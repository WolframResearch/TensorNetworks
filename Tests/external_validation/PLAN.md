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

62 tests, 0 failures, 11 skips properly recorded. See `SKIPPED_AND_MISSING.md` for the live state.

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

### Tier-2 (PROPOSED) — strict direct external comparison

Goal: lift specific numerical answers from the catalog and use them as oracles. ~30-40 new paclet tests, raising `paclet_primitives/` coverage from 38 to ~70.

| New file | Focus | Direct-validation targets |
|---|---|---|
| `cotengra_benchmarks.wl` | Path cost on cotengra's 8 JSON benchmark networks | lattice[4,5] cost=**1464**, 4-tensor demo cost=**4656**, contract_stats={flops:964,write:293,size:32} |
| `tensor_algebra_edge.wl` | Edge cases for EinsteinSummation/IndexedMultiply | empty contraction, single-index, dimension-mismatch error, rank>6 |
| `tn_expectations_canonical.wl` | TN expectations on known states | Bell `<XX>=<YY>=-<ZZ>=1`, GHZ-N `<Z_i Z_j>=1`, W-state expectations |
| `mps_canonical_states.wl` | MPS with known analytic answers | GHZ MPS S=log(2) half-bond, AKLT MPS C(n)=(1/3)^(n-1), product-state Schmidt={1,0,...} |
| `contraction_paths_exact.wl` | Path-shape and integer-cost match against cotengra | edgesort path={(1,2),(0,1)}, exact integer cost match, `ContractionTree` round-trip |

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
| 7 | Tier-2 direct-validation expansion (5 new files, ~30-40 tests) | proposed |
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

## 8. Open decisions

These are choices that would change scope or shape; surfaced for explicit decision before further work:

1. **Direct vs indirect tier-2 split.** Should Tier-2 explicitly require direct-validation (every test cites a specific external numerical answer), or accept indirect-validation for cases where the external value is also analytic? Recommended: strict-only for Tier-2 to make the distinction visible.
2. **Path-cost convention reconciliation.** *Audited 2026-05-08:*
   - **cotengra** (`core.py:1196-1227`): `total_flops(dtype=None)` returns mul-count "ops"; `dtype="float"` doubles it (`real_flops = 2·ops`); `dtype="complex"` quadruples it (`complex_flops = 4·ops`). Default `minimize="flops"`.
   - **paclet (Rust optimizer)** (`Cotengra/src/lib.rs:115-132, 847`): `compute_flops` returns log of the product of all unique dims involved per step (matching cotengra's per-step `_flops` linearly). Default `minimize="flops"`.
   - **paclet (Mathematica wrapper)** (`TensorNetworks.wl:112-118`): default `Method -> "size"` — explicitly overrides the Rust default. The convention itself is identical to cotengra's `dtype=None` (no real/complex scaling).
   - **Open paclet design question** (not a validation work item): should the wrapper default change from `"size"` to `"flops"` to match cotengra and the underlying Rust default? Pros: matches user expectations, proxies wall-time. Cons: behavior change for existing users; current `"size"` minimizes peak memory.
   - **Validation work item:** add `paclet_primitives/contraction_paths.wl` test pinning down per-step cost matches cotengra's mul-count convention on a fixed 3-tensor chain (small enough that per-step flops are computable by hand).
3. **CI integration.** `run_external_validation.wl` exits 0/1 and is invokable directly. Should it be added to `Tests/run_tests.wl`'s discovery, or live as a separate CI step? Recommended: separate step, since it imports external clones and may be slower.
4. **Test-ID renaming.** Current IDs use `tier1a-A1-name` format from when everything was Tier-1. After the paclet/baseline split, IDs like `paclet-tensor-A1-conjugate` would be clearer. Decision pending; currently keep as-is for catalog cross-reference traceability.
5. **Catalog freshness.** The catalog was extracted in May 2026. Re-extracting after upstream package updates is a separate workflow (the audit-agent prompts are reproducible from git history). Recommended cadence: after each major external-package release, or quarterly.

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
