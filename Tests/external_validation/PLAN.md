# External-Validation Test Plan

This document is the single source of truth for the external-validation test strategy: scope, structure, tiers, phases, what's done, what's deferred, and what's open. Update this document when the plan changes; the implementation files and `SKIPPED_AND_MISSING.md` should remain consistent with it.

## 1. Goal

Verify the Wolfram TensorNetworks paclet against the leading numerical TN+quantum packages (quimb, cotengra, ITensors.jl, ITensorMPS.jl, ITensorNetworks.jl, TeNPy) so that:

1. Paclet primitives produce the same numerical answers as their external counterparts on canonical inputs.
2. Capability gaps (features absent from the paclet) are explicitly recorded, distinguishing "missing feature" from "test bug."
3. Tests that cannot be reproduced cross-language (e.g. RNG-dependent) are recorded as such and not flagged as failures.

The catalog (`EXAMPLES_CATALOG.md` + per-package files) captures **503** examples across the six packages; this plan describes which of those translate into actual tests and how.

## 2. Direct vs indirect definition of "external validation"

This distinction matters and was clarified mid-implementation:

- **Indirect validation** (what most tests do today): "External package P returns Y on input X. Paclet on input X returns Y'. Compute Y independently in Mathematica from the same X. Verify Y' == Y." Catches gross paclet bugs but anchors to Mathematica's internal computation, not P's.
- **Direct validation** (what we should aspire to): "P returns specific value Y_P on X (a number lifted directly from the catalog). Paclet returns Y'. Verify Y' == Y_P within tolerance." Anchors to the external package's actual output.

Tier-1 is mostly indirect-validation. Tier-2 (proposed) adds direct-validation tests where the catalog has hard numbers.

## 3. Two-group structure

```
Tests/external_validation/
  paclet_primitives/   <- tests that genuinely call paclet symbols
  baselines/           <- Mathematica-native sanity checks against catalog values; no paclet calls
```

The directory is the source of truth for classification. A test in `paclet_primitives/` MUST exercise at least one symbol from `Wolfram\`TensorNetworks\`*`. A test in `baselines/` documents that the catalog's expected value is reachable in Mathematica generally (e.g. via `Eigenvalues` on a dense Hamiltonian) and serves as a feasibility check before adding a paclet-side equivalent.

Reasoning:
- Paclet regression coverage is unambiguous — count tests in `paclet_primitives/` and that's your number.
- Baselines act as ready-made templates: when paclet adds DMRG, swap `Eigenvalues[H]` for `paclet_DMRG[H]` and the test moves to `paclet_primitives/`.

## 4. Tiers

### Tier-1 (DONE) — broad shallow coverage

62 tests, 0 failures. (Live suite total now 95 with Tier-2 included; see `SKIPPED_AND_MISSING.md` for the up-to-date skip log.)

| Group | File | Tests | Description |
|---|---|---|---|
| paclet | `tensor_algebra.wl` | 17 | EinsteinSummation + ActivateTensors patterns |
| paclet | `contraction_paths.wl` | 10 | OptimalContractionPath / GreedyContractionPath validity + cost ordering |
| paclet | `tn_expectations.wl` | 2 | TensorNetwork + TensorNetworkContract on product states |
| paclet | `mps.wl` | 9 | MPSCanonicalForm / Overlap / Schmidt / Truncate (random inputs) |
| baseline | `decomposition.wl` | 6 | SVD/QR/truncate via Mathematica primitives |
| baseline | `analytic_grounds.wl` | 7 | Dense `Eigenvalues` for small Hamiltonians (Heisenberg, TFIM, AKLT) |
| baseline | `gate_identities.wl` | 7 | Gate matrix identities (HZH=X, Toffoli, QFT unitarity) |
| baseline | `state_expectations.wl` | 4 | Product-state expectations via vector arithmetic |

### Tier-2 (DONE — 5 of 5 files) — direct external-value validation

30 new direct-validation tests across 5 files, raising `paclet_primitives/` coverage from 38 to 71.

| File | Tests | Direct-validation targets |
|---|---|---|
| `cotengra_benchmarks.wl` | 5 + 2 RNG | 4-tensor demo cost=**4656**, all-ones contraction=**6720**, path shape, chain bond=2 cost=**16**, pentagon cost=**28** |
| `tn_canonical_states.wl` | 5 + 1 RNG + 1 missing | Bell `<Z_1>=0`, Bell `<Z_1 Z_2>=1`, GHZ-3 `<Z_2>=0`, GHZ-3 `<Z_1 Z_3>=1`, alternating product `<Sz_j>=±0.5` |
| `mps_canonical_states.wl` | 6 + 2 missing | bond-1 Schmidt=**{1.0}**, bond-1 entropy=**0**, bond-D entropy ≤ log(D), mixed-canonical preserves overlap, AKLT transfer eigvals `{1,-1/3,-1/3,-1/3}`, AKLT ξ=**1/log(3)** |
| `tensor_algebra_edge.wl` | 7 | identity trace=**N**, squeeze size-1 shape, hyper-4 identity-delta, vec-ones self-dot=**N**, all-ones trace=**N**, rank-4·rank-4=**(d_i·d_j)** entries, named-axis transpose shape |
| `contraction_paths_exact.wl` | 7 | 2-tensor path=**{{1,2}}**, chain-5 length=**4**, star-4 length=**4**, edgesort length=**2**, triangle length=**2**, single-tensor empty path, optimal path 4-tensor → all-ones contracted = ones×6720 |

### Tier-3 (DEFERRED) — algorithmic primitives the paclet doesn't have yet

Gated by paclet feature additions. When the paclet adds DMRG / TRG / CTMRG / TDVP, these tests promote from baselines or new files:

- DMRG ground-state energies (TFIM L=10 → -12.3814..., Heisenberg S=1 N=100 → -138.94...)
- TRG free energy (Onsager 2D Ising → -2.10965)
- Isotropic CTMRG magnetization (β=1.1·βc → m≈0.794)
- TDVP vs `exp(-iτH)` agreement
- Specific iDMRG infinite-system answers (TFIM g=1.5 → E/L=-1.6719262215362)

Currently recorded as `RecordSkipMissing` entries in `SKIPPED_AND_MISSING.md` so the gap is visible.

## 5. Phases (original plan, executed)

The build was structured as discrete phases to keep work incremental. All Tier-1 phases are complete.

| Phase | Description | Status |
|---|---|---|
| 0 | `Helpers/ValidationHelpers.wl` — capability gating, skip recording, ValidationClose | done |
| 1 | Tier-1A tensor algebra — `paclet_primitives/tensor_algebra.wl` | done |
| 2 | Tier-1B contraction paths — `paclet_primitives/contraction_paths.wl` | done |
| 3 | Tier-1C decomposition — `baselines/decomposition.wl` | done |
| 4 | Tier-1D analytic ground states — `baselines/analytic_grounds.wl` | done |
| 5 | Tier-1E gate identities — `baselines/gate_identities.wl` | done |
| 6 | Tier-1F TN expectations — split: `paclet/tn_expectations.wl` + `baselines/state_expectations.wl` | done |
| 6+ | Tier-1G MPS — `paclet_primitives/mps.wl` | done |
| 7 | Tier-2 direct-validation (5 files, 30 new tests) | done |
| 8 | Optional: live cross-language oracle subdir (opt-in) | deferred |

## 6. Skip categories and their meanings

Auto-tracked in `SKIPPED_AND_MISSING.md`. Three classes:

- **SkipRNG** — Cross-language RNG reproducibility is impossible. NumPy uses PCG64, Julia uses Xoshiro256++, Mathematica has its own; same seed gives different streams. Use `SkipDueToRNG[id, reason, source]`.
- **SkipMissing** — Paclet lacks a required symbol. Use `WithCapability[{symbols}, id, source, body]` (auto-records if any symbol missing) or `RecordSkipMissing[id, syms, source]` for explicit. **Important:** this is a feature gap, NOT a bug. Distinguishes from Error.
- **Error** — Unexpected exception during a test. This IS a bug. Auto-recorded via `RecordError`.

## 7. Live cross-language oracles (Phase 8, deferred)

For tests where:
1. No analytic answer exists, AND
2. The numerical answer requires running an external package, AND
3. RNG-dependence is mild enough to mock (e.g. fixed-step Simple Update with a deterministic init)

Right shape:
- Separate subdir `oracles/` with Python/Julia driver scripts that dump JSON
- Paclet test loads the JSON and asserts agreement
- Marked opt-in via env flag (`PARITY_LIVE=1`) — does not run by default
- Used sparingly (~10-20 cases max)

Not on the current TODO list. Estimated effort: 2-3 days plus ongoing maintenance burden as upstream packages drift.

## 8. Settled decisions

Recorded for posterity; live behavior follows these rules.

1. **Direct vs indirect Tier-2.** *Decided: direct-only.* Tier-2 tests must lift a specific numerical answer from the catalog (e.g. cotengra cost = 1464, ITensorMPS energy = -138.94008605883985) and assert the paclet output equals that exact value. Tests where the expected value is computed in Mathematica from analytic formulas belong in `baselines/` or stay in Tier-1.

2. **Path-cost convention.** *Audited 2026-05-08; resolved.*
   - **cotengra** (`core.py:1196-1227`): `total_flops(dtype=None)` returns mul-count "ops"; `dtype="float"` doubles it (`real_flops = 2·ops`); `dtype="complex"` quadruples it (`complex_flops = 4·ops`). Default `minimize="flops"`.
   - **paclet Rust optimizer** (`Cotengra/src/lib.rs:115-132, 847`): `compute_flops` returns `log(product of all unique dims involved)` per step (matching cotengra's per-step `_flops` linearly). Default `minimize="flops"`.
   - **paclet Mathematica wrapper** (`TensorNetworks.wl:112-118`): default `Method -> "size"` — explicitly overrides the Rust default. Per-step convention itself matches cotengra's `dtype=None` exactly.
   - Pinned in tests `paclet-paths-Bcost1` (chain optimal flops = 64), `paclet-paths-Bcost2` (closed triangle = 30), `paclet-paths-Bcost3` (wrapper default is `"size"`).
   - **Open paclet design question** (not a validation work item): should the wrapper default change from `"size"` to `"flops"`? Pros: matches cotengra and the Rust default; proxies wall-time. Cons: behavior change for existing users; current `"size"` minimizes peak memory.

3. **CI integration.** *Decided: separate step.* `run_external_validation.wl` runs as its own CI job (not part of `Tests/run_tests.wl` discovery) because it depends on the cloned external packages in `tn-external/` and is slower than the in-paclet test suite. Local runs: `wolframscript -file Tests/external_validation/run_external_validation.wl`. Exit code 0 on all-pass, 1 on any failure or unexpected error.

4. **Test-ID convention.** *Decided: rename from tier-prefixed to group-prefixed.*

   Old format: `tier1a-A1-conjugate`, `tier1c-C5-truncate-cutoff-tuple`
   New format: `<group>-<file>-<original-letter+num>-<short>`
   - `paclet-tensor-*` ← was `tier1a-*` (paclet_primitives/tensor_algebra.wl)
   - `paclet-paths-*` ← was `tier1b-*` (paclet_primitives/contraction_paths.wl)
   - `paclet-tn-*` ← was `tier1f-F5..F8` (paclet_primitives/tn_expectations.wl)
   - `paclet-mps-*` ← was `tier1g-*` (paclet_primitives/mps.wl)
   - `baseline-decomp-*` ← was `tier1c-*` (baselines/decomposition.wl)
   - `baseline-analytic-*` ← was `tier1d-*` (baselines/analytic_grounds.wl)
   - `baseline-gates-*` ← was `tier1e-*` (baselines/gate_identities.wl)
   - `baseline-state-*` ← was `tier1f-F1..F4` (baselines/state_expectations.wl)

   The group/file is now visible in the test ID, so the skip log and test output read clearly without cross-referencing. The original letter+number (A1, B5, Cost1, etc.) preserves cross-reference to the per-package catalog entries.

5. **Catalog freshness.** *Decided: after each major external-package release, or quarterly (whichever first).* Cadence is a re-extraction trigger; the audit-agent prompts are reproducible from git history. Re-running the agents and diffing the new per-package `_examples.md` against the old reveals upstream changes worth tracking.

## 9. How to extend

To add a tier file:

1. Decide group: does the test exercise a paclet symbol? `paclet_primitives/`. Otherwise `baselines/`.
2. Use the loader pattern at the top of any existing file.
3. Each test: `WithCapability[{required_symbols}, id, source, body]` for paclet tests, plain `VerificationTest` otherwise.
4. For RNG-dependence: `SkipDueToRNG[id, reason, source]`.
5. For missing features that aren't auto-detected: `RecordSkipMissing[id, syms, source]`.
6. Add the file name to `run_external_validation.wl`'s `testGroups` list.
7. Run the master runner. Commit the regenerated `SKIPPED_AND_MISSING.md`.

## 10. References

- **Catalogs:** `Tests/external_validation/EXAMPLES_CATALOG.md` (master index) + `<package>_examples.md` (per-package)
- **Implementation conventions:** `Tests/external_validation/Helpers/ValidationHelpers.wl`
- **Live skip log:** `Tests/external_validation/SKIPPED_AND_MISSING.md` (auto-generated)
- **Memory:** `~/.claude/projects/.../memory/reference_external_validation_suite.md` (cross-session pointer to this work)
