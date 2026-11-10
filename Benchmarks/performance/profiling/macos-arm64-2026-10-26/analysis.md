# Ranked TN bottlenecks

**Priority correction:** these small-component timings did not establish that a kernel change would materially improve a useful workload. The optimization priorities proposed here are withdrawn as production priorities. The [PEPS workload study](../../workloads/peps-2026-10-26/analysis.md) supersedes this ranking; the measurements below remain diagnostic evidence only.

The first small-contraction fix should target repeated label-set operations inside each pair, followed by reusing structural execution metadata. Dense key generation has a separate bottleneck: creating a support mask and paying the first-use hash cost on every cache lookup. Numeric matrix multiplication, cache lookup itself, and packed-array precision queries are lower priorities in these workloads.

Kernel functions were neither edited nor replaced in memory. The profile contains 355 validated measurements, seven samples each, using the same binary input tensors as the earlier comparison. `run.json` records source checksums and the unchanged-definition guard. Times below are median [minimum, maximum] in microseconds.

## Ranking and evidence

| Priority | Bottleneck and scope | Measured evidence | Proposed fix |
|---|---|---|---|
| 1 | Pair label operations, small chains | Eleven Dot-pair contracted-label calculations: 1.13e+03 [1.03e+03, 1.36e+03]; remaining-label calculations: 1e+03 [865, 1.32e+03]. Full prepared TN/Dot: 3.37e+03 [3.13e+03, 4.25e+03]. | Replace general multiset operations with order-preserving membership for already settled unique labels; retain a general fallback where those invariants do not hold. |
| 2 | Dense support signature, large tensors, including warm plan lookup | Full key: 4.65e+03 [4.02e+03, 5.57e+03]; newly created mask/hash: 4.1e+03 [4.01e+03, 5.19e+03]; first hash of freshly prepared masks alone: 6.84e+03 [3.9e+03, 9.91e+03]. | Cache the validated signature on an immutable prepared/network object and invalidate it on data changes; for unprepared inputs, investigate a fused support scan and compact bit-mask hash. |
| 3 | Rebuilding the execution schedule and label metadata | Tree-step conversion: 91.8 [85.3, 108]; label dimensions: 115 [105, 123]; repeated tree predicate: 37.4 [33.9, 43.1]. | Store step order, holder/output maps, axis mappings, shape metadata and selected pair executor with the prepared plan. Bind current arrays at execution time. |
| 4 | Repeated leaf classification and representation checks | Computable leaves: 17.9 [15.4, 22.4]; machine-precision normalization: 20.1 [18.1, 25.7]; integer-scale checks: 17.7 [15.4, 26.2]; representation selection: 10.6 [9.99, 15.3]. | Classify at a checked preparation boundary and retain packed-machine fast paths; keep exact/symbolic/container behavior. |

This ranking gives implementation priority for the requested workloads, not a universal ordering across all network sizes. Different rows are independent, inclusive measurements with overlapping work and timing variance. They cannot be summed or subtracted to claim precise wall-time shares or promised speedups.

## Why pair labels come first

`Contraction.wl:31-39` and `Contraction.wl:110-122` compute the contracted and remaining labels using `SymmetricDifference` and three `DeleteElements` calls for every pair. The step inputs have already passed through `settleLeaf`. On the sampled chain workload they have unique labels, allowing direct ordered membership tests.

| Eleven captured Dot pairs | Time, us |
|---|---:|
| Current contracted-label calculation | 1.13e+03 [1.03e+03, 1.36e+03] |
| Current remaining-label calculations | 1e+03 [865, 1.32e+03] |
| Standalone candidate computing all three label lists | 64.2 [59.5, 71.3] |
| Numeric Dot on the frozen intermediate operands | 16.9 [13.3, 17.6] |
| Position indices | 31.4 [26.6, 46.3] |
| Axis permutations | 29.8 [26, 39] |
| Symbolic dimension queries | 189 [143, 213] |

The candidate uses `Select` and `MemberQ` to preserve input axis order. It matches the source algorithm on every captured real/complex chain pair and on unsorted multiple-shared-axis, disjoint, fully overlapping and empty unique-label examples. It has not replaced a TN function. The component difference is evidence for an optimization target; a kernel patch would still need the full hyperedge, scalar, repeated-index, exact, symbolic, sparse and inactive-expression test suite before an end-to-end speedup claim.

`contractStep` and `contractTreePath` replays remain much slower than the arithmetic. The repeated metadata around each pair is therefore a better first target than changing BLAS or optimizing matrix products for these tiny tensors. Data-association construction is separately measured and is excluded from the prepared execution total.

## Dense keys: first-use hashing matters

`Contraction.wl:945-950` includes `Hash[Unitize[t]]` in every dense leaf signature. `automaticPlan` computes that signature before looking up even a warm entry. Sparse signatures instead hash stored CSR structure. The benchmark compares fully populated sparse inputs as a storage-mechanism diagnostic; converting production dense arrays to sparse solely for keying is not the proposed fix.

| Twelve 256-by-256 real tensors | Time, us |
|---|---:|
| Unitize, without hashing | 404 [363, 746] |
| First hash of fresh masks, preparation excluded | 6.84e+03 [3.9e+03, 9.91e+03] |
| Repeated hash of the same precomputed masks | 2.5 [2.2, 3.96] |
| Precision queries | 2.27 [1.65, 5.01] |
| Numeric-leaf predicate | 16.5 [14.4, 46.1] |
| Additional ArrayQ numeric check | 6.6 [4.44, 9.79] |
| Lookup with an already computed key and association | 0.534 [0.448, 0.585] |

The warm precomputed-mask row is not the cost of hashing a new mask. New masks are allocated outside each timed first-hash sample, hashed exactly once, and checked against the expected result afterward. Unlike the batched rows, that row uses one complete tensor set per sample with no calibration hashes. Its wider range makes exact phase subtraction particularly inappropriate.

Each support mask currently occupies packed integer storage comparable to the original real tensor storage. A fused zero-test and compact support hash could avoid materializing that full integer mask. This is an unimplemented proposal, not a measured speedup. Zero must retain its exact current meaning for real and complex machine inputs; a tolerance-based zero test would change planning semantics.

Reusing a validated support signature needs a clear ownership boundary. An immutable prepared/network object can retain it; changed tensor data must trigger revalidation. Changed values with the same support should still produce the same plan key. Changed support, output order, dimensions, method, precision or container must keep invalidating as appropriate. Raw association inputs should retain the existing safe fallback. A shape-only key is insufficient because diagonal reduction depends on support.

## Prepared execution proposal

`contractTreePath` currently reconstructs holders, dimensions and post-order steps (`Contraction.wl:516-545`). The public tree executor additionally repeats leaf conversion and numeric classification (`Contraction.wl:818-829`). The current cache retains the tree or reduction descriptor, rather than a ready-to-run sequence of axis operations. A richer prepared plan could keep that structural sequence while accepting current tensor values.

Prebuilt inactive-expression activation approaches direct numeric arithmetic in this diagnostic. Its tensor values are embedded, so it is only a lower-bound experiment; it cannot be shipped as a cache of numeric results or reused blindly after tensor updates. The supported fix would separate immutable structural instructions from live values and preserve output ordering, hyperedge handling, representation policy and exact scaling.

## Reproduce and inspect

Run from the repository root, with the dependencies described in the performance suite README:

```sh
Benchmarks/performance/.venv/bin/python Benchmarks/performance/profile_tn.py
```

All rows are in [summary.md](summary.md) and [timings.csv](timings.csv). Captured event counts, deduplicated operand counts, semantic checks, raw samples and unchanged-definition evidence are in [profile.json](profile.json). Source/corpus identity and process metadata are in [run.json](run.json). The isolated Arrays dependency and requested thread policy match the earlier baseline. Timings exclude startup, tracing, input loading and correctness checks; process RSS covers the entire worker and is not contraction-only memory.

## Independent verification

The first independent review passed with zero open issues. It reran all 355 measurements with seven samples, reproduced the ranking, checked the candidate on 4,624 additional ordered unique-label combinations, and tested key invalidation for support, output order, dimensions, method, precision and container. Captured calls remained executable after clearing the original setup variables. All ten regression tests passed, including missing-row and malformed numeric evidence checks. The maximum normalized error was below 8e-16, and source and function-definition guards passed.

The [verification report](verification/verification-report.md), [independent run](verification/run.json), [comparison](verification/comparison.json), and supplemental kernel checks preserve the evidence. No kernel functions were changed. These checks establish the scoped profile and the standalone candidate's stated domain; they do not establish an implemented end-to-end speedup or general kernel replacement.
