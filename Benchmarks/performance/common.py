"""Shared corpus validation, bounded result records, and batched timing."""
from __future__ import annotations

import hashlib
import json
import math
import statistics
import time
from pathlib import Path

SCHEMA_VERSION = 1


def finite_number(value) -> bool:
    """JSON booleans are not numerical measurement evidence."""
    return type(value) in (int, float) and math.isfinite(value)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value) -> None:
    """Atomic, finite JSON only; never serialize tensor expressions into results."""
    data = json.dumps(value, indent=2, allow_nan=False) + "\n"
    if len(data) > 8 * 1024**2:
        raise ValueError("result exceeds 8 MiB")
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(data)
    temporary.replace(path)


def verify_manifest(path: Path) -> dict:
    manifest = json.loads(path.read_text())
    if type(manifest["schema_version"]) is not int or manifest["schema_version"] != SCHEMA_VERSION:
        raise ValueError("unsupported corpus schema")
    for item in manifest["files"]:
        file = (path.parent / item["path"]).resolve()
        if not file.is_relative_to(path.parent.resolve()):
            raise ValueError("corpus path escapes its directory")
        if digest(file) != item["sha256"]:
            raise ValueError(f"corpus checksum mismatch: {item['path']}")
        if file.stat().st_size != item["bytes"]:
            raise ValueError(f"corpus size mismatch: {item['path']}")
    ids = [case["id"] for case in manifest["cases"]]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate case IDs")
    return manifest


def read_array(root: Path, spec: dict):
    import numpy as np

    count = math.prod(spec["shape"])
    real = np.fromfile(root / spec["real"], dtype="<f8")
    if real.size != count:
        raise ValueError("wrong tensor length")
    value = real.reshape(spec["shape"])
    if "imag" in spec:
        imag = np.fromfile(root / spec["imag"], dtype="<f8")
        if imag.size != count:
            raise ValueError("wrong imaginary tensor length")
        value = value + 1j * imag.reshape(spec["shape"])
    return value


def numeric_error(actual, expected) -> float:
    import numpy as np

    value = np.asarray(actual)
    reference = np.asarray(expected)
    if value.shape != reference.shape or value.dtype.kind not in "fci":
        raise ValueError(f"wrong numeric output shape/type: {value.shape}, {value.dtype}")
    if not np.all(np.isfinite(value)):
        raise ValueError("non-finite output")
    error = float(np.linalg.norm((value - reference).ravel()) / max(1.0, np.linalg.norm(reference.ravel())))
    if error > 1e-10:
        raise ValueError(f"normalized error {error:.3g} exceeds 1e-10")
    return error


def timing_record(case: str, implementation: str, task: str, function,
                  validate, samples: int, seconds: float, *, mode="warm", setup=None) -> dict:
    record = {"case": case, "implementation": implementation, "task": task, "mode": mode}
    try:
        error = validate(function())
        iterations = 1
        while True:
            start = time.perf_counter_ns()
            for _ in range(iterations):
                function()
            elapsed = (time.perf_counter_ns() - start) * 1e-9
            if elapsed >= seconds or iterations >= 16384:
                break
            iterations *= 2
        timings = []
        for _ in range(samples):
            if setup is not None:
                setup()
            start = time.perf_counter_ns()
            for _ in range(iterations):
                function()
            timings.append((time.perf_counter_ns() - start) * 1e-9 / iterations)
        validate(function())
        record.update(status="ok", normalized_error=error, samples_seconds=timings,
                      iterations_per_sample=iterations, median_seconds=statistics.median(timings),
                      min_seconds=min(timings), max_seconds=max(timings))
    except Exception as exc:
        record.update(status="failed", error=f"{type(exc).__name__}: {str(exc)[:300]}")
    return record


def validate_result(result: dict, manifest: dict, corpus_sha256: str, expected_backend: str) -> None:
    if result.get("backend") != expected_backend:
        raise ValueError(f"worker identity mismatch: expected {expected_backend}, got {result.get('backend')}")
    if type(result["schema_version"]) is not int or result["schema_version"] != SCHEMA_VERSION or result["corpus_sha256"] != corpus_sha256:
        raise ValueError("result schema or corpus identity mismatch")
    known = {case["id"] for case in manifest["cases"]} | {"harness"}
    seen = set()
    for row in result["records"]:
        key = tuple(row[k] for k in ("case", "implementation", "task", "mode"))
        if row["case"] not in known or key in seen:
            raise ValueError("unknown or duplicate benchmark row")
        seen.add(key)
        if row["status"] not in {"ok", "failed"}:
            raise ValueError("unknown result status")
        if row["status"] == "ok":
            values = row["samples_seconds"]
            if len(values) != manifest["protocol"]["samples"] or not all(
                finite_number(x) and x > 0 for x in values
            ):
                raise ValueError("invalid timing samples")
            if not all(finite_number(row[k]) and row[k] > 0 for k in
                       ("median_seconds", "min_seconds", "max_seconds")):
                raise ValueError("invalid timing statistics")
            if not math.isclose(row["median_seconds"], statistics.median(values), rel_tol=1e-10):
                raise ValueError("median does not match raw samples")
            if row["min_seconds"] != min(values) or row["max_seconds"] != max(values):
                raise ValueError("range does not match raw samples")
            if type(row["iterations_per_sample"]) is not int or row["iterations_per_sample"] < 1:
                raise ValueError("invalid batch iteration count")
            if not finite_number(row.get("normalized_error")) or not 0 <= row["normalized_error"] <= 1e-10:
                raise ValueError("invalid correctness evidence")
    # Require the complete advertised row set, not just the columns shown in the main table.
    required_all = {("harness", {"tn": "wl", "python": "python", "julia": "julia"}[expected_backend],
                     "harness.noop", "prepared")}
    for case in manifest["cases"]:
        if case["family"] == "matrix_chain":
            required = {
                "tn": [("tn", task, "prepared") for task in (
                    "chain.prepare.data", "cache.key.dense", "cache.key.sparse_full", "cache.key.sparse_diagonal",
                    "cache.component.precision", "cache.component.numericq", "cache.component.zero_mask_hash",
                    "chain.prepare.parameters", "chain.prepare.path_to_tree")]
                    + [(name, "chain.execute.fixed_path", "prepared") for name in
                       ("tn.Dot", "tn.ArrayDot", "wl.Dot", "wl.ArrayDot")]
                    + [("tn", "chain.plan.greedy", "search"),
                       ("tn.ArrayDot", "chain.execute.fixed_path", "canonical_path_net"),
                       ("tn", "chain.execute.automatic", "cache_hit_data"),
                       ("tn", "chain.execute.automatic", "cache_miss_data"),
                       ("tn", "chain.execute.new_values", "cache_hit_data"),
                       ("tn", "chain.execute.changed_support", "cache_miss_data")],
                "python": [(name, task, "prepared") for name in ("opt_einsum.numpy", "cotengra.numpy") for task in
                           ("chain.prepare.expression.fixed_path", "chain.execute.fixed_path", "chain.execute.new_values",
                            "chain.execute.changed_support")]
                    + [("numpy", "chain.execute.fixed_path", "prepared")]
                    + [(name, "chain.plan.greedy", "search") for name in ("opt_einsum.numpy", "cotengra.numpy")],
                "julia": [("ITensors", task, "prepared") for task in
                          ("chain.prepare.objects", "chain.execute.fixed_path", "chain.execute.new_values", "chain.execute.changed_support")]
                    + [("julia.BLAS", "chain.execute.fixed_path", "prepared")],
            }[expected_backend]
        else:
            implementations = {"tn": ["tn.MPS"], "python": ["opt_einsum.numpy", "cotengra.numpy"],
                               "julia": ["ITensorMPS"]}[expected_backend]
            mode = "prepared_generic_network" if expected_backend == "python" else "native_mps"
            required = [(name, "mps.overlap", mode) for name in implementations]
            if expected_backend != "python":
                required += [(implementations[0], "mps.left_canonical", mode)]
        required_all.update((case["id"], *key) for key in required)
    if seen != required_all:
        raise ValueError(f"incomplete or unexpected {expected_backend} coverage: missing {sorted(required_all-seen)}, extra {sorted(seen-required_all)}")
    if expected_backend == "tn":
        observations = {item["case"]: item for item in result.get("observations", [])}
        for case in manifest["cases"]:
            if case["family"] == "matrix_chain":
                item = observations.get(case["id"], {})
                if not all(item.get(key) is True for key in ("same_support_same_key", "changed_support_changes_key",
                                                           "output_order_changes_key", "outputs_correct")):
                    raise ValueError("cache semantic validation failed")
                counts = item.get("cache_counts_base_repeat_values_support_output")
                if not isinstance(counts, list) or not all(type(n) is int for n in counts) or counts != [1, 1, 1, 2, 3]:
                    raise ValueError("unexpected cache hit/invalidation sequence")
