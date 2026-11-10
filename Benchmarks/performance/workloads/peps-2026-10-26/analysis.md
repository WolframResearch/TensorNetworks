# PEPS bottlenecks that affect workload feasibility

The earlier small-contraction timings did not establish a worthwhile optimization priority. This workload study establishes path sensitivity and engine tradeoffs on PEPS cases; it does not establish a validated paclet implementation change or the order in which such changes should be made. Small dispatch and plan-key costs have not been shown to be limiting these PEPS workloads. The [dense execution probe](../dense-execution-2026-10-26/analysis.md) investigates a specific internal execution candidate.

These are exact norms of real, random open-boundary PEPS with physical dimension 2. Each site tensor is Frobenius-normalized; the same binary values and saved paths are used across runtimes. The bra/ket network contains twice the number of grid sites. This is a representative synthetic PEPS workload, not a trace of the user's production application.

## 1. Path quality crosses a memory wall

| Grid and bond dimension | TN Automatic-selected path: largest dense intermediate | Best cotengra path found in this run | Execution outcome |
|---|---:|---:|---|
| 5x5, D=4 | 2 GiB | 256 MiB | Better path completes inside TN: 5.05 s |
| 6x6, D=3 | 3.42 GiB | 21.6 MiB | Better path completes inside TN: 0.949 s |
| 6x6, D=4 | 4 TiB | 4 GiB | Both excluded by the execution memory budget |
| 8x8, D=2 | 1 GiB | 4 MiB | Better path completes inside TN: 0.6 s |

The memory columns are derived by walking the saved paths and counting the exact number of entries in each intermediate, at eight bytes per real value. They are not measured peak RSS, a proof of optimality, or observed OOMs. Paths above a 256 MiB largest-intermediate threshold were excluded before numeric execution. Completed TN calls also had a 768 MiB additional-allocation guard and 30-second time limit.

The Automatic selector prices only a small family of candidate paths and bounds intermediate size relative to the default path, rather than by an absolute memory budget (`Contraction.wl:954-989`). In these cases that leaves a path outside this study's execution budget even though a much smaller path exists. This is a capacity limitation: the issue is whether the contraction fits, not saving a few microseconds.

Possible planning experiments include an explicit intermediate/working-memory budget and a larger search family. Neither has been validated as a TN implementation improvement here. A memory cap alone can reject a path without finding a faster one. Passing an externally prepared path uses the existing API but is a workflow workaround, not a paclet optimization. The reported searches use different effort budgets, so this does not establish that TN greedy and cotengra's multi-trial/refined search received equal search effort.

## 2. Path quality saves whole seconds in unchanged TN

All rows below use TN's existing ArrayDot engine, the same tensors, and explicit paths. Three warmed trials follow a separate first call. Planning time is separate and must be added for a one-off task.

| Workload | Path search | Search time, s | TN execution median [min, max], s | Largest intermediate, MiB |
|---|---|---:|---:|---:|
| peps-norm-5x5-D4 | cotengra.random128 | 0.173 | 12.3 [12, 12.7] | 256 |
| peps-norm-5x5-D4 | cotengra.hyper3s | 3.03 | 5.05 [4.94, 5.13] | 256 |
| peps-norm-6x6-D3 | cotengra.random128 | 0.393 | 6.58 [6.54, 6.71] | 73 |
| peps-norm-6x6-D3 | cotengra.hyper3s | 3.01 | 0.949 [0.869, 1.27] | 21.6 |

The refined path improves time to solution even after adding its recorded search cost for both of these examples. If a topology is reused, only then may search be amortized over repeated contractions. On smaller grids the recorded TN executions are already short, and a multi-second search can cost more than it saves; those cases do not justify this change by themselves.

## 3. Existing engines trade execution time for temporary memory

| Fixed workload and cotengra refined path | Engine | Outcome | Median, s | Sampled process-tree peak RSS, MiB |
|---|---|---|---:|---:|
| peps-norm-5x5-D4 | ArrayDot | ok | 5.05 | 1.1e+03 |
| peps-norm-5x5-D4 | Dot | memory_limit_768MiB | not completed | 1.37e+03 |
| peps-norm-5x5-D4 | ArrayDotTranspose | memory_limit_768MiB | not completed | 1.57e+03 |
| peps-norm-6x6-D3 | ArrayDot | ok | 0.949 | 486 |
| peps-norm-6x6-D3 | Dot | ok | 0.276 | 619 |
| peps-norm-6x6-D3 | ArrayDotTranspose | ok | 0.884 | 587 |

Dot helps on one large workload but exceeds the explicit allocation budget on the other; ArrayDot completes the latter within that same guard. The 768 MiB cap belongs to this benchmark, not TN. These outcomes do not reject Dot for an application with more memory and do not establish an appropriate universal default. Transpose/reshape/materialization costs have not been isolated in this study. RSS is sampled across startup, loading and execution, and shared pages can be counted more than once. The allocation guard and RSS are different quantities; the table is not a count of contraction-only temporary bytes.

On the identical refined paths, cotengra/NumPy takes about 0.67 s for the 5x5 D=4 case and 0.12 s for 6x6 D=3 in this run. This residual cross-runtime gap is observed but not fully explained: the native BLAS stacks differ and NumPy's effective Accelerate thread count is unavailable. The within-TN path and engine comparisons provide the stronger causal evidence.

## 4. Limits remaining after better planning

The best found 6x6 D=4 path still has a multi-GiB intermediate and was not numerically executed here. More search or slicing should be investigated before assuming this is the minimum achievable memory. Exact slicing trades additional work for lower memory; approximate boundary contraction would change the accuracy contract and needs a separate user-facing choice. This study does not claim either is implemented or promise a speedup for them.

## Evidence and replay

Independent verification converged in two rounds. The [final report](verification/round2/verdict.md) reproduces both large path comparisons, both actual engine allocation-limit outcomes, all saved TN paths, the input archive and path costs. Its fresh execution medians were 15.67 versus 5.75 s for 5x5 D=4 and 6.81 versus 1.03 s for 6x6 D=3. Host timing variance changes the absolute values; the path ranking and one-off benefit after search costs held in both independent replays.

The [first review](verification/round1/report.md) found a validation floor for references below 1e-300. Current worker gates require a finite positive reference and divide directly by its magnitude; the final review checks the tiny-reference boundary. Every retained corpus reference exceeds 1.49e-34, so the original results were unaffected. Original measured worker sources remain in [measurement-sources](measurement-sources/), with their hashes distinguished from current source hashes in evidence.json.

No TN kernel functions were changed. Every completed scalar was checked with relative error against a cotengra contraction of identical tensors; the denominator uses the reference magnitude, so tiny PEPS norms do not pass on absolute tolerance alone. Raw first/warm timings, paths, plan costs, input checksums, explicit exclusions and actual resource-limit failures are retained in the JSON files.

The [input archive](site-tensors.npz) stores every site tensor under its original binary filename. Writing each array back as C-order little-endian Float64 reproduces its manifest SHA256. [manifest.json](manifest.json), [execution.json](execution.json), [engines.json](engines.json), and [evidence.json](evidence.json) separate measured execution from path-derived estimates. Largest-intermediate estimates are independently cross-checkable with cotengra ContractionTree.max_size().

From the repository root, after the existing suite dependency setup:

```sh
Benchmarks/performance/.venv/bin/python Benchmarks/performance/peps_audit.py \
  --out Benchmarks/performance/results/peps-replay
```

Use `--planning-only` to generate paths and memory estimates without executing contractions. A future unseeded three-second search may find different paths; replay the saved manifest paths to reproduce these exact execution comparisons.
