# External TN Package Examples Catalog

Comprehensive catalog of computational examples extracted from the six leading numerical TN+quantum packages. Goal: reproduce each example in the Wolfram TensorNetworks paclet and compare results, building a validation test suite.

Source clones live at `tn-external/numerical/` (gitignored via `.git/info/exclude`).

## Summary

| Package | Examples | Source path | Per-package catalog |
|---|---|---|---|
| quimb | 142 | `tn-external/numerical/quimb/` | [quimb_examples.md](quimb_examples.md) |
| cotengra | 67 | `tn-external/numerical/cotengra/` | [cotengra_examples.md](cotengra_examples.md) |
| ITensors.jl | 41 | `tn-external/numerical/ITensors.jl/` | [itensors_examples.md](itensors_examples.md) |
| ITensorMPS.jl | 134 | `tn-external/numerical/ITensorMPS.jl/` | [itensormps_examples.md](itensormps_examples.md) |
| ITensorNetworks.jl | 41 | `tn-external/numerical/ITensorNetworks.jl/` | [itensornetworks_examples.md](itensornetworks_examples.md) |
| TeNPy | 78 | `tn-external/numerical/tenpy/` | [tenpy_examples.md](tenpy_examples.md) |
| **Total** | **503** | | |

## Cross-package category coverage

| Category | quimb | cotengra | ITensors | ITensorMPS | ITensorNets | TeNPy |
|---|---|---|---|---|---|---|
| tensor algebra / contraction | 22 | — | 6 | — | — | — |
| MPS construction | 11 | — | — | 14 | — | 7 |
| MPS algebra | 12 | — | — | 14 | — | 4 |
| MPO construction | 8 | — | — | 6 | — | 5 |
| MPO algebra | — | — | — | 11 | — | — |
| OpSum / Hamiltonian | — | — | — | 13 | — | — |
| AutoMPO | — | — | — | 7 | — | — |
| PEPS / 2D TN | 11 | — | — | — | 4 | — |
| MERA | 5 | — | — | — | — | — |
| TTN / general-graph TN | — | — | — | — | 14 | — |
| contraction path / cost | 9 | 26 | — | — | 2 | — |
| decomposition | 11 | — | 7 | — | — | — |
| gauge | 7 | — | — | — | 2 | — |
| circuit construction | 13 | — | — | — | — | — |
| gate application / TEBD / METTS | 12 | — | — | 7 | 3 | — |
| expectation value (`expect`/`inner`) | 11 | — | — | 8 | 4 | 5 |
| sampling / measurement | 8 | — | — | 3 | 0 | — |
| optimization | 9 | — | — | — | — | — |
| DMRG (finite + iDMRG) | — | — | — | 23 | 2 | 12 |
| DMRG-X / TDVP | — | — | — | 7 | 2 | 4 |
| model construction | — | — | — | — | — | 14 |
| ground-state energy vs analytic | — | — | — | 6 | — | 6 |
| correlation function | — | — | — | 5 | — | 4 |
| entanglement entropy / Schmidt | — | — | — | 3 | — | 4 |
| symmetry sectors (QN) | — | — | 4 | 6 | — | 3 |
| custom site types | — | — | 3 | 4 | — | 2 |
| observer / sweep callbacks | — | — | — | 5 | — | 2 |
| projector / ProjMPO | — | — | — | 5 | — | — |
| random MPS | — | — | — | 4 | — | — |
| MPS↔dense conversion | — | — | — | 3 | — | — |
| TRG / CTMRG | — | — | 4 | — | — | — |
| benchmark networks | — | 14 | — | — | — | — |
| slicing / SA / reconfigure | — | 17 | — | — | — | — |
| compressed contraction | — | 5 | — | — | — | — |
| BP (belief propagation) | — | — | — | — | 6 | — |
| OpSum → TTN operator | — | — | — | — | 4 | — |
| lattices / sweeps / other | — | — | — | 14 | — | — |

## Tier-1 priority validation tests

The most actionable validation tests — deterministic, exact numerical answers, small enough to run quickly. Group A→G in increasing computational cost.

### A. Pure tensor algebra (instant, exact)

| # | From | What | Expected |
|---|---|---|---|
| A1 | quimb #4, #6, #11, #21 (`tests/test_tensor_core.py`) | rank-3 tensor construction, fuse, isel, transpose | shape & data matches numpy |
| A2 | ITensors.jl #14 (`test/base/test_contract.jl:7-150`) | every rank/permutation contraction pattern (Float64 + ComplexF64) | `array(C)` matches Julia BLAS |
| A3 | ITensors.jl #1 (`README.md:132-167`) | 3-index tensor build & `*` contraction | `hasinds(C, i, k, l) == true` |
| A4 | quimb #15 (`tests/test_tensor_core.py:718-733`) | `qtn.connect` reduces outer indices | `outer_inds()` reduces to 0 |
| A5 | quimb #18 (`docs/tensor/tensor-basics.ipynb`) | `MPS_rand_state(10, 7).H @ self` | 1.0 |

### B. Contraction path / cost (deterministic integer comparisons)

| # | From | What | Expected |
|---|---|---|---|
| B1 | cotengra #19 (`tests/test_paths_basic.py:194-205`) | `optimize_optimal` on lattice[4,5] d_max=3 seed=42, `minimize='flops'` | cost = **1464** (exact integer) |
| B2 | cotengra #19 same, `minimize='size'` | width = **5.584962500721156** (= log2 48) |
| B3 | cotengra #21 (`docs/basics.ipynb`) | 4-tensor demo with HyperOptimizer | cost = **4656**, result is 2×3 array of **6720**'s |
| B4 | cotengra #25 (`tests/test_paths_basic.py:221-243`) | `edgesort` on chain `[(3,2),(2,1),(1,0)]` all bond=2 | path = **`((1,2),(0,1))`** |
| B5 | cotengra #31 (`docs/high-level-interface.ipynb`) | `tree.contract_stats()` on default lattice[4,5] | `{'flops':964, 'write':293, 'size':32}` |
| B6 | quimb #5 (`tests/test_tensor_core.py:1095-1101`) | chain of (8,8) tensors a-b-c shared bonds | `contraction_width()=6, cost=2·8³=1024` |

### C. Decomposition / SVD (exact)

| # | From | What | Expected |
|---|---|---|---|
| C1 | ITensors.jl #41 (`test/base/test_svd.jl:10-19`) | SVD of hand-coded rank-3 4×4 matrix | reconstruction err < 1e-13 |
| C2 | ITensors.jl #19 (`README.md:170-194`) | SVD of random 10×20 matrix | `M ≈ U*S*V` (norm err < 1e-13) |
| C3 | ITensors.jl #23 (`test/base/test_decomp.jl:164-200`) | QR with `positive=true`, all rank slices 0..3 | `A ≈ Q*R`, R diag ≥ 0 |
| C4 | ITensors.jl #26 (`test/base/test_decomp.jl:95-111`) | `truncate!` on `[0.1, 0.01, 1e-13]` cutoff=1e-5 | returns `(1e-13, 5e-3)`, len 2 |
| C5 | quimb #1, #6 (`docs/tensor/tensor-basics.ipynb`) | `tensor_split` SVD, info["error"] == distance | exact match |
| C6 | quimb #8 (`tests/test_tensor_core.py:1322-1334`) | `tensor_compress_bond` reducing two-tensor bond | bond → 4, contraction unchanged |

### D. Small-system analytic (exact ground states)

| # | From | What | Expected |
|---|---|---|---|
| D1 | quimb #4 (optimization) | 2-qubit Heisenberg ground state energy | **-3/4** exactly |
| D2 | quimb PEPS #7 (`docs/tensor/tensor-2d.ipynb`) | 4×4 Heisenberg ground energy / site | **-0.5743254415745597** |
| D3 | quimb other #18 | `bound_spectrum(H_heis(20))` | `(-8.682, 4.75)` |
| D4 | TeNPy #6 (`tfi_exact.py`) | TFIM finite ED energy via sparse Kron | matches analytic |
| D5 | TeNPy #7 (`tfi_exact.py:81-84`) | TFIM dispersion ε(p) = 2√(J²-2Jg·cosp+g²) | gap closes at g=1 |
| D6 | TeNPy #4 (`exercises_uniform_toycodes.ipynb`) | AKLT exact: e₀=-2/3, S=log2, ξ=1/log3 | exact |
| D7 | quimb #11 (`docs/examples/ex_dmrg_periodic.ipynb`) | correlation `<sz_0 sz_1>` on 300-site PBC Heisenberg DMRG | **≈ -0.1565** |

### E. Gate identities & circuit primitives

| # | From | What | Expected |
|---|---|---|---|
| E1 | quimb #8 gate (`tests/test_circuit.py:658-682`) | `circ.apply_gate("x", (2,), controls=(0,1))` | equals `qu.toffoli()` exactly |
| E2 | quimb #8 gate same | `circ.apply_gate("swap", (1,2), controls=(0,))` | equals `qu.fredkin()` exactly |
| E3 | quimb #10 circuit (`tests/test_circuit.py:129-146`) | GHZ-3 prepare via H + CNOTs | `<ψ\|GHZ_3>` = 1 |
| E4 | quimb (`tests/test_circuit.py:154-156`) | `Circuit.from_openqasm2_str(qasm_qft)` 4-qubit QFT | norm = 1.0 |
| E5 | quimb #11 gate (`tests/test_circuit.py:310-348`) | `circ.su4(*15params)` vs explicit decomposition | fidelity = 1.0 |

### F. TN expectation values on simple states (exact)

| # | From | What | Expected |
|---|---|---|---|
| F1 | ITensorNetworks.jl #15 (`test/test_additensornetworks.jl:11-26`) | 2×2 GHZ on grid, ⟨Sz⟩ via state-sum | exactly **0.0** |
| F2 | ITensorNetworks.jl #31 (`test/test_ttn_expect.jl:1-22`) | comb-tree (2,2) alternating Up/Dn product, `expect("Sz")` | per-vertex `±0.5` |
| F3 | quimb #5 MPS algebra (`docs/tensor/tensor-1d.ipynb`) | Neel-state `<Z_i>` for L=20 | `[1,-1,1,-1,...]` |
| F4 | TeNPy #3 expect (`examples/userguide/c_mps_mpo.py:38`) | Heisenberg L=6, Neel state, `H_MPO.expectation_value` | **-1.25** |
| F5 | ITensorMPS.jl MPS-Construction #2 (`test_mps.jl:69-89`) | `MPS(sites, ["Up","Dn",...])` on S=1/2, L=10 | per-site `<Sz_j> = ±0.5` exactly |
| F6 | ITensorMPS.jl AutoMPO #4 (`test_autompo.jl:395-414`) | OpSum Heisenberg vs hand-built MPO | `<ψ\|H_OpSum\|ψ> == <ψ\|H_hand\|ψ>` |
| F7 | ITensorMPS.jl OpSum #13 (`test_autompo.jl:1120-1156`) | HardCore boson L=20 t=1 V1=1e-3 V2=2e-5 on alternating product `\|10101...>` | `<ψ0\|H\|ψ0> = 0.00018` ± 1e-10 |

### G. Algorithmic — DMRG / TRG / CTMRG (slow but high-signal)

| # | From | What | Expected |
|---|---|---|---|
| G1 | TeNPy #1 DMRG (`d_dmrg.py:182-204`) | TFIM finite L=10, g=1, full DMRG | E = **-12.3814899996548** (rel err < 1e-15 vs ED) |
| G2 | TeNPy #2 DMRG (`f_dmrg_finite.py`) | TFIM finite L=16, g=1, χ=100 | E = **-20.01638790048513** |
| G3 | TeNPy #4 DMRG | TFIM iDMRG g=1.5 | E/L = **-1.6719262215362**, ⟨σx⟩=0.87733, ξ=2.42 |
| G4 | TeNPy #5 DMRG (`g_dmrg_infinite.py`) | TFIM iDMRG g=1.1 χ=100 | E = **-1.342864022725017**, ξ = 4.915809146764157 |
| G5 | TeNPy #11 DMRG (notebooks/02) | XXZChain Jz=1.2 sweep L∈{16,32,64,128} | E_∞ → **-0.47364442364092396** |
| G6 | TeNPy #2 entanglement (notebooks/01) | TFIM L=100 critical, fit S(l,L) = (c/6) log[2L/π·sin(πl/L)] | central charge **c = 0.5** |
| G7 | quimb #6 expectation (`docs/tensor/tensor-1d.ipynb`) | DMRG2 L=100 spin-1 Heisenberg, χ=200 | E ≈ **-138.940086** |
| G8 | quimb #7 expectation (`ex_dmrg_periodic.ipynb`) | DMRG2 PBC L=300 Heisenberg | E ≈ **-132.94082** (rel err 4.6e-5 vs analytic) |
| G9 | ITensors.jl #38 (`examples/trg/run.jl`) | TRG 2D Ising at β=1.1·βc, χ=20, 20 steps | κ ≈ **3.071**, m ≈ **0.794** |
| G10 | ITensors.jl #39 (`examples/ctmrg/isotropic/run.jl`) | CTMRG isotropic same β | κ ≈ **3.071**, m ≈ **0.794** |
| G11 | quimb other #21 (`docs/examples/ex_tn_TRG.ipynb`) | TRG 2D Ising at βc, χ=64, 16 iter | f ≈ **-2.10965** (rel err 7e-8 vs Onsager) |
| G12 | TeNPy #4 plane-wave (`vumps_and_plane_wave.py`) | VUMPS + plane-wave dispersion | exactly matches analytic |
| G13 | ITensorMPS.jl DMRG #1 (`examples/dmrg/1d_heisenberg.jl`) | Heisenberg S=1 N=100, default sweeps | E = **-138.94008605883985** (Haldane regime gold) |
| G14 | ITensorMPS.jl DMRG #5 (`test_dmrg.jl:198-247`) | TFI L=32 critical OBC | E = **1 − 1/sin(π/(4N+2))** ≈ **-20.1817** (analytic) |
| G15 | ITensorMPS.jl DMRG #11 (`test_dmrg.jl:416-442`) | Hubbard L=10 N=8 t=1 U=1 V=0.5 | **-8.02 < E < -8.01** |
| G16 | ITensorMPS.jl DMRG #10 | Spinless-fermion N=8 t=1 V=4 | E = **-2.859778** |
| G17 | ITensorMPS.jl Conv #3 (`exact_diagonalization.jl`) | Heisenberg L=14 DMRG vs Krylov ED on fused MPO | DMRG energy matches ED exactly |
| G18 | ITensorMPS.jl TDVP #5 (`test_tdvp.jl:120-171`) | L=4 Heisenberg TDVP τ=0.1 ttotal=1.0 vs `exp(-iτH)` | `\|Sz_tdvp - Sz_exact\| < 1e-5` |

### H. Cross-platform benchmark networks (just topology)

cotengra ships canonical JSON benchmark networks at `tn-external/numerical/cotengra/examples/benchmarks/`. These are gold for round-trip topology + cost-comparison tests:

| File | Tensors | Indices | Type |
|---|---|---|---|
| `cubic_6x6x10.json` | 360 | 924 | 3D cubic lattice |
| `mps_mpo_L100_chi64_D5.json` | 200 | 298 | MPS-MPO sandwich |
| `peps_cluster_r2_D10_a.json` | 32 | 74 | PEPS cluster radius-2 |
| `qucirc_rrzz_n56_d13.json` | 924 | 616 | random RR+ZZ circuit |
| `rand_50_5_a.json` | 50 | 125 | random hypergraph (only one with non-empty output) |
| `randreg_200_3_a.json` | 200 | 300 | random 3-regular graph |
| `rtree_100_a.json` | 100 | 99 | random tree (trivial optimum) |
| `sycamore_n53_m20_s0_e0_pABCDCDAB.json` | 381 | 754 | Google Sycamore depth-20 |

For the WL paclet, write a JSON loader → `BinaryTensorNetwork` adapter and round-trip every benchmark.

## Reference RNG conventions for validation testing

- **quimb** honors `seed=` kwargs in `MPS_rand_state`, `PEPS.rand`, `MERA.rand`, `rand_tensor`, `rand_ket`, `rand_uni`, `rand_herm`. Match seeds on both sides.
- **cotengra** seeds: `RandomGreedyOptimizer(seed=…)`, `rand_equation(seed=…)`, `rand_reg_contract(20, 5, seed=42)`.
- **ITensors.jl** `Random.seed!` for tensor entries plus `Random.seed!(index_id_rng(), …)` for Index ids.
- **TeNPy** uses NumPy RNG via standard `np.random.seed`.
- **ITensorNetworks.jl** uses `Random.seed!(StableRNG(seed))` in tests.

For data-dependent answers (random PEPS contraction, random MPO compression error), always pin a seed and require exact match.

## Skip / non-portable categories

These bundle external dependencies the WL paclet does not have. Either skip these examples or compare only at a coarse level:

- **autodiff-based optimizers** (`quimb.TNOptimizer` with jax/torch/autograd backend) — most "MERA optimization", "PEPS energy minimization", "circuit training" examples
- **GPU primitives** — `cuTensorNet`, anything requiring CUDA/`cupy`
- **Belief-propagation infrastructure** — large parts of ITensorNetworks.jl tests; no BP cache in the paclet today
- **QN / charge-conserving symmetric tensors** — block-sparse machinery; most packages have it (ITensors.jl + ITensorMPS.jl + ITensorNetworks.jl + TeNPy), paclet doesn't yet
- **Bayesian-optimizer hyperparameter search** — cotengra's `HyperOptimizer` with KaHyPar/optuna/cmaes
- **Fermionic / Jordan-Wigner** — TeNPy Hubbard / Haldane / Chern-insulator examples
- **External solvers** — slepc, ARPACK shift-invert (some quimb examples)

## Recommended workflow

1. **Pick a Tier-1 group** (start with A, B, C — these are zero-dependency).
2. For each entry, write a `Tests/external_validation/<source-package>/test_<thing>.wl` script that constructs the same input in WL and asserts the expected output.
3. Run with `wolframscript -file Tests/external_validation/<...>.wl` and compare numerically.
4. Bundle into a `run_external_validation.wl` master runner (akin to existing `run_dataset_test.wl`).
5. Tier-1G (algorithmic checks) requires DMRG / TRG / CTMRG primitives in the paclet — gate these with capability checks if not all present.

## How to refresh this catalog

Re-clone packages with `git clone --depth=1` into `tn-external/numerical/`, then re-run the six validation-audit agents (one per package; see git log for the agent prompts used). Compare the fresh catalog against this one to detect new examples added upstream.
