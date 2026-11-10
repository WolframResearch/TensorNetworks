#!/usr/bin/env python3
"""Profile TN components without changing or replacing TN function definitions."""
import argparse
import csv
import datetime as dt
import json
import math
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys

from common import digest, finite_number, verify_manifest, write_json
from corpus import generate
from run import HERE, REPO, kernel_snapshot, run_process, source_digest, suite_snapshot

KEY_TASKS = {"key." + name for name in (
    "total", "leaf_signatures", "mask_and_hash", "unitize", "hash_precomputed_masks", "dimensions",
    "precision", "numeric_leaf", "arrayq_numeric", "sparse_full", "cache_lookup_precomputed", "hash_fresh_masks")}
SMALL_TASKS = {"execute.direct_dot", "prepare.data", "prepare.tree_predicate", "prepare.tree_steps",
               "prepare.label_dimensions", "prepare.convert_leaves", "prepare.computable_leaves",
               "prepare.machine_precision_leaves", "prepare.integer_scaled_leaves", "prepare.represent_leaves",
               "prepare.holder_counts", "prepare.leaf_association", "automatic.cached_plan", "automatic.warm_execute"}
for engine in ("Dot", "ArrayDot"):
    SMALL_TASKS.update("execute." + name + "." + engine for name in ("total", "build_inactive", "activate_prebuilt"))
    SMALL_TASKS.add("harness.replay_dispatch." + engine)
    SMALL_TASKS.update("pair." + engine + "." + name for name in (
        "symmetric_difference", "contracted_labels", "remaining_labels", "position_indices", "ordered_label_candidate", "delete_elements_single",
        "symbolic_dimensions", "tensor_dimensions", "permutations", "numeric_dot", "numeric_arraydot"))
    SMALL_TASKS.update("replay." + engine + "." + name for name in (
        "contractTreePath", "contractStep", "contractTensorPair", "einsum" + engine, "settleLeaf"))


def validate_profile(result, manifest, identity):
    if result.get("backend") != "tn.profile" or type(result.get("schema_version")) is not int or result["schema_version"] != 1:
        raise ValueError("wrong profiling worker/schema")
    if result["corpus_sha256"] != identity or any(result["metadata"].get(k) is not True for k in ("profiled_definitions_unchanged", "ordered_label_candidate_boundary_checks")):
        raise ValueError("corpus identity or definition guard failed")
    required = {("harness", "harness.noop")}
    for case in manifest["cases"]:
        required.update((case["id"], task) for task in KEY_TASKS | (SMALL_TASKS if case["d"] <= 16 else set()))
    seen = set()
    for row in result["records"]:
        key = row["case"], row["task"]
        if key in seen or row["status"] != "ok":
            raise ValueError(f"failed or duplicate profiling row: {key}: {row.get('error')}")
        seen.add(key)
        values = row["samples_seconds"]
        if len(values) != manifest["protocol"]["samples"] or not all(finite_number(v) and v > 0 for v in values):
            raise ValueError("invalid raw samples")
        if not all(finite_number(row[k]) and row[k] > 0 for k in ("median_seconds", "min_seconds", "max_seconds")):
            raise ValueError("invalid statistics")
        if not math.isclose(row["median_seconds"], statistics.median(values), rel_tol=1e-10) or row["min_seconds"] != min(values) or row["max_seconds"] != max(values):
            raise ValueError("inconsistent statistics")
        if any(type(row[k]) is not int or row[k] < 1 for k in ("iterations_per_sample", "calls_per_replay")):
            raise ValueError("invalid counts")
        if not finite_number(row["normalized_error"]) or not 0 <= row["normalized_error"] <= 1e-10:
            raise ValueError("invalid numerical evidence")
    if seen != required:
        raise ValueError(f"profiling coverage mismatch: missing {sorted(required-seen)}, extra {sorted(seen-required)}")
    observations = result["observations"]
    for case in manifest["cases"]:
        key_obs = [o for o in observations if o["case"] == case["id"] and "engine" not in o]
        if len(key_obs) != 1 or not all(key_obs[0].get(k) is True for k in ("packed_inputs", "same_support_same_key", "changed_support_changes_key")):
            raise ValueError("missing key semantics or packed-input evidence")
        if case["d"] <= 16:
            for engine in ("Dot", "ArrayDot"):
                trace = [o for o in observations if o["case"] == case["id"] and o.get("engine") == engine]
                expected = {"contractTreePath": 1, "settleLeaf": case["n"], "contractStep": case["n"]-1,
                            "contractTensorPair": case["n"]-1, "einsum"+engine: case["n"]-1}
                if len(trace) != 1 or trace[0]["unique_replay_inputs"] != expected:
                    raise ValueError("unexpected captured call topology")


def render(run, output):
    rows = run.get("result", {}).get("records", [])
    fields = ["case", "task", "calls_per_replay", "status", "median_seconds", "min_seconds", "max_seconds",
              "iterations_per_sample", "normalized_error", "samples_seconds"]
    with (output / "timings.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows({**r, "samples_seconds": json.dumps(r.get("samples_seconds", []))} for r in rows)
    text = ["# TN component profile", "", f"Status: **{run['status']}**", "",
            "Measurements are untraced per-call batch means, reported as median [minimum, maximum].",
            "Replay rows sum one call per distinct captured input for the named helper. Timings are inclusive and overlap: they are not additive phase shares.",
            "The capture pass is outside timing. Duplicate TraceScan evaluation events are removed; these corpus inputs have distinct operands at each step.",
            "Frozen intermediate replays omit dependency formation and can change cache locality; use them to locate costs, not to claim exact end-to-end savings.",
            "Fresh-mask hashing prepares a new Unitize result outside each timed sample, then hashes it once, without calibration. Repeated precomputed-mask hashing can reuse internal state and is not a first-use hash measurement.",
            "The ordered-label candidate is a standalone profiling function tested on unique labels, including unsorted multiple shared axes, disjoint/full overlap, and empty sets. No kernel implementation was replaced.",
            "Activating a prebuilt expression embeds the original tensor values. It is a diagnostic lower bound, not a reusable execution API for changed values.",
            "", f"Kernel source unchanged: {run.get('kernel_unchanged')}. Suite source unchanged: {run.get('suite_unchanged')}.",
            f"Corpus SHA256: `{run['corpus_sha256']}`.", ""]
    for case in run["manifest"]["cases"]:
        text += [f"## {case['id']}", "", "| Component | Calls per replay | Median [min, max], us |", "|---|---:|---:|"]
        for row in rows:
            if row["case"] == case["id"]:
                timing = "failed" if row["status"] != "ok" else "{:.3g} [{:.3g}, {:.3g}]".format(*(row[k]*1e6 for k in ("median_seconds","min_seconds","max_seconds")))
                text.append(f"| {row['task']} | {row['calls_per_replay']} | {timing} |")
        text.append("")
    if "error" in run:
        text += ["Failure: " + run["error"], ""]
    (output / "summary.md").write_text("\n".join(text))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--cases", default="chain-n2-d2-real,chain-n2-d16-real,chain-n4-d8-real,chain-n12-d16-real,chain-n12-d16-complex,chain-n12-d64-real,chain-n12-d256-real")
    parser.add_argument("--samples", type=int, default=7)
    parser.add_argument("--sample-seconds", type=float, default=.03)
    parser.add_argument("--threads", type=int, default=1)
    parser.add_argument("--timeout", type=float, default=600)
    parser.add_argument("--arrays-directory", type=Path, default=HERE/".dependencies/Arrays/Arrays")
    parser.add_argument("--kernel", default="/Applications/Wolfram 15.01.app/Contents/MacOS/WolframKernel")
    args = parser.parse_args()
    if args.samples < 5 or not 0 < args.sample_seconds <= 2 or args.threads < 1 or not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("samples >=5, positive seconds <=2, threads >=1, positive finite timeout required")
    output = (args.out or HERE/"results"/("profile-"+dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))).resolve()
    output.mkdir(parents=True,exist_ok=False)
    before, suite = kernel_snapshot(), suite_snapshot()
    manifest_path = generate(output/"corpus", "focus", args.samples, args.sample_seconds, args.threads, args.cases.split(","))
    manifest, identity = verify_manifest(manifest_path), digest(manifest_path)
    if any(c["family"] != "matrix_chain" for c in manifest["cases"]):
        parser.error("profiling accepts matrix-chain cases only")
    env = os.environ.copy()
    for name in ("OMP_NUM_THREADS","OPENBLAS_NUM_THREADS","MKL_NUM_THREADS","VECLIB_MAXIMUM_THREADS","BLIS_NUM_THREADS"):
        env[name]=str(args.threads)
    env.update(TN_BENCH_MANIFEST=str(manifest_path),TN_BENCH_OUTPUT=str(output/"profile.json"),
               TN_BENCH_REPO=str(REPO),TN_BENCH_ARRAYS_DIRECTORY=str(args.arrays_directory.resolve()))
    run={"status":"running","created_utc":dt.datetime.now(dt.timezone.utc).isoformat(),
         "git_head":subprocess.check_output(["git","rev-parse","HEAD"],cwd=REPO,text=True).strip(),
         "kernel_files":before,"kernel_sha256":source_digest(before),"suite_files":suite,
         "corpus_sha256":identity,"manifest":manifest}
    shutil.copyfile(HERE/"requirements.txt",output/"python-requirements.txt")
    run["process"]=run_process(["wolframscript","-local",args.kernel,"-file",str(HERE/"profile_tn.wls")],
                               env,output/"profile.log",args.timeout,output/"profile.rss.txt")
    try:
        result=json.loads((output/"profile.json").read_text())
        run["result"]=result
        validate_profile(result,manifest,identity)
        if run["process"]["status"] != "ok":
            raise ValueError("worker failed or timed out")
        run["kernel_unchanged"]=kernel_snapshot()==before
        run["suite_unchanged"]=suite_snapshot()==suite
        if not run["kernel_unchanged"] or not run["suite_unchanged"]:
            raise ValueError("sources changed during profiling")
        run["status"]="ok"
    except Exception as exc:
        run.update(status="failed",error=f"{type(exc).__name__}: {exc}")
    write_json(output/"run.json",run)
    render(run,output)
    print(f"{run['status']}: {output/'summary.md'}")
    return int(run["status"] != "ok")

if __name__=="__main__":
    sys.exit(main())
