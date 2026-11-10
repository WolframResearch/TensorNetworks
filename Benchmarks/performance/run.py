#!/usr/bin/env python3
"""Generate shared inputs, run backends serially, validate, and report."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import platform
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

from common import digest, validate_result, verify_manifest, write_json
from corpus import generate
from report import render

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]


def kernel_snapshot(repo=REPO):
    paths = sorted((repo / "TensorNetworks" / "Kernel").rglob("*.wl"))
    paths += [repo / "TensorNetworks" / "PacletInfo.wl"]
    return {str(path.relative_to(repo)): digest(path) for path in paths}


def source_digest(snapshot):
    return hashlib.sha256(json.dumps(snapshot, sort_keys=True).encode()).hexdigest()


def suite_snapshot():
    return {str(path.relative_to(HERE)): digest(path) for path in
            sorted([*HERE.glob("*.py"), *HERE.glob("*.wls"), *HERE.glob("requirements.txt"),
                    *HERE.glob("julia/*.jl"), *HERE.glob("julia/Project.toml")])}


def check_kernel_unchanged(before, after):
    if before != after:
        raise ValueError("kernel source changed during the audit; results cannot be attributed to one revision")


def stop_process_group(proc):
    if proc.poll() is not None:
        return
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait()


def run_process(command, env, log, timeout, rssfile):
    import psutil
    timer = Path("/usr/bin/time")
    if timer.exists() and sys.platform in {"darwin", "linux"}:
        command = [str(timer), "-l" if sys.platform == "darwin" else "-v", "-o", str(rssfile), *command]
    started = time.monotonic()
    with log.open("w") as stream:
        proc = subprocess.Popen(command, cwd=REPO, env=env, stdout=stream,
                                stderr=subprocess.STDOUT, start_new_session=True)
        peak_tree_rss, rss_errors = 0, 0
        try:
            while proc.poll() is None:
                if time.monotonic() - started > timeout:
                    raise subprocess.TimeoutExpired(command, timeout)
                try:
                    parent = psutil.Process(proc.pid)
                    processes = [parent, *parent.children(recursive=True)]
                    rss = 0
                    for process in processes:
                        try:
                            rss += process.memory_info().rss
                        except (psutil.Error, OSError):
                            rss_errors += 1
                    peak_tree_rss = max(peak_tree_rss, rss)
                except (psutil.Error, OSError):
                    rss_errors += 1
                time.sleep(.05)
            code = proc.returncode
            status = "ok" if code == 0 else "failed"
        except subprocess.TimeoutExpired:
            stop_process_group(proc)
            code, status = proc.returncode, "timeout"
        finally:
            stop_process_group(proc)
    result = {"status": status, "returncode": code, "process_wall_seconds": time.monotonic() - started,
              "log": log.name, "rss_sampling_errors": rss_errors}
    if peak_tree_rss > 0:
        result["sampled_process_tree_peak_rss_bytes"] = peak_tree_rss
    if rssfile.exists():
        raw = rssfile.read_text()
        match = re.search(r"(\d+)\s+maximum resident set size", raw) if sys.platform == "darwin" else re.search(
            r"Maximum resident set size \(kbytes\):\s*(\d+)", raw)
        if match:
            result["launcher_peak_rss_bytes"] = int(match[1]) * (1 if sys.platform == "darwin" else 1024)
    return result


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=["smoke", "focus", "full"], default="focus")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--backends", default="tn,python,julia", help="comma-separated subset; all three by default")
    parser.add_argument("--cases", help="comma-separated case IDs from the selected profile")
    parser.add_argument("--samples", type=int, default=5)
    parser.add_argument("--sample-seconds", type=float, default=.04)
    parser.add_argument("--threads", type=int, default=1)
    parser.add_argument("--timeout", type=float, default=600, help="seconds per backend; includes startup")
    parser.add_argument("--python", default=sys.executable)
    parser.add_argument("--julia", default="julia")
    parser.add_argument("--wolframscript", default="wolframscript")
    parser.add_argument("--kernel", type=Path)
    parser.add_argument("--arrays-directory", type=Path, help="optional isolated paclet directory containing Arrays/PacletInfo.wl or PacletInfo.wl")
    parser.add_argument("--allow-unsupported-dependencies", action="store_true",
                        help="allow explicitly provisional TN timings below the declared Arrays minimum")
    args = parser.parse_args()
    if args.samples < 3 or not 0 < args.sample_seconds <= 2 or args.threads < 1 or not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("samples >= 3, 0 < sample-seconds <= 2, threads >= 1 and timeout > 0 required")
    args.backends = args.backends.split(",")
    if not args.backends or len(set(args.backends)) != len(args.backends) or not set(args.backends) <= {"tn", "python", "julia"}:
        parser.error("choose unique backends from tn,python,julia")
    return args


def main():
    args = arguments()
    output = (args.out or HERE / "results" / dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")).resolve()
    output.mkdir(parents=True, exist_ok=False)
    before = kernel_snapshot()
    manifest_path = generate(output / "corpus", args.profile, args.samples, args.sample_seconds,
                             args.threads, args.cases.split(",") if args.cases else None)
    manifest = json.loads(manifest_path.read_text())
    manifest["minimum_arrays_version"] = re.search(
        r'\{"Wolfram/Arrays",\s*"([\d.]+)\+"\}',
        (REPO / "TensorNetworks" / "PacletInfo.wl").read_text()).group(1)
    write_json(manifest_path, manifest)
    verify_manifest(manifest_path)
    identity = digest(manifest_path)
    env = os.environ.copy()
    for key in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "BLIS_NUM_THREADS", "JULIA_NUM_THREADS"):
        env[key] = str(args.threads)
    env.update(TN_BENCH_MANIFEST=str(manifest_path), TN_BENCH_REPO=str(REPO),
               TN_BENCH_ALLOW_UNSUPPORTED="1" if args.allow_unsupported_dependencies else "0",
               TN_BENCH_ARRAYS_DIRECTORY=str(args.arrays_directory.resolve()) if args.arrays_directory else "")
    kernel = args.kernel
    if kernel is None:
        candidates = [Path("/Applications/Wolfram 15.01.app/Contents/MacOS/WolframKernel"),
                      Path("/Applications/Wolfram 15.0.app/Contents/MacOS/WolframKernel"),
                      Path("/Applications/Wolfram 14.3.app/Contents/MacOS/WolframKernel")]
        kernel = next((p for p in candidates if p.exists()), None)
    tn_command = [args.wolframscript]
    if kernel:
        tn_command += ["-local", str(kernel)]
    tn_command += ["-file", str(HERE / "tn_bench.wls")]
    commands = {"tn": tn_command,
                "python": [args.python, str(HERE / "python_bench.py"), str(manifest_path), str(output / "python.json")],
                "julia": [args.julia, "--startup-file=no", f"--project={HERE / 'julia'}", str(HERE / "julia" / "bench.jl"),
                          str(manifest_path), str(output / "julia.json")]}
    run = {"schema_version": 1, "created_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
           "host": {"platform": platform.platform(), "processor": platform.processor(), "logical_cpus": os.cpu_count()},
           "git_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
           "kernel_sha256": source_digest(before), "kernel_files": before,
           "suite_files": suite_snapshot(),
           "corpus_sha256": identity, "manifest": manifest, "requested_backends": args.backends,
           "protocol_notes": ["Backends run serially; inputs and references are identical binary data.",
                              "Imports, loading, JIT warm-up and validation are excluded from row timings.",
                              "Samples are per-call batch means, not individual-call latency percentiles.",
                              "Sampled process-tree RSS includes child Wolfram kernels and all startup/loading/validation; 50 ms polling can miss peaks and sums shared pages.",
                              "Only prepared fixed-path rows share an explicitly fixed contraction order.",
                              "Native MPS canonicalization algorithms differ: TN SVD versus ITensorMPS gauge movement."],
           "backends": {}, "results": {}}
    if args.arrays_directory:
        arrays_root = args.arrays_directory.resolve()
        run["arrays_override"] = {"path": str(arrays_root), "files": {
            str(path.relative_to(arrays_root)): digest(path) for path in sorted(arrays_root.rglob("*.wl"))
            if ".git" not in path.parts}}
    if (HERE / "julia" / "Manifest.toml").exists():
        shutil.copyfile(HERE / "julia" / "Manifest.toml", output / "JuliaManifest.toml")
    shutil.copyfile(HERE / "requirements.txt", output / "python-requirements.txt")
    for backend in args.backends:
        print(f"Running {backend} ...", flush=True)
        env["TN_BENCH_OUTPUT"] = str(output / "tn.json")
        info = None
        try:
            info = run_process(commands[backend], env, output / f"{backend}.log", args.timeout, output / f"{backend}.rss.txt")
            path = output / f"{backend}.json"
            if path.exists():
                value = json.loads(path.read_text())
                if "error" in value:
                    raise ValueError(value["error"])
                validate_result(value, manifest, identity, backend)
                if not value["records"] or any(row["status"] != "ok" for row in value["records"]):
                    info["status"] = "failed"
                run["results"][backend] = value
            else:
                if info["status"] == "ok":
                    info["status"] = "failed"
                info["error"] = "backend produced no validated JSON results"
        except Exception as exc:
            info = info or {"status": "failed"}
            if info["status"] == "ok":
                info["status"] = "failed"
            info["error"] = f"{type(exc).__name__}: {str(exc)[:500]}"
        run["backends"][backend] = info
        write_json(output / "run.json", run)
    try:
        check_kernel_unchanged(before, kernel_snapshot())
        run["kernel_unchanged"] = True
    except ValueError as exc:
        run["kernel_unchanged"] = False
        run["source_error"] = str(exc)
    run["suite_unchanged"] = run["suite_files"] == suite_snapshot()
    failed = not run["kernel_unchanged"] or not run["suite_unchanged"] or any(x["status"] != "ok" for x in run["backends"].values())
    provisional = run["results"].get("tn", {}).get("metadata", {}).get("dependency_supported") is False
    run["status"] = "failed" if failed else "provisional" if provisional else "ok"
    write_json(output / "run.json", run)
    render(run, output)
    print(f"{run['status']}: {output / 'summary.md'}", flush=True)
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
