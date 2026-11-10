# PEPS independent verification, round 1 of 3

## VERDICT

The workload conclusions are reproduced. One validation boundary requires a small fix; it does not invalidate any stored workload result.

## REPRODUCED

- Reconstructed all 227 original site binaries from the NPZ and checked every manifest shape, byte count and SHA256. All sites are finite real Frobenius-normalized tensors, physical dimension 2. Independent grid reconstruction confirms open boundaries, separate bra/ket virtual bonds and shared physical labels. A separately contracted 3x3 ket wavefunction gives the identical squared norm, 4.9551661468307596e-08.
- Checked every saved path and all 40 cost records against cotengra 0.8.3 `ContractionTree.max_size()` and `contraction_cost()`. These are dense intermediate estimates, not RSS. The reported Automatic/refined sizes reproduce: 6x6 D3 3503.151/21.624 MiB, 6x6 D4 4 TiB/4 GiB, and 8x8 D2 1024/4 MiB. All 14 preflight exclusions exceed 256 MiB and are labeled as unexecuted estimates. The 6x6 D4 case has no numerical reference or completion claim.
- In Wolfram 15.0.1 ARM, called live `automaticPlan` three times per case with empty localized plan cache and `ClearSystemCache[]`. All eight saved Automatic paths reproduce exactly. Returned tensors and labels remain identical and no reduction key is present. Five planner/executor definition hashes and every recorded kernel source hash remain unchanged.
- Replayed both large ArrayDot path comparisons and all four alternate-engine jobs in fresh workers using unchanged supplied drivers, identical reconstructed arrays and saved paths. All completed scalars have relative error at most 4.20e-16. First-call times and three warmed trials are retained. Both actual 5x5 D4 alternate-engine memory-limit outcomes reproduce.

| Workload | Path / engine | Warm median [min, max], s | Outcome |
|---|---|---:|---|
| peps-norm-5x5-D4 | cotengra.random128 | 11.075075 [10.993220, 11.498279] | ok |
| peps-norm-5x5-D4 | cotengra.hyper3s | 4.416215 [4.236550, 4.490881] | ok |
| peps-norm-6x6-D3 | cotengra.random128 | 5.753662 [5.690603, 5.986667] | ok |
| peps-norm-6x6-D3 | cotengra.hyper3s | 0.846927 [0.812244, 0.961277] | ok |
| peps-norm-5x5-D4 | Dot | not completed | memory_limit_768MiB |
| peps-norm-5x5-D4 | ArrayDotTranspose | not completed | memory_limit_768MiB |
| peps-norm-6x6-D3 | Dot | 0.281170 [0.229665, 0.439951] | ok |
| peps-norm-6x6-D3 | ArrayDotTranspose | 0.837147 [0.798353, 1.040172] | ok |

- The recorded one-task search-plus-execution totals are 12.483 versus 8.085 s for 5x5 D4, and 6.973 versus 3.960 s for 6x6 D3. Replayed fixed-path execution preserves both improvements with the recorded search costs. Exact wall times vary with the host; no universal speed threshold is claimed.
- Replayed all seven completed cotengra/NumPy scalar references, with exactly matching values. Large-case medians are 0.654 and 0.122 s. The Accelerate effective thread count remains unavailable, so no full attribution of cross-runtime gaps is supported or claimed.
- The new `peps_audit.py --planning-only` orchestrator completes with unchanged kernel and suite hashes. Earlier execution/engine suite snapshots contain 15/17 files respectively; every recorded file still matches, without requiring later-added file sets to be identical.
- Live kernel usage, options, dependency versions and locations are recorded. Arrays 1.4.2 loads only from the isolated checkout. Five malformed pair paths are rejected. Current corpus references all reject zero; symbolic, Indeterminate and Infinity results are rejected.

## FINDINGS

P2: `Benchmarks/performance/peps_execute.wls:19` and `peps_engines.wls:19` clamp the relative-error denominator to 1e-300. In the live kernel, a zero result with reference `N[10^-310,50]` passes this gate, although its relative error is 1. This contradicts the requested strictly relative tiny-norm rule. The recorded corpus is unaffected: its smallest reference is approximately 1.50e-34, and every recorded completed scalar passes direct relative validation.

## RECOMMENDED FIXES

Reject invalid/nonpositive references and divide directly by `Abs[reference]` in both worker gates. Add a direct boundary check that zero is rejected for a positive reference below 1e-300. Preserve original measurement provenance, because the old floor did not affect any retained reference.

The report correctly treats better search and memory-aware engine selection as proposals. Search optimality, production-workload representativeness and future slicing speedups are not established, and are not claimed as measured results. RSS remains whole-worker memory, with polling and shared-page limitations.

Evidence: `data-checks.json`, `kernel-checks.json`, `replay-results.json`, `python-replay.json`, `final-source-checks.json`, `builtin-usage.json`, all job logs/RSS files, reconstructed inputs under `replay/`, and fresh planning evidence under `orchestrator-planning/`. The saved runner scripts contain exact commands and thread environments. No target artifact was edited.

OPEN ISSUES: 1
