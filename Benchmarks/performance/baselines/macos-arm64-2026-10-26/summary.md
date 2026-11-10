# TensorNetworks performance audit

Status: **ok**

Kernel commit: `6facfdab999fb1fe95925c50ee4724e1d1c0701c`. Kernel unchanged during run: `True`.
Suite unchanged during run: `True`.
Corpus SHA256: `4d64a094ef2581c78215a93936b6fadc4f8d26506c0db9add8d0fa34156ebd84`.

Times are median [minimum, maximum] of per-call batch means. No percentiles or statistical significance are inferred.

## Backend status

| Backend | Status | Sampled process-tree peak RSS |
|---|---|---:|
| tn | ok | 269.3 MiB |
| python | ok | 64.7 MiB |
| julia | ok | 1342.1 MiB |

Requested threads: 1. NumPy BLAS build: accelerate, version unknown.
NumPy effective BLAS thread readback: unavailable.
Effective BLAS thread count unavailable: threadpoolctl detected no supported BLAS pool. Environment settings are requested controls, not verified counts.

RSS sums the launcher and descendants, including the separate Wolfram kernel. Sampling every 50 ms can miss peaks and shared pages can be counted more than once. This includes imports, JIT, loading, warm-up and validation; it is not contraction-only memory.

## Small contractions: same data and left-fold path

Input loading, object/index construction, path search and expression preparation are excluded.

| Case | WL Dot | TN Dot | TN ArrayDot | opt_einsum | cotengra | ITensors |
|---|---:|---:|---:|---:|---:|---:|
| chain-n2-d2-real | 0.882 [0.795, 1.46] us | 527 [439, 591] us | 536 [504, 630] us | 8.27 [6.41, 11.5] us | 3.65 [3.43, 4.18] us | 0.832 [0.753, 1.22] us |
| chain-n2-d16-real | 1.26 [1.2, 1.53] us | 502 [411, 709] us | 531 [460, 594] us | 9.03 [8.51, 10.1] us | 5.21 [4.65, 6.18] us | 1.42 [1.34, 1.71] us |
| chain-n4-d8-real | 1.59 [1.46, 2.68] us | 1.14 [0.983, 1.7] ms | 1.31 [1.22, 1.9] ms | 28.8 [25, 34.8] us | 8.63 [7.87, 12.7] us | 2.54 [2.46, 3.18] us |
| chain-n12-d16-real | 8.4 [6.76, 9.52] us | 3.71 [3.25, 4.52] ms | 4.23 [3.51, 4.39] ms | 86.3 [65.9, 102] us | 43.9 [39.3, 50.9] us | 14.7 [14.6, 16.3] us |
| chain-n12-d64-real | 345 [311, 460] us | 5.15 [3.38, 6.94] ms | 4.52 [4.16, 4.91] ms | 97.1 [88.5, 114] us | 64.2 [61.4, 67.3] us | 302 [293, 328] us |
| chain-n12-d256-real | 10.6 [9.14, 11.8] ms | 12.1 [11.9, 15.1] ms | 22.5 [19.9, 27.6] ms | 2.12 [1.22, 2.7] ms | 1.68 [1.18, 1.72] ms | 9.86 [9.01, 11] ms |
| chain-n12-d16-complex | 20.4 [16.3, 26.3] us | 4.28 [3.46, 4.93] ms | 3.68 [3.01, 4.56] ms | 125 [96.4, 160] us | 62.1 [55.5, 79.2] us | 26.2 [25, 30.6] us |

## Cache keys and automatic execution

Cold and warm Automatic both receive the same precomputed data association. Automatic may choose a different path than the fixed-path table; do not subtract these tables to attribute phases.

| Case | Dense key | Full sparse key | Diagonal sparse key | Zero-mask hash component | Automatic hit | Automatic miss |
|---|---:|---:|---:|---:|---:|---:|
| chain-n2-d2-real | 8.07 [6.63, 9.56] us | 7.59 [6.85, 8.2] us | 8.19 [7.11, 9] us | 1.88 [1.6, 2.53] us | 579 [553, 590] us | 740 [647, 963] us |
| chain-n2-d16-real | 10.4 [10.2, 12.2] us | 7.72 [6.17, 9.21] us | 6.88 [6.19, 9.3] us | 5.9 [5.41, 6.95] us | 588 [466, 653] us | 804 [666, 864] us |
| chain-n4-d8-real | 14.6 [13.3, 19.8] us | 16.1 [12.5, 22.1] us | 12.9 [12.4, 13.5] us | 4.52 [4.33, 4.77] us | 1.28 [0.994, 1.38] ms | 1.62 [1.43, 1.78] ms |
| chain-n12-d16-real | 57.9 [55.5, 62.7] us | 34.1 [30.1, 36.1] us | 36.4 [33, 39.9] us | 31.4 [23.5, 34.1] us | 3.83 [3.35, 4.29] ms | 4.7 [4.18, 6.51] ms |
| chain-n12-d64-real | 417 [290, 461] us | 36.4 [31.4, 38.2] us | 39.2 [30.2, 45] us | 354 [303, 399] us | 5.62 [5.24, 6.22] ms | 5.36 [5.23, 6.38] ms |
| chain-n12-d256-real | 4.97 [4.34, 7.58] ms | 37.5 [32.5, 41.8] us | 35.7 [33.2, 37.7] us | 5.54 [4.65, 6.85] ms | 27 [25.1, 34.2] ms | 30.7 [23.4, 33.2] ms |
| chain-n12-d16-complex | 59.6 [48.4, 88.4] us | 39.3 [30, 43.5] us | 32.9 [30.2, 42.8] us | 30.7 [24, 36.7] us | 3.87 [3.53, 4.69] ms | 4.75 [4.5, 5.33] ms |

Full sparse keys use fully populated SparseArrays; diagonal sparse keys use one stored diagonal per tensor. These measure different support/storage regimes, not equal sparse density.

## Greedy planning

These are greedy algorithms, not equal-time-budget hyperoptimizer searches. TN includes parameter extraction and its WXF boundary; Python planners receive shapes. Terms use one common dimension-product convention, not SDK-specific FLOP counters.

| Case | Planner | Search time | Scalar product terms | Largest intermediate elements |
|---|---|---:|---:|---:|
| chain-n2-d2-real | tn | 248 [219, 296] us | 8 | 4 |
| chain-n2-d2-real | opt_einsum.numpy | 10.6 [8.42, 11.7] us | 8 | 4 |
| chain-n2-d2-real | cotengra.numpy | 7.82 [7.19, 9.55] us | 8 | 4 |
| chain-n2-d16-real | tn | 225 [213, 281] us | 4096 | 256 |
| chain-n2-d16-real | opt_einsum.numpy | 11.8 [9.4, 14.4] us | 4096 | 256 |
| chain-n2-d16-real | cotengra.numpy | 7.93 [6.33, 10.1] us | 4096 | 256 |
| chain-n4-d8-real | tn | 300 [246, 405] us | 1536 | 64 |
| chain-n4-d8-real | opt_einsum.numpy | 53.3 [51.2, 55] us | 1536 | 64 |
| chain-n4-d8-real | cotengra.numpy | 37 [29.2, 42.8] us | 1536 | 64 |
| chain-n12-d16-real | tn | 688 [558, 814] us | 45056 | 256 |
| chain-n12-d16-real | opt_einsum.numpy | 184 [163, 190] us | 45056 | 256 |
| chain-n12-d16-real | cotengra.numpy | 113 [92.1, 118] us | 45056 | 256 |
| chain-n12-d64-real | tn | 578 [540, 629] us | 2883584 | 4096 |
| chain-n12-d64-real | opt_einsum.numpy | 157 [139, 181] us | 2883584 | 4096 |
| chain-n12-d64-real | cotengra.numpy | 102 [88.4, 135] us | 2883584 | 4096 |
| chain-n12-d256-real | tn | 649 [460, 741] us | 184549376 | 65536 |
| chain-n12-d256-real | opt_einsum.numpy | 205 [193, 226] us | 184549376 | 65536 |
| chain-n12-d256-real | cotengra.numpy | 111 [105, 116] us | 184549376 | 65536 |
| chain-n12-d16-complex | tn | 596 [490, 642] us | 45056 | 256 |
| chain-n12-d16-complex | opt_einsum.numpy | 157 [148, 181] us | 45056 | 256 |
| chain-n12-d16-complex | cotengra.numpy | 104 [100, 152] us | 45056 | 256 |

## MPS tasks

Overlap uses native MPS APIs for TN and ITensorMPS. Python libraries contract a prepared bra/ket network; their algorithms and path can differ. Canonicalization compares equivalent output requirements, not the same decomposition algorithm.

| Case | TN overlap | ITensorMPS overlap | opt_einsum overlap | cotengra overlap | TN canonical | ITensorMPS canonical |
|---|---:|---:|---:|---:|---:|---:|
| mps-n6-d4-real | 3.67 [3.25, 4.96] ms | 99.8 [85, 126] us | 74.7 [64.7, 87.7] us | 78.4 [65.3, 89.6] us | 548 [506, 619] us | 178 [148, 215] us |
| mps-n8-d8-complex | 6.24 [5.59, 7.05] ms | 148 [142, 179] us | 121 [101, 136] us | 142 [102, 192] us | 933 [816, 1.21e+03] us | 335 [241, 394] us |

## Validation and interpretation

Validated rows: 260. Failed rows: 0.
Each timed operation is validated before and after timing. Normalized error uses norm(error)/max(1,norm(reference)) <= 1e-10.
Cache observations, component timings, planner timing, raw samples, versions, thread settings, and process logs are in run.json and the backend JSON files.
Private plan-key measurements are tied to the recorded source hash and may need adapter updates when internals change.

