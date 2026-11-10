"""Summarize only validated measurements; never silently rank missing backends."""
import csv
import json
from pathlib import Path
from python_bench import path_stats


def duration(row):
    if not row or row["status"] != "ok":
        return "unavailable"
    scale, unit = (1e6, "us") if row["median_seconds"] < .001 else (1e3, "ms")
    return f"{row['median_seconds'] * scale:.3g} [{row['min_seconds'] * scale:.3g}, {row['max_seconds'] * scale:.3g}] {unit}"


def render(run, output: Path):
    rows = [row for result in run["results"].values() for row in result["records"]]
    index = {(r["case"], r["implementation"], r["task"], r["mode"]): r for r in rows}

    def get(case, impl, task, mode="prepared"):
        return duration(index.get((case, impl, task, mode)))

    text = ["# TensorNetworks performance audit", "", f"Status: **{run['status']}**", "",
            f"Kernel commit: `{run['git_head']}`. Kernel unchanged during run: `{run['kernel_unchanged']}`.",
            f"Suite unchanged during run: `{run.get('suite_unchanged', 'not recorded')}`.",
            f"Corpus SHA256: `{run['corpus_sha256']}`.", "",
            "Times are median [minimum, maximum] of per-call batch means. No percentiles or statistical significance are inferred.", ""]
    if run["status"] == "provisional":
        text += ["**Provisional environment:** installed Arrays is below the paclet dependency minimum; this run is not a supported-environment baseline.", ""]
    text += ["## Backend status", "", "| Backend | Status | Sampled process-tree peak RSS |", "|---|---|---:|"]
    for backend, info in run["backends"].items():
        rss = f"{info['sampled_process_tree_peak_rss_bytes'] / 2**20:.1f} MiB" if "sampled_process_tree_peak_rss_bytes" in info else "unavailable"
        text.append(f"| {backend} | {info['status']} | {rss} |")
    python_metadata = run["results"].get("python", {}).get("metadata", {})
    blas = python_metadata.get("numpy_build_config", {}).get("Build Dependencies", {}).get("blas", {})
    if python_metadata:
        text += ["", f"Requested threads: {run['manifest']['protocol']['threads']}. NumPy BLAS build: {blas.get('name', 'unavailable')}, version {blas.get('version', 'unavailable')}.",
                 f"NumPy effective BLAS thread readback: {python_metadata.get('effective_blas_threads') or 'unavailable'}.",
                 python_metadata.get("thread_observability", "Thread observability unavailable.")]
    text += ["", "RSS sums the launcher and descendants, including the separate Wolfram kernel. Sampling every 50 ms can miss peaks and shared pages can be counted more than once. This includes imports, JIT, loading, warm-up and validation; it is not contraction-only memory.", "",
             "## Small contractions: same data and left-fold path", "",
             "Input loading, object/index construction, path search and expression preparation are excluded.", "",
             "| Case | WL Dot | TN Dot | TN ArrayDot | opt_einsum | cotengra | ITensors |",
             "|---|---:|---:|---:|---:|---:|---:|"]
    for case in run["manifest"]["cases"]:
        if case["family"] == "matrix_chain":
            values = [get(case["id"], impl, "chain.execute.fixed_path") for impl in
                      ("wl.Dot", "tn.Dot", "tn.ArrayDot", "opt_einsum.numpy", "cotengra.numpy", "ITensors")]
            text.append("| " + " | ".join([case["id"], *values]) + " |")
    text += ["", "## Cache keys and automatic execution", "",
             "Cold and warm Automatic both receive the same precomputed data association. Automatic may choose a different path than the fixed-path table; do not subtract these tables to attribute phases.", "",
             "| Case | Dense key | Full sparse key | Diagonal sparse key | Zero-mask hash component | Automatic hit | Automatic miss |",
             "|---|---:|---:|---:|---:|---:|---:|"]
    for case in run["manifest"]["cases"]:
        if case["family"] == "matrix_chain":
            values = [get(case["id"], "tn", task) for task in
                      ("cache.key.dense", "cache.key.sparse_full", "cache.key.sparse_diagonal", "cache.component.zero_mask_hash")]
            values += [get(case["id"], "tn", "chain.execute.automatic", mode) for mode in ("cache_hit_data", "cache_miss_data")]
            text.append("| " + " | ".join([case["id"], *values]) + " |")
    text += ["", "Full sparse keys use fully populated SparseArrays; diagonal sparse keys use one stored diagonal per tensor. These measure different support/storage regimes, not equal sparse density.", "",
             "## Greedy planning", "",
             "These are greedy algorithms, not equal-time-budget hyperoptimizer searches. TN includes parameter extraction and its WXF boundary; Python planners receive shapes. Terms use one common dimension-product convention, not SDK-specific FLOP counters.", "",
             "| Case | Planner | Search time | Scalar product terms | Largest intermediate elements |",
             "|---|---|---:|---:|---:|"]
    for case in run["manifest"]["cases"]:
        if case["family"] != "matrix_chain":
            continue
        sizes = {i: d for labels, spec in zip(case["labels"], case["tensors"]) for i, d in zip(labels, spec["shape"])}
        for impl in ("tn", "opt_einsum.numpy", "cotengra.numpy"):
            row = index.get((case["id"], impl, "chain.plan.greedy", "search"))
            stats = row.get("plan_stats", {}) if row else {}
            if row and row["status"] == "ok" and "planned_path" in row:
                stats = path_stats(case["labels"], case["output"], sizes, row["planned_path"])
            text.append(f"| {case['id']} | {impl} | {duration(row)} | {stats.get('scalar_product_terms', 'unavailable')} | {stats.get('largest_intermediate_elements', 'unavailable')} |")
    text += ["",
             "## MPS tasks", "",
             "Overlap uses native MPS APIs for TN and ITensorMPS. Python libraries contract a prepared bra/ket network; their algorithms and path can differ. Canonicalization compares equivalent output requirements, not the same decomposition algorithm.", "",
             "| Case | TN overlap | ITensorMPS overlap | opt_einsum overlap | cotengra overlap | TN canonical | ITensorMPS canonical |",
             "|---|---:|---:|---:|---:|---:|---:|"]
    for case in run["manifest"]["cases"]:
        if case["family"] == "mps":
            values = [get(case["id"], impl, "mps.overlap", mode) for impl, mode in
                      (("tn.MPS", "native_mps"), ("ITensorMPS", "native_mps"),
                       ("opt_einsum.numpy", "prepared_generic_network"), ("cotengra.numpy", "prepared_generic_network"))]
            values += [get(case["id"], impl, "mps.left_canonical", "native_mps") for impl in ("tn.MPS", "ITensorMPS")]
            text.append("| " + " | ".join([case["id"], *values]) + " |")
    failures = [r for r in rows if r["status"] != "ok"]
    text += ["", "## Validation and interpretation", "",
             f"Validated rows: {len(rows) - len(failures)}. Failed rows: {len(failures)}.",
             "Each timed operation is validated before and after timing. Normalized error uses norm(error)/max(1,norm(reference)) <= 1e-10.",
             "Cache observations, component timings, planner timing, raw samples, versions, thread settings, and process logs are in run.json and the backend JSON files.",
             "Private plan-key measurements are tied to the recorded source hash and may need adapter updates when internals change.", ""]
    for row in failures:
        text.append(f"- {row['case']} / {row['implementation']} / {row['task']}: {row['error']}")
    for backend, info in run["backends"].items():
        if info["status"] != "ok":
            text.append(f"- Backend {backend}: {info.get('error', 'see ' + info.get('log', 'backend log'))}")
    (output / "summary.md").write_text("\n".join(text) + "\n")
    fields = ["case", "implementation", "task", "mode", "status", "median_seconds", "min_seconds", "max_seconds",
              "normalized_error", "iterations_per_sample", "samples_seconds", "error"]
    with (output / "timings.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows({**row, "samples_seconds": json.dumps(row.get("samples_seconds", []))} for row in rows)
