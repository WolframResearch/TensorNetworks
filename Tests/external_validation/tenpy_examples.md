# TeNPy Validation-Test Catalog

Source: `tn-external/numerical/tenpy/`. Especially valuable because examples often have known analytic-limit answers (Ising, XXZ, free fermions).

**Total examples cataloged: 78**

**Per-category counts:**
- Model construction (Ising / XXZ / Heisenberg / Hubbard / Bose-Hubbard / Fermi-Hubbard / Kitaev): 14
- MPS construction: 7
- MPS algebra: 4
- MPO construction: 5
- DMRG (finite / iDMRG): 12
- TDVP (finite / infinite): 4
- TEBD: 9
- Ground state energy vs analytic: 6
- Expectation value: 5
- Correlation function: 4
- Entanglement entropy / spectrum: 4
- Structure factor / spectral function: 1
- Charge / symmetry sectors: 3
- Lanczos / Krylov: 1
- Custom site types: 2
- Observer / measurement callbacks: 2
- Other (purification, segment BC, plane-wave excitations, central charge, mixer studies): 7

## 1. Model construction

### Ising / TFIM

1. **TFIModel toy code (finite)** — Source: `doc/toycodes/tenpy_toycodes/b_model.py:7-87`. Builds bond list `H_bonds[i] = -J ZZ - g X` and 3×3×2×2 MPO `W` with entries `Id, Z, -gX | -JZ | Id` for transverse-field Ising in 1D. Inputs: L, J, g, bc∈{finite,infinite}. Output: H_bonds list, H_mpo list. WL-portable: Yes.
2. **TFIChain (TeNPy)** — Source: `examples/d_dmrg.py:19-20`, `examples/userguide/f_dmrg_finite.py:8`, `doc/notebooks/00_tebd.ipynb` cell-4. Class `tenpy.models.tf_ising.TFIChain` with params `{L, J, g, bc_MPS}`. Hamiltonian convention: `H = -J Σ XX - g Σ Z` (note: Pauli X·X coupling, not Z·Z). WL-portable: Yes.
3. **TFIModel 2D Square cylinder** — Source: `examples/v1_publication/tfi_cylinder.py:160-170`. Params: `lattice='Square', Lx=2, Ly∈{4,6,8}, bc_y='cylinder', bc_MPS='infinite', J, g`. WL-portable: Partial (needs cylinder geometry).
4. **TFI 2D — yaml form** — Source: `examples/v1_publication/tfi_cylinder.yaml:1-26`. Sweep g via `np.linspace(2,4,101)`. WL-portable: Partial.
5. **Toric Code on DualSquare lattice** — Source: `doc/notebooks/11_toric_code.ipynb`, cells 5-7, extends `tenpy.models.toric_code.ToricCode`. Hamiltonian `H = -Σ_p B_p - Σ_s A_s` with optional Wilson/'t Hooft loop terms `J_WL, J_HL` and field `h`. Inputs: `Lx=1, Ly∈{2..6}, bc_MPS=infinite, conserve=None`. WL-portable: Partial.

### XXZ / Heisenberg / Spin

6. **XXZChain (NN AFM)** — Source: `tenpy/models/xxz_chain.py` (referenced in `examples/userguide/d_model_1D.py`, `examples/z_exact_diag.py:15`). Params `Jxx, Jz, hz, L, bc_MPS, sort_charge`. Hamiltonian `H = ½ J(S+S- + h.c.) + Jz Sz·Sz - hz Σ Sz`. WL-portable: Yes.
7. **SpinChain (XXZ + fields)** — Source: `examples/d_dmrg.py:146-159`, `examples/e_tdvp.py:20-32`, `examples/v1_publication/heisenberg_tebd.py:15-21`, `examples/advanced/xxz_corr_length.py:19-20`. Generic spin chain via `tenpy.models.spins.SpinChain` or `SpinModel`. Params `S, Jx, Jy, Jz, hx, hy, hz, muJ, bc_MPS, conserve∈{Sz, parity, None, best}`. WL-portable: Yes.
8. **SpinModel on Kagome 2D** — Source: `examples/userguide/e_model_2D.py:5-16`. Params `S=0.5, lattice='Kagome', Ly=2, bc_y='cylinder', bc_MPS='infinite', Jx=Jy=Jz=1, conserve='Sz'`. WL-portable: Partial.
9. **SpinChainNNN2 (NN+NNN spin chain)** — Source: `examples/c_tebd.py:134-186` (TFI NNN), `doc/notebooks/12_dmrg_mixer.ipynb`. Params `Jx, Jy, Jz, Jxp, Jyp, Jzp, hz, L, bc_MPS, conserve`. Used in conjunction with `group_sites` for NN-style TEBD. WL-portable: Yes.
10. **SpinHalfSite explicit Heisenberg MPO** — Source: `examples/a_np_conserved.py:80-88`, `examples/b_mps.py:52-63`, `examples/userguide/c_mps_mpo.py:27-37`. Builds 5×5 grid `[[Id,Sp,Sm,Sz,-hz·Sz], [None,...,½Jxx·Sm], [...,½Jxx·Sp], [...,Jz·Sz], [...,Id]]`. AFM Heisenberg with `Jxx=Jz=1, hz=0.2`. WL-portable: Yes.
11. **AnisotropicSpin1Chain (custom)** — Source: `examples/model_custom.py:19-48`. `H = J Σ S_i·S_{i+1} + B Σ Sx + D Σ (Sz)²`. Pollmann-Turner spin-1 model, arXiv:1204.0704. WL-portable: Yes.
12. **AKLT-style spin-1 from explicit `A_L`** — Source: `doc/toycodes/exercises_uniform_toycodes.ipynb` (Part 1.2). Implements `H = S·S + ⅓(S·S)² = 2P_{S=2} - 2/3` with exact MPS `A_L^{+1}=√(2/3)σ⁺`, `A_L^0=√(1/3)σ_z`, `A_L^{-1}=-√(2/3)σ⁻`. WL-portable: Yes.
13. **ExponentiallyDecayingHeisenberg** — Source: `examples/advanced/mpo_exponential_decay.py:24-112`. `H = Σ exp(-(j-i-1)/ξ) [½Jxx(SpSm+h.c.) + Jz SzSz] - hz Σ Sz`. Defaults `Jxx=1, Jz=1.5, ξ=0.8`. Demonstrates `MPO.from_grids`. WL-portable: Yes.
14. **DipolarSpinChain (S=1)** — Source: `tests/test_tebd.py` (`test_tebd_dipole_conservation`), introduced in `doc/intro/npc.rst`. Conserves dipole moment `P = Σ r_i q_i`. Three- and four-body couplings `J3, J4`. WL-portable: No (charge framework dependent).

### Hubbard / Fermi-Hubbard

15. **FermiHubbardModel / FermiHubbardModel2** — Referenced in `doc/notebooks/31_multispecies_models.ipynb` and `tenpy/models/hubbard.py`. WL-portable: Partial.
16. **FermionicHaldaneModel (spinless C=1)** — Source: `examples/chern_insulators/haldane.py:56-110`. Honeycomb t1, t2 (complex), Peierls flux, V interaction. Parameters: `t1=-1, t2 = (√129/36)·t1·exp(iφ_band-flat)`, where `φ = arccos(3√(3/43))`. WL-portable: No (requires charge conservation + complex phases).
17. **BosonicHaldaneModel (hardcore boson FCI)** — Source: `examples/chern_insulators/haldane_FCI.py:121-141`. 1/4 filling, ν=1/2. WL-portable: No.
18. **FermionicC3HaldaneModel** — Source: `examples/chern_insulators/haldane_C3.py:79-122`. C=3 Chern insulator, tripartite triangular, fermions. WL-portable: No.
19. **FermionicPiFluxModel** — Source: `examples/chern_insulators/chiral_pi_flux.py:56-92`. π-flux on bipartite square; t1·exp(iπ/4), t2/√2. WL-portable: No.

(Items 17-19 are more advanced; the catalog is dominated by Ising/Heisenberg/XXZ which are fully WL-portable.)

## 2. MPS construction

1. **`init_FM_MPS(L, d=2, bc)`** — `doc/toycodes/tenpy_toycodes/a_mps.py:148-155`. All-up product state, `B[0,0,0]=1`, `S=[1]`. Output: `SimpleMPS`. WL-portable: Yes.
2. **`init_Neel_MPS(L, d=2, bc)`** — `a_mps.py:158-170`. Alternating up/down. WL-portable: Yes.
3. **`init_PM_MPS(L)` (paramagnetic +x)** — `doc/toycodes/solution_3_dmrg.ipynb` (and exercise). `B[0,0,0]=B[0,1,0]=1/√2`. WL-portable: Yes.
4. **`MPS.from_product_state(sites, state, bc)`** — `examples/d_dmrg.py:21-23`, `examples/userguide/c_mps_mpo.py:12`. Generic: e.g. `['up','down']*(L//2)` for Neel. WL-portable: Yes.
5. **`MPS.from_lat_product_state(lat, [['up']])`** — `doc/notebooks/00_tebd.ipynb` cell-5, `examples/v1_publication/tfi_cylinder.py:174`. Builds product on lattice unit-cell. WL-portable: Yes.
6. **Explicit `npc.Array` Neel MPS with charge legs** — `examples/a_np_conserved.py:38-51`. Builds `B_even, B_odd` with `LegCharge` (Sz charges), demonstrates block-sparse construction. WL-portable: Partial (no full charge support yet in Wolfram).
7. **`UniformMPS.from_desired_bond_dimension(D, d=2)`** — `doc/toycodes/tenpy_toycodes/f_umps.py:143-148`. Random injective tensor → canonical form via successive QR/SVD. WL-portable: Yes.

## 3. MPS algebra

1. **`get_theta1(i)` / `get_theta2(i)`** — `a_mps.py:47-60`. Effective wavefunctions in mixed canonical form. WL-portable: Yes.
2. **`split_truncate_theta(theta, chi_max, eps)`** — `a_mps.py:173-214`. SVD + truncate + renormalize, returns `(A, S, B)`. WL-portable: Yes.
3. **`overlap` between two MPS** — `examples/z_exact_diag.py:42`, `doc/notebooks/11_toric_code.ipynb` cell-12. Asserts `<ψ_ED_mps|ψ_DMRG>=1` to 1e-13. WL-portable: Yes.
4. **`canonical_form()` / `convert_form('B')` / `enlarge_mps_unit_cell` / `apply_local_op`** — `examples/advanced/tfi_segment.py:54-58`, `examples/c_tebd.py:100`. WL-portable: Yes.

## 4. MPO construction

1. **TFI 3×3 W tensor** — `b_model.py:74-87`. Verifiable analytic form. WL-portable: Yes.
2. **AFM Heisenberg 5×5 W grid** — `examples/userguide/c_mps_mpo.py:27-37`. Expected `<Neel|H|Neel> = -1.25`. WL-portable: Yes.
3. **`MPO.from_grids(sites, grids, bc, IdL=0, IdR=-1)`** — `examples/userguide/c_mps_mpo.py:34-37`, `examples/advanced/mpo_exponential_decay.py:84-110`. Three equivalent grid syntaxes (npc array / `[("OpName", strength)]` tuples / bare op name strings). WL-portable: Yes.
4. **`add_coupling`/`add_onsite`/`add_multi_coupling`** — `tenpy/models/xxz_chain.py:14-19`, `examples/model_custom.py:42-48`. Pattern: `add_coupling(0.5*J, u1, 'Sp', u2, 'Sm', dx, plus_hc=True)` and `add_coupling(Jz, u1, 'Sz', u2, 'Sz', dx)`. WL-portable: Yes.
5. **`MPO.expectation_value(psi)` / `MPOEnvironment(psi, H, psi).full_contraction(L-1)`** — `examples/userguide/c_mps_mpo.py:38`, `examples/b_mps.py:74`. WL-portable: Yes.

## 5. DMRG (finite / iDMRG)

1. **Finite TFIM DMRG, L=10, g=1** — `doc/toycodes/tenpy_toycodes/d_dmrg.py:182-204`, run in `toycode_example_calls.ipynb`. **E_DMRG = -12.3814899996548**, exact (ED) `-12.3814899996548`, relative err `4e-16`, χ-profile `[2,4,8,14,19,14,8,4,2]`. 10 sweeps. WL-portable: Yes.
2. **Finite TFIM DMRG, L=16, g=1, χ=100** — `examples/userguide/f_dmrg_finite.py`. **E = -20.01638790048513**, max bond dim 27. WL-portable: Yes.
3. **Finite TFIM DMRG, L=100, g=1 (critical)** — `doc/notebooks/01_dmrg.ipynb` cell-6. **E = -126.96187673968092**, max χ=90, 5 sweeps. Used for central-charge fit `c≈0.5` from `S(l,L) = (c/6) log(2L/π · sin(πl/L))`. WL-portable: Yes.
4. **Infinite TFIM iDMRG, g=1.5** — `d_dmrg.py:207-230`, `toycode_example_calls.ipynb`. **E/L = -1.6719262215362** (matches analytic to 6.6e-16), `<σx>=0.87733, <σz>=0`, ξ=2.42, χ=30. 20 sweeps. WL-portable: Yes.
5. **Infinite TFIM iDMRG, g=1.1, L=2 unit cell, χ=100** — `examples/userguide/g_dmrg_infinite.py`. **E = -1.342864022725017**, max χ=56, ξ=4.915809146764157. WL-portable: Yes.
6. **One-site (SingleSite) finite/infinite DMRG, TFIM** — `examples/d_dmrg.py:48-143`. Same model, requires `mixer=True, active_sites=1`. Same E expected as 2-site. WL-portable: Yes.
7. **Infinite XXZ Heisenberg DMRG, Jz=1.5, S=½, χ=100** — `examples/d_dmrg.py:146-183`. Conserve='best', Neel start, returns `<Sz>≈0` (Sz-conservation), correlation length, `corr = correlation_function('Sz','Sz', sites1=range(10))`. WL-portable: Partial (needs Sz sector).
8. **Infinite XXZ DMRG, varying Jz from 4→0.85** — `examples/advanced/xxz_corr_length.py:18-61`. Sweeps Jz, plots `exp(-1/ξ)` vs Jz. Result: ξ diverges at Jz=1 (Heisenberg). WL-portable: Yes.
9. **TFIM phase transition sweep, infinite DMRG** — `examples/advanced/tfi_phase_transition.py:17-82`. Sweeps g over [0.5, 1.5] (extra dense around g=1), records `E, S, <σz>, <σx_0σx_i>, ξ, fidelity`. WL-portable: Yes.
10. **Central charge from S(ξ) scaling, TFIM iDMRG** — `examples/advanced/central_charge_ising.py:21-67`. Critical g=1, sweeps χ=7..29, fits `S = (c/6) log ξ + const`. **Expected c=0.5**. WL-portable: Yes.
11. **Sequential Heisenberg DMRG with χ ramp** — `doc/notebooks/02_simulation.ipynb`. XXZChain Jxx=1, Jz=1.2, finite L∈{16,32,64,128}. **E/L extrapolated = -0.47364442364092396** (vs iDMRG `-0.47365599058122143`). WL-portable: Yes.
12. **Toric Code iDMRG** — `doc/notebooks/11_toric_code.ipynb`, cell-9. 4-fold degenerate ground state via `J_WL, J_HL ∈ ±5`. **E/site = -1**, `S = (Ly-1)·log 2` (topological entropy γ=log 2). WL-portable: Partial.

Additional ED comparison: `examples/z_exact_diag.py:14-46` runs XXZChain L=10, Jxx=1, Jz=1, hz=0, charge sector from Neel; verifies `|<ψ_ED|ψ_DMRG>|=1` to 1e-13.

## 6. TDVP (finite / infinite)

1. **Finite 2-site TDVP on Heisenberg, L=14** — `examples/e_tdvp.py:16-71`. `S=0.5, conserve='Sz', Jx=Jy=Jz=1`, χ=20, dt=0.1, 30 steps, then switch to 1-site for next 30 steps. Tracks center-bond entropy and `H_MPO.expectation_value`. WL-portable: Partial.
2. **Toy TDVP on TFIM lightcone, L=20, g=1.5** — `doc/toycodes/tenpy_toycodes/e_tdvp.py:342-380`. Uses DMRG ground state, applies σz at center, real-time evolves with 1- or 2-site TDVP, plots S(i,t) lightcone, tmax=3, dt=0.05, χ=50. WL-portable: Yes.
3. **uTDVP infinite, global quench TFIM** — `doc/toycodes/tenpy_toycodes/h_utdvp.py:15-30`. Uses VUMPS ground state at g₁, evolves under H(g₂). WL-portable: Yes.
4. **`tenpy-run` minimal_TDVP.yml** — `examples/yaml/minimal_TDVP.yml`. SpinChain L=32, Jz=1, Neel start, `TwoSiteTDVPEngine`, dt=0.05, final_time=1, χ=120. WL-portable: Yes.

## 7. TEBD

1. **Finite TEBD imag-time TFIM, L=10, g=1** — `c_tebd.example_TEBD_gs_tf_ising_finite`, `c_tebd.py:52-74`. dt schedule [0.1, 0.01, 0.001, 1e-4, 1e-5], 500 steps each. **E = -12.38148414093407** (vs ED `-12.3814899996548`, rel err 4.7e-7). χ-profile `[2,4,8,14,19,14,8,4,2]`. WL-portable: Yes.
2. **Infinite TEBD imag-time TFIM, g=1.5** — `c_tebd.example_TEBD_gs_tf_ising_infinite`. **E/L = -1.6719249672500** (analytic `-1.6719262215362`, rel err 7.5e-7), `<σx>=0.87733, <σz>≈0`, ξ=2.41, χ=21. WL-portable: Yes.
3. **Infinite TEBD via TeNPy TFIM, g=1.5, χ=30** — `examples/c_tebd.py:52-85`, `examples/userguide/h_tebd_infinite.py`. Same expected energies. WL-portable: Yes.
4. **TEBD lightcone TFIM, L=20, g=1.5, tmax=3** — `c_tebd.py:103-135`, `examples/c_tebd.py:88-131`. Initial state from finite DMRG at g=1.5; apply σz at center; real-time evolve with dt=0.01, 4th-order Trotter; image of S(i,t). WL-portable: Yes.
5. **Critical TFIM real-time L=30, g=1, tmax=5** — `doc/notebooks/00_tebd.ipynb`. Init `|↑↑…↑>` (global quench from g=∞), order=4, dt=0.1, χ=100. Linear S(t) growth, conservation `<X>=0` (parity), expanding `<X_i X_{L/2}>` correlations. WL-portable: Yes.
6. **TEBD with NNN spin chain via `group_sites`** — `examples/c_tebd.py:134-186`, `tests/test_tebd.py`. Group sites pairwise then `NearestNeighborModel.from_MPOModel`. WL-portable: Partial.
7. **2nd-order Trotter `run_TEBD_second_order`** — `doc/toycodes/exercises_uniform_toycodes.ipynb` Part 3. `U(dt) = e^{-iH_odd dt/2} e^{-iH_even dt} e^{-iH_odd dt/2} + O(dt³)`. WL-portable: Yes.
8. **Heisenberg dynamics from Neel state** — `examples/v1_publication/heisenberg_tebd.py:57-83`. SpinChain L=50, Jx=Jy=Jz=1, dt=0.02, N_steps=5, 200 measurement intervals (final t≈20). χ∈{50,100,200,400,800}. Measures S(t), `<Sz_i>(t)` profile, imbalance `½⟨Sz_even - Sz_odd⟩`, truncation error. WL-portable: Yes.
9. **`tenpy-run` minimal_TEBD.yml** — `examples/yaml/minimal_TEBD.yml`. SpinChain L=32, Jz=1, Neel, dt=0.05, final_time=1, χ=120, plus `<Sz>` and `<Sp_i Sm_j>` measurements. WL-portable: Yes.

## 8. Ground state energy vs analytic

1. **TFIM finite ED energy** — `tfi_exact.finite_gs_energy(L, J, g)` (`tenpy_toycodes/tfi_exact.py:19-54`). Sparse Kron of σ_z·σ_z and σ_x; eigsh `which='SA'`. Used as validation check throughout. WL-portable: Yes.
2. **TFIM infinite analytic energy density** — `tfi_exact.infinite_gs_energy(J, g)`, lines 72-79. `e₀ = -(1/4π) ∫_{-π}^π 2√(J²-2Jg·cosp+g²) dp`. At J=g=1 gives `e₀ = -4/π ≈ -1.2732`. (Convention: `H = -J ZZ - g X`.) WL-portable: Yes.
3. **TFIM infinite excitation dispersion** — `tfi_exact.infinite_excitation_dispersion(J,g)` (line 81-84). `ε(p)=2√(J²-2Jg·cosp+g²)`. Gap closes at g=1. WL-portable: Yes.
4. **TFIM finite ED examples convention (X·X coupling)** — `examples/tfi_exact.py:55-68`. `H = -J Σ XX - g Σ Z`, `e₀ = -(g/2πJ) ∫_{-π}^π √(1+(J/g)²+2(J/g)cos k) dk`. WL-portable: Yes.
5. **XX chain ground-state energy** — `tenpy_toycodes/free_fermions_exact.py:55-63`. `XX_model_ground_state_energy(L, h_staggered, bc)`. Free-fermion eigenvalues; `E = Σ_{k<L/2} ε_k`. WL-portable: Yes.
6. **Finite Heisenberg PBC, S=1, L=100** — `doc/notebooks/12_dmrg_mixer.ipynb`. **E_exact = -140.14840390392** (from arXiv:cond-mat/0508709). WL-portable: Partial (PBC + S=1 increases χ).

## 9. Expectation value

1. **Site expectation `<σx>, <σz>`** — `c_tebd.py:65-68`, `b_mps.py` etc. For TFIM finite GS at L=10, g=1: `Σ<σx> ≈ 7.32, Σ<σz> = 0`. WL-portable: Yes.
2. **Bond energy `bond_expectation_value(H_bonds)`** — `a_mps.py:76-85`, `c_tebd.py:62`. Sum over bonds = total energy for NN model. WL-portable: Yes.
3. **MPO expectation `H_MPO.expectation_value(psi)`** — `examples/d_dmrg.py:96`, `examples/userguide/c_mps_mpo.py:38`. Returns scalar `<ψ|H|ψ>`. For Neel + Heisenberg L=6 returns -1.25. WL-portable: Yes.
4. **`<Sz>` per-site reservation under DMRG (Sz-conservation)** — `examples/d_dmrg.py:175-178` (Heisenberg XXZ): mean `<Sz>=0` exactly because of conservation. WL-portable: Partial.
5. **Site, bond, full MPO contraction equivalence** — `doc/notebooks/01_dmrg.ipynb` cell-8: `assert |E - H_MPO.expectation_value(psi)| < 1e-10` and equal to `Σ bond_energies(psi)`. WL-portable: Yes.

## 10. Correlation function

1. **`<Sz_i Sz_j>` in Neel state** — `examples/userguide/c_mps_mpo.py:15`. Diagonal pattern: 1 at `(0,0),(2,2),(4,4)`, 0 elsewhere. WL-portable: Yes.
2. **`correlation_function('Sigmax','Sigmax')` on TFIM critical GS** — `doc/notebooks/01_dmrg.ipynb` cell-10. Power-law decay (critical). WL-portable: Yes.
3. **`term_correlation_function_right` on TFIM L=100** — same notebook. Disconnected `<XX>_disc`, `<ZZ>_disc`. WL-portable: Yes.
4. **AKLT correlation `C(n) = <Sz_0 Sz_n> - <Sz>² → |λ_2|^{n-1} = (1/3)^{n-1}`** — `exercises_uniform_toycodes.ipynb` Part 1.2. WL-portable: Yes.

## 11. Entanglement entropy / spectrum

1. **`entanglement_entropy()` profile** — `a_mps.py:87-98`, `examples/c_tebd.py:111`. Returns `S(l)` for each bond. WL-portable: Yes.
2. **CFT entropy fit `S(l,L)=(c/6) log(2L/π sin(πl/L)) + const`** — `01_dmrg.ipynb` cell-12. **Extracts c≈0.5** for critical TFIM. WL-portable: Yes.
3. **Toric code half-cylinder S = (Ly-1) log 2 → γ=log 2** — `11_toric_code.ipynb` cell-19,21. Topological entanglement entropy. WL-portable: Partial.
4. **`entanglement_spectrum(by_charge=True)`** — `examples/chern_insulators/haldane.py:70`. Spectrum vs flux φ; demonstrates Chern number from spectral flow. WL-portable: No.

## 12. Structure factor / spectral function

1. **Spectral simulation TEBD on DMRG ground state** — `examples/yaml/minimal_SpectralSimulation.yml`. Operator Sz at t=0, Sz at t (S(q,ω) via `linear_predict + gaussian_window`). WL-portable: Partial.

## 13. Charge / symmetry sectors

1. **`SpinHalfSite(conserve='Sz')` Sz blocks** — `examples/userguide/b_npc_arrays.py:5-15`. Diagonalizes `H_xx + H_zz` in 4-leg form, reports charges `[-2,0,0,2]` and eigenvalues `[0.25, -0.75, 0.25, 0.25]` (singlet at -0.75). WL-portable: Partial.
2. **TFIChain `conserve='parity'`** — `examples/advanced/vumps_and_plane_wave.py:16`. Even/odd ℤ_2 sectors. WL-portable: Partial.
3. **Multi-species Sz + N independent charges** — `doc/notebooks/31_multispecies_models.ipynb` (Heisenberg+Fermion ladder; `set_common_charges(sites, new_charges='independent')`). WL-portable: No.

## 14. Lanczos / Krylov

1. **Toy Lanczos ground state and `expm(-iHdt)|psi>`** — `tenpy_toycodes/lanczos.py:14-74`. Pure NumPy K-step Lanczos with tridiagonal `T`; `lanczos_ground_state(H, ψ₀, k=20)` and `lanczos_expm_multiply(H, ψ₀, dt, k)`. Replaces `eigsh`/`expm_multiply` calls. WL-portable: Yes.

## 15. Custom site types

1. **`GroupedSite([fs, fs], labels=['A','B'])`** — `examples/chern_insulators/haldane_C3.py:80-85`. Adds `'Ntot'` operator. WL-portable: No.
2. **`set_common_charges([spin, ferm], new_charges='independent')`** — `doc/notebooks/31_multispecies_models.ipynb` cell-6. WL-portable: No.

## 16. Observer / measurement callbacks

1. **`m_pollmann_turner_inversion`** — `examples/model_custom.py:51-68`. Custom measurement function with `TransferMatrix(psi, psi2, charge_sector=0)`, returns `O_I` (eq.15 of arXiv:1204.0704). WL-portable: Partial.
2. **`connect_measurements` YAML schema** — `examples/yaml/details_simulation.yml`, `simulation_custom.yml`. Combines `m_onsite_expectation_value`, `psi_method wrap correlation_function`, `simulation_method wrap walltime`, `tools.process wrap memory_usage`. WL-portable: No (TeNPy plumbing).

## 17. Other (purification / segment / plane-wave / mixers)

1. **Purification TEBD imag-time** — `examples/purification.py:9-23`. `PurificationMPS.from_infiniteT`, evolve with β·H/2, track `<Sz>(β)` for TFIM L=30, g=1.2, dt=0.05, χ=100, `β_max=3`. WL-portable: No.
2. **Purification via MPO `make_U(±dt, approx)`** — `examples/purification.py:26-46`. Same observable. WL-portable: No.
3. **Purification sampling** — `doc/notebooks/15_purification_sampling.ipynb`. `psi.sample_measurements(sample_q={True,False})`. WL-portable: No.
4. **VUMPS + plane-wave excitations on TFIM** — `examples/advanced/vumps_and_plane_wave.py:15-69`. Ground state via `TwoSiteVUMPSEngine`, χ=32, `parity` sector. Then `PlaneWaveExcitationEngine` for momenta `np.arange(0,π,π/8)`, qtotal_change=[1] (odd parity). **Expected dispersion `2 min(√(g²-2g·cos k+1), √(g²-2g·cos(k+π)+1))`**, exact match. WL-portable: Yes.
5. **Toy VUMPS** — `tenpy_toycodes/g_vumps.py`, `vumps_algorithm(h, guess_psi0, tol)`. Returns `(e0, psi0, var0)`. WL-portable: Yes.
6. **Variational plane-wave on toy uMPS** — `tenpy_toycodes/i_uexcitations.py:16-298`. Targets domain-wall excitations for g<1 with two degenerate symmetry-broken `psi0, psi0_tilde`. WL-portable: Yes.
7. **Segment boundary conditions for excitations** — `examples/advanced/tfi_segment.py:23-127` and `doc/notebooks/14_segment_half_infinite.ipynb`. Two infinite GS (`+x`/`-x` symmetry-broken), build segment of length `repeat_L+repeat_R`, run DMRG; also "half-infinite" projecting LP onto leading right Schmidt. **Expected `<σz>` profile relaxes from boundary value to bulk `0.87733` over O(ξ)** for g=1.5. WL-portable: No.
8. **Mixer benchmarks (DensityMatrixMixer vs SubspaceExpansion)** — `doc/notebooks/12_dmrg_mixer.ipynb`. Spin-1 PBC L=100, varying mixers and `chi_list={0:50,4:100,8:200,12:400,16:600}`. **E_exact = -140.14840390392**. WL-portable: Partial.
9. **Time-dependent H** — `doc/notebooks/13_time_dependent_H_evolution.ipynb`. `class MyTimeDepModel(SpinChain)` with `Jz = 1/(time+0.01)`. `TimeDependentExpMPOEvolution` simulation class, dt=0.05, final_time=1.5. WL-portable: Yes.
10. **Free-fermion XX model time-evolved entropy from Neel CDW** — `tenpy_toycodes/free_fermions_exact.py:65-100`. `XX_model_time_evolved_entropies(L=100, h_s, time_list)`; benchmark for TEBD/TDVP. WL-portable: Yes.

## Notes on WL portability

**Fully portable (no charge framework needed)**: TFIM/XXZ toy code (b_model + c_tebd + d_dmrg + e_tdvp), VUMPS/uTDVP toycodes, Lanczos toy, free-fermion exact, Toric Code measurement (with `conserve=None`).

**Partial (works without charges; full validation needs charge support)**: SpinHalfSite + Sz-conserving DMRG (e.g. XXZ at Jz≠0 expecting `<Sz>=0`), TFIChain `conserve='parity'`, central-charge fit.

**Non-portable today**: spinful fermion / spinless fermion / Bose-Hubbard / Haldane / Chern insulator examples (require U(1) particle-number conservation, Jordan-Wigner machinery, complex hopping with flux), purification MPS, multi-species models with `set_common_charges`, segment boundary conditions, irregular lattices, simulation YAML measurement plumbing.

**High-priority WL validation targets** (analytic answers + small bond dimension):
- TFIM finite L=10 g=1 → E=-12.3814899996548 (toy DMRG/TEBD).
- TFIM infinite g=1.5 → E/L = -1.6719262215362, `<σx>=0.87733`, ξ=2.42.
- TFIM critical L=100 → c=0.5 from CFT entropy fit.
- AKLT exact `S=log 2`, ξ=1/log 3, `e=-2/3`, var=0.
- Heisenberg L=16 (singlet sector via Neel start) → E=-20.01638790048513.
- XXZ Heisenberg from Neel L∈{16,32,64,128} → E_∞ extrapolation `-0.47364442364…`.
- Toric code on cylinder Ly∈{2..6}: `E=-1, S=(Ly-1)log2`.
