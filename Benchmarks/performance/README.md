# TensorNetworks performance audit

The [PEPS workload study](workloads/peps-2026-10-26/analysis.md) takes priority over the small-contraction diagnostics below. It measures exact 2D PEPS norms, path-dependent memory requirements, whole-second execution costs, and actual memory-limit outcomes. The earlier microbenchmarks alone do not justify changing the kernel.

The [dense execution probe](workloads/dense-execution-2026-10-26/analysis.md) isolates an internal paclet optimization candidate: the default dense numerical dispatch. It compares existing TN execution routes on identical saved PEPS paths and records the speed/memory tradeoff. It does not claim an integrated default-call speedup.

```sh
Benchmarks/performance/.venv/bin/python Benchmarks/performance/peps_audit.py \
  --out Benchmarks/performance/results/peps-replay
```

Add `--planning-only` to inspect paths and memory estimates without numerical execution. The study preserves fixed paths and tensors for exact replay; new unseeded search runs may find different paths. No kernel functions are changed.

This suite measures small-contraction overhead and automatic-plan cache costs without editing TN kernel functions. It compares Wolfram/TensorNetworks with cotengra, opt_einsum, ITensors primitives, and ITensorMPS. Direct WL, NumPy, and Julia matrix products provide local numerical baselines.

The [macOS ARM64 baseline](baselines/macos-arm64-2026-10-26/README.md) contains a completed focus run, raw samples, dependency manifests, and the verification record.

The [TN component profile](profiling/macos-arm64-2026-10-26/analysis.md) ranks the small-contraction and dense-key bottlenecks and proposes fixes. It includes a separate read-only profiler:

```sh
Benchmarks/performance/.venv/bin/python Benchmarks/performance/profile_tn.py
```

The profiler defaults to the isolated Arrays 1.4.2 checkout described in the baseline. `--arrays-directory`, `--kernel`, `--cases`, `--samples`, `--sample-seconds`, `--timeout`, and `--out` customize it. Call capture happens outside timing, and untraced helper replays overlap; their durations are not additive shares of execution time. Fresh-mask hashing is measured separately from repeatedly hashing precomputed masks. A standalone label-operation candidate is benchmarked without replacing any TN function. Source and function-definition guards check that the kernel stays unchanged.

## Setup

From the repository root:

```sh
python3 -m venv Benchmarks/performance/.venv
Benchmarks/performance/.venv/bin/python -m pip install -r Benchmarks/performance/requirements.txt
julia --startup-file=no --project=Benchmarks/performance/julia -e 'using Pkg; Pkg.instantiate()'
```

Wolfram Language 14.3 or later, a built TN Rust library, and the paclet's declared Wolfram/Arrays dependency are required. Use the normal repository build workflow if the binary is absent. The suite neither builds nor edits the kernel.

The Python requirements and Julia direct dependencies are pinned. Each run saves the Julia manifest, package versions, NumPy's BLAS/LAPACK build configuration, Julia's BLAS configuration, requested thread controls and available readbacks, source hashes, corpus checksums, and raw timing samples. Unknown BLAS versions and unavailable effective thread counts remain explicitly unknown. Local virtual environments, dependency checkouts, and generated runs are gitignored.

## Run

```sh
# Quick integration check, including all requested SDKs:
Benchmarks/performance/.venv/bin/python Benchmarks/performance/run.py --profile smoke

# Primary audit: seven matrix-chain cases and two MPS cases, five samples each:
Benchmarks/performance/.venv/bin/python Benchmarks/performance/run.py --profile focus

# More chain lengths and another MPS size:
Benchmarks/performance/.venv/bin/python Benchmarks/performance/run.py --profile full
```

Results go to a new timestamped directory under `results/`. Use `--out path` to choose a new directory; existing directories are refused. The command returns nonzero for a missing dependency, worker failure, timeout, validation failure, incomplete results, or a change in TN kernel source during the run. A failed run still produces a summary and preserves available logs and validated results.

Useful controls:

```sh
# Select a known workload; values are identical to the same case in its full profile:
Benchmarks/performance/.venv/bin/python Benchmarks/performance/run.py \
  --profile focus --cases chain-n12-d16-real --threads 1 --samples 5 --sample-seconds 0.04

# Run only selected adapters; omitted adapters are shown as unavailable:
Benchmarks/performance/.venv/bin/python Benchmarks/performance/run.py --backends tn,python
```

`--kernel /absolute/path/to/WolframKernel`, `--wolframscript`, `--python`, and `--julia` select executables. `--timeout` is the maximum wall time per backend, including startup. Timings exclude startup. All backends run serially. One thread is requested by default; other applications on the host can still affect measurements. Some native libraries, including this Mac's Accelerate backend, are not visible to threadpoolctl. Their effective thread counts cannot be certified from environment controls; the report explicitly marks this limitation.

If the installed Arrays version is too old, the TN adapter refuses to run by default. To use an isolated source checkout, pass the directory containing its `PacletInfo.wl`:

```sh
Benchmarks/performance/.venv/bin/python Benchmarks/performance/run.py \
  --profile focus --arrays-directory /path/to/Arrays/Arrays
```

This registers the dependency only inside the worker kernel. It does not update installed paclets. `--allow-unsupported-dependencies` is an explicit alternative for a provisional diagnostic; it is recorded prominently and does not establish a supported-environment baseline. No dependencies are downloaded automatically by the runner.

## What is compared

| Workload | Comparison | Costs excluded from timed execution |
|---|---|---|
| Matrix chains | Same binary arrays and left-fold contraction path in every SDK | Input loading, construction, path search, expression preparation |
| Changed values | New first tensor with unchanged nonzero support | New tensor construction |
| Changed support | One previously nonzero entry becomes zero | Tensor construction; Python reuses its shape-based prepared expression |
| Greedy planning | Each library's greedy strategy, with shared dimension-product cost accounting | Numeric contraction; TN still includes extraction and its WXF boundary |
| MPS overlap | Native TN/ITensorMPS versus a prepared generic bra/ket network in Python | Loading, object creation, search and compilation |
| Left canonicalization | Equivalent state and canonicality requirements | Loading and validation; TN uses SVD, ITensorMPS moves the gauge center |

The Julia fixed-chain adapter uses ITensors, the contraction layer on which ITensorMPS operates. Actual MPS overlap and canonicalization call ITensorMPS. Python libraries do not supply the native MPS canonicalization comparison.

These greedy tests are not a best-possible cotengra HyperOptimizer comparison or an equal-search-budget competition. The current corpus targets overhead and cache behavior, not hard two-dimensional path optimization, GPU throughput, or symmetry-sector sparsity.

Prepared Python expressions are built with the supplied path and no constant operands. Changed-value/support inputs are passed as new arrays, so numeric results cannot be cached accidentally. Julia tensor and site/link Index construction is outside execution timing. Every output adapter is checked against shared numeric references before and after timing.

## Cache audit

The TN adapter accesses the private `planKey` and numeric-leaf predicate read-only, with source hashes recorded. A change to those internals can require an adapter update.

It measures full dense keys, full SparseArray keys, diagonal SparseArray keys, precision scans, numeric-leaf checks, and zero-mask hashing independently. Full and diagonal sparse inputs have different support/storage regimes; their times do not represent equal density.

Automatic hit and miss rows both consume the **same precomputed data association**. Hits use a cache dynamically localized and primed outside timing. Misses localize an empty cache on every call; this small `Block` cost is part of the miss timing. New-value hit tests use the same support. Changed-support execution rows use an empty cache; invalidation behavior itself is checked separately by a sequence of calls.

The sequence is base, identical base, changed values, changed support, reversed output order. All results are validated and the expected cache counts are `[1, 1, 1, 2, 3]`. No kernel function is redefined. Cache values are localized with `Block` and discarded after the test.

Automatic may choose a different path than the explicit left fold. Subtracting times from those two tables does not give an exact phase breakdown. Component timings are diagnostics; they also cannot simply be added or subtracted to recover an allocation-free cost model.

## Protocol and output

Inputs use little-endian Float64 components in C order, with separate imaginary files for Complex128. Each case has its own deterministic RNG seed. Binary tensor/reference files have SHA256 and byte-count checks; all workers verify them. A seed alone is never used as cross-language evidence. Reference arithmetic can differ in its final bits on other BLAS/hardware combinations; use corpus checksums to establish input identity.

Each operation gets an untimed validation/warm-up, batch calibration, multiple timed batches, and a final validation. Samples are per-call batch means. The report gives median, minimum, and maximum, not latency percentiles. Error is `norm(actual-reference)/max(1,norm(reference)) <= 1e-10`. Timing never includes correctness checks. Empty-call timings expose each harness's own floor; they are not subtracted.

WL clears system caches once per case; plan-cache miss/hit state is controlled separately. WL measurements have resource guards; the parent enforces a process-group timeout for every backend. It terminates the worker group on timeout, including child kernels. Results contain only scalar summaries and bounded diagnostics.

`summary.md` presents comparisons; `timings.csv` contains all rows; `run.json` combines metadata and validated backend records. Individual backend JSON/log files are retained. Failed/missing rows are never filled with zero or silently treated as passes. `JuliaManifest.toml` captures the resolved Julia environment for replay.

Process-tree RSS is sampled every 50 ms and includes Wolfram's separate child kernel. It covers startup, JIT, loading, validation, and computation. Short peaks can be missed and shared pages can be counted in more than one process. Native launcher high-water RSS and Wolfram's tracked peak memory are also retained under separate names. None is labeled contraction-only memory or largest-intermediate memory.

## Verification

```sh
Benchmarks/performance/.venv/bin/python -m unittest discover -s Benchmarks/performance/tests -v
```

Tests check corpus corruption, binary layout and independent references, stable filtered workloads, invalid numeric outputs, incomplete/mismatched results, malformed paths, and the kernel source guard. The smoke profile is the integration test of the actual WL, Python, and Julia APIs. Timings have no machine-independent pass/fail speed threshold.

Authoritative API references: [cotengra contraction](https://cotengra.readthedocs.io/en/latest/contraction.html), [opt_einsum reusable paths](https://dgasmith.github.io/opt_einsum/getting_started/reusing_paths/), [ITensorMPS](https://itensor.github.io/ITensorMPS.jl/stable/MPSandMPO.html), and [ITensors threading](https://itensor.github.io/ITensors.jl/stable/Multithreading.html).
