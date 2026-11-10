# VERDICT

PASS. The revised validation and original-measurement provenance claims hold, and the PEPS report's load-bearing numerical, path-memory, execution-ranking, and allocation-guard claims reproduced. No target artifact or TN function definition was edited.

# REPRODUCED

- Wolfram 15.0.1, MacOSX-ARM64; isolated Wolfram/Arrays 1.4.2; Python 3.14.0, NumPy 2.5.4, cotengra 0.8.3. `kernel-checks.json` retains live signatures, options, planner return shape, package information, and unchanged DownValues fingerprints.
- All eight networks have the declared real d=2 open-boundary PEPS norm topology. All 227 unique Frobenius-normalized site tensors regenerate exactly from the declared seeds and reproduce every archived binary SHA256/length. All 40 saved paths and both cost metrics agree with independent index simulation and cotengra.
- Both current worker validators pass all 20 probes each: matching 50-digit 1e-310 accepted; zero rejected against that reference; malformed, infinite, zero, and negative references/invalid values rejected. Intentional nonreal-reference probes emit Less::nord and return False; messages were not hidden.
- All 27 retained numerical rows satisfy direct relative error <1e-9 with finite positive reference. Minimum original reference is 1.4985049712010843e-34, safely above the former 1e-300 floor. Original changed worker files and their measurement-table hashes match the separately retained originals; current hashes also match.
- Replayed all seven NumPy reference jobs (first plus three warm calls), all 18 saved ArrayDot jobs, and all four alternate-engine jobs. All 20 expected TN successes passed; the two expected failures again report memory_limit_768MiB. Maximum new TN warm relative error is 7.11e-16; maximum independent NumPy reference discrepancy is 1.43e-16.
- Three fresh-kernel planning trials reproduce every saved TN greedy and Automatic path, using existing planner definitions, per-case ClearSystemCache[], and localized private caches. Every >256 MiB path has an explicit preflight exclusion. The reported Automatic/refined capacities reproduce: 5x5 D4 2 GiB/256 MiB; 6x6 D3 3.42 GiB/21.6 MiB; 6x6 D4 4 TiB/4 GiB; 8x8 D2 1 GiB/4 MiB.

New timing trials, using the unchanged workers and saved paths:

| Workload / engine | Path | First call, s | Warm samples, s | Warm median, s |
|---|---|---:|---|---:|
| 5x5 D4 ArrayDot | random128 | 14.679 | 15.669, 16.326, 13.179 | 15.669 |
| 5x5 D4 ArrayDot | refined | 6.176 | 5.751, 5.620, 7.180 | 5.751 |
| 6x6 D3 ArrayDot | random128 | 7.071 | 6.779, 6.808, 7.068 | 6.808 |
| 6x6 D3 ArrayDot | refined | 0.943 | 1.236, 1.026, 0.835 | 1.026 |
| 6x6 D3 Dot | refined | 0.406 | 0.405, 0.387, 0.563 | 0.405 |
| 6x6 D3 ArrayDotTranspose | refined | 1.393 | 1.376, 1.165, 0.950 | 1.165 |

Startup/loading are excluded from these in-kernel call times and retained separately in each process_wall_seconds field. Each worker clears system caches before its first call. The archived medians/ranges and RSS table agree arithmetically with retained records; new wall times drift, but all claimed causal rankings reproduce.

Three new random128 search trials reproduce the exact saved seeded paths: 5x5 D4 0.256/0.315/0.217 seconds, 6x6 D3 0.566/0.475/0.246 seconds. Three unseeded refined searches take 3.007/3.059/3.006 and 3.086/3.067/3.218 seconds. Including these search costs still preserves the one-off advantage in both demonstrated cases. Unequal search effort, unobserved effective NumPy Accelerate threads, path-estimate versus RSS distinctions, and absence of slicing/optimality/production-trace claims are disclosed in the report.

# FINDINGS

None unresolved. Full claim/example inventory: `claim-inventory.md`. Scope exclusions are explicit: no claim of globally optimal paths, production representativeness, exact attribution of the NumPy/TN gap, or implemented slicing was made, so those are not treated as successes or missing verification.

Commands, from repository root:

```sh
Benchmarks/performance/.venv/bin/python Benchmarks/performance/results/peps-verification-round2/check_data.py
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 BLIS_NUM_THREADS=1 wolframscript -local '/Applications/Wolfram 15.01.app/Contents/MacOS/WolframKernel' -file Benchmarks/performance/results/peps-verification-round2/kernel_checks.wls
Benchmarks/performance/.venv/bin/python Benchmarks/performance/results/peps-verification-round2/replay_jobs.py
Benchmarks/performance/.venv/bin/python Benchmarks/performance/results/peps-verification-round2/replay_planning.py
```

All Python replay scripts set native thread controls to 1 before imports. Numeric and planning workers ran serially; Wolfram launches used the required sandbox escalation. Outputs, exact child commands, messages, timing samples, process durations, RSS, and before/after hashes are in `data-checks.json`, `additional-source-checks.json`, `kernel-checks.json`, `replay-results.json`, `planning-results.json`, `before.json`, `after.json`, and corresponding logs. The initial data-check script had a verifier-only KeyError while looking for a later-added source in an earlier measurement table; its corrected final run and all planned checks completed successfully.

# RECOMMENDED FIXES

None required for the verified scope.

OPEN ISSUES: 0
