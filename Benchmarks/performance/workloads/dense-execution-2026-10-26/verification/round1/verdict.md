# VERDICT

PASS within the declared scope: the two archived, connected, closed, binary real PEPS norms on their unchanged refined paths. Independent replay supports a workload-specific numerical execution prototype. It does not establish an integrated paclet improvement, a universal default-method change, a transpose root cause, or a planner improvement.

# REPRODUCED

The complete probe, analysis, provenance and four exploratory records were read. The repository audit was read; its f383b09 anchor is stale, so current Contraction.wl and Utilities.wl and live definitions were used. The current public Method default is ArrayDot (Contraction.wl:745,759,1133; live Options also agrees). The existing ArrayDot and Dot helper signatures and return shapes agree with the source.

All 454 archived tensor specifications across eight cases passed SHA256, byte count, shape and exact NPZ comparison, covering 227 distinct site arrays. All eight archived refined paths passed position validity and final closed-label checks. Every operand has unique labels and every label occurs twice. The manifest and NPZ hashes are retained in preflight.json. The two tested reference scalars also agree with an independent NumPy tensordot contraction on the same archived paths.

Thirty-three numerical workers ran serially. Twenty-four workers provide three fresh one-method repetitions for each of four methods and both cases under the same 2 GiB additional-allocation guard. Method and case order were counterbalanced. Each first measurement follows ClearSystemCache[]; the three subsequent samples in each worker are warm. The remaining nine predeclared workers check the 768 MiB guard, existing Dot, and fused Flatten. Startup and loading are outside the timed expressions; whole-process time and overhead are retained separately. All native thread environment controls and Wolfram's ParallelThreadNumber were one before evaluation. Runtime: Wolfram 15.0.1, Mac OS X ARM64, with the isolated Wolfram/Arrays 1.4.2 entry file confirmed.

| Case | Method, 2 GiB | Cleared first-call seconds, three workers | Warm median seconds, nine calls | Sampled whole-worker peak RSS MiB, range |
| --- | --- | --- | --- | --- |
| 5x5 D4 | public ArrayDot | 5.719, 4.708, 4.622 | 4.416 | 1048-1122 |
| 5x5 D4 | public Dot | 1.910, 1.547, 1.380 | 1.486 | 1456-1529 |
| 5x5 D4 | standalone existing ArrayDot | 6.026, 4.566, 4.011 | 4.587 | 1081-1135 |
| 5x5 D4 | standalone 2D Dot | 1.490, 1.507, 1.312 | 1.197 | 1085-1154 |
| 6x6 D3 | public ArrayDot | 0.799, 0.877, 0.683 | 0.782 | 473-516 |
| 6x6 D3 | public Dot | 0.324, 0.326, 0.219 | 0.290 | 588-620 |
| 6x6 D3 | standalone existing ArrayDot | 0.799, 0.800, 0.702 | 0.737 | 460-508 |
| 6x6 D3 | standalone 2D Dot | 0.217, 0.248, 0.191 | 0.227 | 528-559 |

For these paths, public Dot consistently beats public ArrayDot and standalone 2D consistently beats standalone existing ArrayDot. Public Dot has higher sampled RSS in every matched case. The 5x5 standalone ArrayDot and 2D RSS ranges overlap; a precise memory ranking for that comparison is not established. These are whole-worker measurements including startup and four evaluations, using the existing run.py runner functions verbatim. RSS polling every 50 ms can miss peaks and sums shared pages. Each worker recorded 1-4 RSS sampling exceptions; the runner does not retain exception details. RSS values are approximate observed peaks, not exact memory bounds. Startup, loading, IO and other untimed overhead total 2.87-6.45 seconds per worker.

At 768 MiB, 5x5 public ArrayDot completes; public Dot, standalone existing Dot, standalone 2D Dot and fused Flatten return memory_limit. Those routes complete under 2 GiB. Existing standalone Dot gives a warm median of 1.211 seconds on 5x5 versus 1.197 for the 2D candidate, with overlapping samples. On 6x6, existing standalone Dot gives 0.235 seconds versus 0.227 for the candidate, again with overlapping samples. A new candidate advantage over the existing Dot helper is not established on either case. Fused Flatten's warm median is 3.361 seconds and it fails the smaller guard, so the negative recommendation reproduces. Exact exploratory seconds were checked against the archived raw records; current seconds differ, while the principal rankings persist.

Actual completed WL scalar values and direct relative errors, recomputed from the JSON numbers rather than trusting ok flags:

- 5x5 D4: reference 8.963865307280872e-25; every completed route returns 8.963865307280874e-25; error 2.0490155309093748e-16.
- 6x6 D3: reference 8.017515365910888e-29; public and existing helpers return 8.017515365910885e-29, error 4.1947114048311773e-16; candidate returns 8.017515365910852e-29, error 4.4743588318199224e-15.
- Independent NumPy scalar checks return 8.963865307280874e-25 and 8.017515365910862e-29, with direct errors 2.05e-16 and 3.22e-15 respectively. Their timings are not benchmark comparisons.

The small-tensor suite checks all 36 permutations of a nonadjacent two-label contraction, 12 permutations with all axes of one operand contracted, full vector and matrix contractions, outer products, exact and machine values, unit dimensions, a connected cycle that begins with an outer product, a connected chain, and a symbolic vector contraction. All 408 positive-rank pair comparisons across the four helpers pass against an independent TensorProduct/TensorContract oracle. The candidate's positive-rank label order and shapes match. Connected network examples give 9809, 310 and 214 as independently expected.

All target artifacts and kernel source hashes remain unchanged. Each worker's public function guards and the probe's four private helper guards agree before and after. A further 973-symbol function-definition snapshot covering public and private TN contexts agrees before and after the boundary suite. Final probe SHA256: b4befcbd5678c6637f8c21cbf3d915d9e5f387dffcad984dca695be68129d72d.

# FINDINGS

No unresolved issue within the declared measured PEPS scope.

Informational boundary limitation, probe.wls:39-44 and 56-59: the standalone matrix and fused helpers do not handle rank-0 operands. For example, matrixPair[{2,{}},{-3,{}}] emits ArrayReshape messages and incorrectly returns {2,{}}. A closed disconnected network that first produces two scalar inner products gives 18 instead of 900. Twelve scalar pair checks fail across the two candidates. This is outside the measured connected PEPS paths, whose pair operands have positive rank until the final scalar result. The existing public executor handles scalar operands separately at Contraction.wl:564-566. Incompatible dimensions and empty axes also produce messages or invalid results; these helpers have no general input validation. None of these failures supports treating the prototype as a general contractor.

Non-claims remain untested: production integration, full supported input regression coverage, universal default-call speed, transpose causality, and planner improvement. The artifacts explicitly disclaim those conclusions.

# RECOMMENDED FIXES

No kernel or prototype change is required for the bounded measured conclusions. Keep the scope explicit: positive-rank, dimension-compatible dense pair operands on these connected PEPS paths; a scalar result is supported. Any future integration must preserve the existing rank-0 dispatch and reject or route malformed, zero-dimensional, repeated-label, hyperedge and unsupported container cases before calling the candidate. Retain separate cleared and warm samples, the observed RSS tradeoff, and the workload-specific wording.

Evidence: run.json contains commands, ordered jobs, timing samples, scalar values, guards and process measurements; summary.json contains grouped measurements and independently recomputed errors; boundaries.json and boundaries.log retain all small-case outputs and messages; preflight.json and final-guards.json retain input and source identities. No target artifact was edited.

OPEN ISSUES: 0
