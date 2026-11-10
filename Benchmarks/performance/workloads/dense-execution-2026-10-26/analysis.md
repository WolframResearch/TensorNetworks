# Dense execution inside the TN paclet

The intended improvement is inside the paclet: faster execution through its existing public API. External path generation is not that improvement. This probe holds tensors and the saved refined contraction path fixed and investigates the numerical engine independently of path quality.

## What is being tested

The current public defaults use `Method -> "ArrayDot"`. `einsumArrayDot` lowers each binary pair to `ArrayDot`; `einsumDot` uses the existing transpose/reshape/Dot route. The standalone 2D candidate collapses all free axes on each side and all contracted axes into an actual matrix multiplication, then restores the output shape. It does not replace TN definitions.

The standalone executor runs the same closed real PEPS norm path with either the existing TN pair helper or the candidate helper. Public API calls are separate controls. Agreement with the scalar reference is checked using direct relative error. These are synthetic binary real PEPS cases, not all supported TN inputs.

## Exploratory observations

For 6x6 D=3, under the 768 MiB benchmark allocation guard, the public ArrayDot median was 1.023 s, the standalone existing ArrayDot route 0.866 s, the existing Dot route 0.347 s, and the standalone 2D route 0.248 s. All completed scalars agreed with the reference within 4.5e-15 relative error.

For 5x5 D=4 the Dot routes hit that same allocation guard. This is an audit-imposed cap, not a paclet limit. Under a 2 GiB benchmark guard, the public ArrayDot median was 5.152 s and public Dot 1.550 s. The standalone existing Dot and 2D routes were both about 1.02 s; the new 2D route did not demonstrate an advantage over existing Dot on this case. These exploratory runs were separate workers and have host timing variance.

The fused Flatten experiment took about 4.06 s under the larger guard and failed under the smaller guard. It has not demonstrated a worthwhile benefit.

## Candidate paclet change and limits

The concrete internal target is the active dense numeric pair dispatch in `Contraction.wl`, particularly `contractTensorPair` and the default evaluated contraction route. Prototype internal use of the existing Dot lowering for eligible dense numerical pairs, keeping forced methods and noneligible input semantics intact. The public default currently selects ArrayDot; the faster Dot route is already implemented. A decision must account for materialization memory: the fast route exceeded the original benchmark guard on one case. A global switch to Dot has not been established as appropriate.

The new standalone 2D helper did not demonstrate a reproducible advantage over the existing Dot helper. Rewriting that numerical route is therefore not justified by this probe. The evidence supports prototyping default dispatch using existing code, followed by integration and supported-input regression checks.

This does not demonstrate an integrated paclet speedup yet. The standalone prototype omits some TN orchestration, and all comparisons use a fixed saved path. The existing default planner can still choose an expensive path. Integration, regressions across supported inputs, and a useful memory policy remain unimplemented. No TN kernel function or in-memory definition was changed.

The prior report's 768 MiB engine failures are valid bounded outcomes, but they cannot be used to reject a method independently of the memory available to an actual application. Its broad recommendations about planning, engine selection, caching, and slicing were not validated implementation changes.

## Independent replay

Verification converged in one round. Three counterbalanced fresh workers per method used identical saved paths and inputs, the same 2 GiB additional-allocation guard, one cleared first call and three subsequent calls. The [full verdict](verification/round1/verdict.md) and [grouped results](verification/round1/summary.json) retain all samples and source/definition guards.

| Workload | Public route | Median cleared first call, s | Median of nine warm calls, s | Sampled whole-worker peak RSS, MiB |
|---|---|---:|---:|---:|
| 5x5 D=4 | ArrayDot | 4.708 | 4.416 | 1048–1122 |
| 5x5 D=4 | Dot | 1.547 | 1.486 | 1456–1529 |
| 6x6 D=3 | ArrayDot | 0.799 | 0.782 | 473–516 |
| 6x6 D=3 | Dot | 0.324 | 0.290 | 588–620 |

These are public API comparisons with an explicit fixed refined path, isolating execution. They are not measurements of an implemented new default or a changed planner. Peak RSS includes startup and all four calls, can miss brief peaks, and can double-count shared pages; each worker also had a few RSS polling exceptions. Values are approximate observed peaks, not exact temporary-allocation counts or memory bounds. The allocation guard is a different quantity.

The candidate standalone 2D route had cleared medians 1.490 s and 0.217 s, compared with 4.566 s and 0.799 s for the same standalone executor using the existing ArrayDot helper. That supports a dense numerical fast-path experiment but does not identify transposes as the root cause. The scalar results agree within 4.5e-15 direct relative error. No candidate advantage over existing Dot was established on either case.

The standalone candidate supports positive-rank, dimension-compatible pair operands on the measured connected PEPS paths, including a final scalar result. It fails for scalar operands: an out-of-scope disconnected example returned 18 instead of 900. The existing public `contractStep` handles scalar operands separately; integration must preserve that branch and all other supported input semantics. Malformed and empty arrays are also outside this prototype's supported scope.

Input tensors and paths are the prior PEPS study's archived values. The probe source, its hash, exploratory records, and independent evidence are retained alongside this report. No kernel files or TN definitions changed.
