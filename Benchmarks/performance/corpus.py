"""Generate one checksummed, C-order Float64/Complex128 corpus for every backend."""
from __future__ import annotations

from pathlib import Path
from functools import reduce
import hashlib
import numpy as np

from common import SCHEMA_VERSION, digest, write_json


def left_path(n):
    return [[0, 1]] + [[size - 1, 0] for size in range(n - 1, 1, -1)]


def mps_state(tensors):
    value = tensors[0].T
    for tensor in tensors[1:-1]:
        value = np.moveaxis(np.tensordot(value, tensor, axes=(-1, 0)), -2, -1)
    return np.tensordot(value, tensors[-1], axes=(-1, 0))


def generate(root: Path, profile: str, samples: int, seconds: float, threads: int,
             selected: list[str] | None = None) -> Path:
    root.mkdir(parents=True, exist_ok=False)
    files, cases = [], []

    def generator(ident):
        seed = int.from_bytes(hashlib.sha256(ident.encode()).digest()[:8], "little") ^ 20261026
        return np.random.default_rng(seed)

    def save(name, array):
        array = np.asarray(array)
        spec = {"shape": list(array.shape), "real": name + ".real.bin"}
        parts = [(spec["real"], array.real)]
        if np.iscomplexobj(array):
            spec["imag"] = name + ".imag.bin"
            parts.append((spec["imag"], array.imag))
        for filename, part in parts:
            path = root / filename
            np.asarray(part, dtype="<f8", order="C").tofile(path)
            files.append({"path": filename, "sha256": digest(path), "bytes": path.stat().st_size})
        return spec

    chain_specs = [(2, 8, False), (12, 16, False)]
    mps_specs = [(6, 4, True)]
    if profile in {"focus", "full"}:
        chain_specs = [(2, 2, False), (2, 16, False), (4, 8, False),
                       (12, 16, False), (12, 64, False), (12, 256, False), (12, 16, True)]
        mps_specs = [(6, 4, False), (8, 8, True)]
    if profile == "full":
        chain_specs += [(n, d, False) for n, d in [(2, 64), (4, 16), (32, 8), (64, 4)]]
        mps_specs += [(12, 4, True)]
    for n, d, complex_values in chain_specs:
        ident = f"chain-n{n}-d{d}-{'complex' if complex_values else 'real'}"
        if selected and ident not in selected:
            continue
        rng = generator(ident)
        tensors = [rng.normal(size=(d, d)) / np.sqrt(d) for _ in range(n)]
        if complex_values:
            tensors = [(a + 1j * rng.normal(size=a.shape) / np.sqrt(d)) / np.sqrt(2) for a in tensors]
        changed = tensors[0].copy()
        changed[0, 0] = 0
        product = lambda xs: reduce(np.matmul, xs)
        cases.append({
            "id": ident, "family": "matrix_chain", "n": n, "d": d,
            "dtype": "complex128" if complex_values else "float64",
            "labels": [[i, i + 1] for i in range(n)], "output": [0, n],
            "path": left_path(n), "tensors": [save(f"{ident}-t{i}", a) for i, a in enumerate(tensors)],
            "reference": save(f"{ident}-reference", product(tensors)),
            "changed_first": save(f"{ident}-changed-first", changed),
            "changed_reference": save(f"{ident}-changed-reference", product([changed] + tensors[1:])),
        })
    for n, d, complex_values in mps_specs:
        ident = f"mps-n{n}-d{d}-{'complex' if complex_values else 'real'}"
        if selected and ident not in selected:
            continue
        rng = generator(ident)
        shapes = [(d, 2)] + [(d, d, 2)] * (n - 2) + [(d, 2)]
        tensors = [rng.normal(size=s) / np.sqrt(2 * d) for s in shapes]
        if complex_values:
            tensors = [(a + 1j * rng.normal(size=a.shape) / np.sqrt(2 * d)) / np.sqrt(2) for a in tensors]
        state = mps_state(tensors)
        tensors[0] *= np.sqrt((1 + .1 * n + .01 * d) / np.vdot(state, state).real)
        state = mps_state(tensors)
        physical = list(range(n - 1, 2 * n - 1))
        labels = [[0, physical[0]]] + [[i - 1, i, physical[i]] for i in range(1, n - 1)] + [[n - 2, physical[-1]]]
        cases.append({"id": ident, "family": "mps", "n": n, "d": d,
                      "dtype": "complex128" if complex_values else "float64",
                      "labels": labels, "output": physical,
                      "tensors": [save(f"{ident}-t{i}", a) for i, a in enumerate(tensors)],
                      "reference": save(f"{ident}-state", state),
                      "norm_squared": float(np.vdot(state, state).real)})
    if not cases or selected and set(selected) != {case["id"] for case in cases}:
        raise ValueError("empty corpus or unknown case selection for this profile")
    manifest = {"schema_version": SCHEMA_VERSION, "seed": 20261026, "profile": profile,
                "layout": "IEEE754 little-endian Float64 components, C row-major; separate imaginary file",
                "protocol": {"samples": samples, "sample_seconds": seconds, "threads": threads,
                             "tolerance": 1e-10, "batch_limit": 16384},
                "cases": cases, "files": files}
    path = root / "manifest.json"
    write_json(path, manifest)
    return path
