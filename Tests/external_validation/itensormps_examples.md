# ITensorMPS.jl Validation-Test Catalog

Source: `tn-external/numerical/ITensorMPS.jl/`. Split out from ITensors.jl in v0.7 (Oct 2024). Owns all MPS/MPO/DMRG/OpSum/`siteinds`/`inner`/`expect`/observer machinery. This catalog complements [itensors_examples.md](itensors_examples.md) which has only tensor primitives + TRG/CTMRG.

## Summary

**Total entries: 134** across `README.md`, all 32 `docs/src/**` markdown/jl pages, all 35 `examples/**` Julia scripts (incl. autodiff + solvers + write_to_disk + threaded_blocksparse + finite_temperature + gate_evolution + exact_diagonalization + DMRG sub-tree + helpers), the lone `benchmark/benchmarks.jl`, and every test file in `test/`, `test/base/`, `test/base/test_solvers/`, `test/Ops/`, plus relevant `test/ext/ITensorMPSChainRulesCoreExt/` files.

**Counts per category (and WL-portable: Yes / Partial / No):**

| Category | Count | Y | P | N |
|---|---|---|---|---|
| MPS construction | 14 | 12 | 1 | 1 |
| MPS algebra | 14 | 13 | 1 | 0 |
| MPO construction | 6 | 6 | 0 | 0 |
| MPO algebra | 11 | 10 | 1 | 0 |
| OpSum / Hamiltonian | 13 | 11 | 1 | 1 |
| AutoMPO | 7 | 6 | 1 | 0 |
| DMRG (finite) | 23 | 16 | 4 | 3 |
| TDVP | 7 | 5 | 2 | 0 |
| Expectation value (`expect`/`inner`) | 8 | 8 | 0 | 0 |
| Ground-state energy validation references | 6 | 6 | 0 | 0 |
| Correlation function | 5 | 5 | 0 | 0 |
| Entanglement / Schmidt | 3 | 3 | 0 | 0 |
| Sampling | 3 | 3 | 0 | 0 |
| Custom site types | 4 | 3 | 1 | 0 |
| Observer / sweep callbacks | 5 | 4 | 1 | 0 |
| Projector / ProjMPO | 5 | 4 | 1 | 0 |
| Symmetry sectors (QN) | 6 | 4 | 2 | 0 |
| Random MPS | 4 | 4 | 0 | 0 |
| Conversion (MPS↔dense) | 3 | 3 | 0 | 0 |
| Gate evolution / TEBD / METTS / purification | 7 | 6 | 1 | 0 |
| Other (lattices, sweepnext, sweeps, autodiff, threading) | 14 | 6 | 4 | 4 |

(**Y/P/N** = WL-portable Yes / Partial / No. *Partial* = main numerics fine but some setting requires features the paclet does not yet have, e.g. block-sparse QN flux, AutoMPO row-bypass tricks, or random-circuit test states.)

**Gold validation tests** (analytical or known-numeric reference):

* TFI critical OBC energy, `E = 1 − 1/sin(π/(4N+2))` — `test_dmrg.jl:218-247`, `:271`. For N=32 ≈ −20.1817.
* Heisenberg S=1 N=100 final energy `E = -138.94008605883985` — README, `index.md`, `examples/dmrg/1d_heisenberg.jl`.
* Spinless-fermion N=8 t=1 V=4 `E = -2.859778` — `test_fermions.jl:195-208`.
* Hubbard L=10 N=8 t=1 U=1 V=0.5 `-8.02 < E < -8.01` — `test_dmrg.jl:415-441`.
* Heisenberg S=1 L=10 OBC `E < -12` (Haldane regime) — `test_dmrg.jl:6-58`.
* TFI excited-state gap `Eg = 2|h-1|` — `docs/src/examples/DMRG.md:285-368`.
* HardCore-boson product-state expectation value `0.00018` — `test_autompo.jl:1120-1156`.
* Fermion matrix-element checks `inner(ψA',H,ψB) ≈ ±t1` — `test_fermions.jl:68-155`.
* Heisenberg L=14 DMRG vs. exact diagonalization (Krylov on contracted MPO) — `examples/exact_diagonalization/exact_diagonalization.jl`.

## MPS construction

1. **Empty / sized MPS constructor.** `test/base/test_mps.jl:13-50`, `:603-606`, `docs/src/MPSandMPO.md:13-22`. Builds `MPS(sites)`, `MPS(N)`, `MPS(sites; linkdims=3)` with zero/random tensors. Inputs: arbitrary site-indices vector. API: `MPS`, `length`, `linkdims`, `flux`. Output: linkdims = 1 (or chosen), flux = nothing. WL-portable: Yes.
2. **Vector-of-string product MPS.** `test/base/test_mps.jl:69-89`. `MPS(sites,state)` with `state[j] = isodd(j) ? "Up" : "Dn"` on `S=1/2` sites. Checks `<ψ|Sz_j|ψ> = ±1/2`. Inputs: L=10, S=1/2. API: `MPS(::Vector{Index},::Vector{String})`, `op`. Output: alternating `±0.5` Sz expectation. WL-portable: Yes.
3. **Single-string product MPS.** `test_mps.jl:91-110`. `MPS(sites,"Dn")` and `MPS(sites,"X+")`. Checks `<Sz>=-1/2` everywhere or `<X>=1`. WL-portable: Yes.
4. **Integer / Vector-of-int / pair-of-ivals constructors.** `test_mps.jl:112-167`. `MPS(sites,2)`, `MPS(sites,[1,2,1,...])`, `MPS([s[n] => states[n] for n=1:N])`. WL-portable: Yes.
5. **Complex-eltype product MPS.** `test_mps.jl:168-180`. `MPS(ComplexF64,sites,fill(1,L))`; checks element type. WL-portable: Yes.
6. **N=1 MPS.** `test_mps.jl:51-58`, `:183-197`. Single-site MPS; checks first-tensor entries. WL-portable: Yes.
7. **MPS from a single ITensor (TT-SVD).** `docs/src/examples/MPSandMPO.md:24-39`, `test_mps.jl:1297-1355`. `MPS(T,(i,j,k,l,m); cutoff,maxdim)` reconstructs T. Output: `prod(ψ) ≈ T`, `maxlinkdim ≤ 4` for d=2,N=5. WL-portable: Yes.
8. **MPS from a Julia array.** `docs/src/examples/MPSandMPO.md:40-75`, `test_mps.jl:1346-1355`. `A = randn(d,d,d,d,d)` or `randn(d^N)`, then `MPS(A,sites; cutoff,maxdim)`. WL-portable: Yes.
9. **MPS over a Hilbert space subset; setting tensor ranges.** `test_mps.jl:1357-1383`. `ψ[2:N-1] = ϕ` and `ψ[2:N-1, orthocenter=3] = A`. WL-portable: Yes.
10. **MPS with no link indices.** `test_mps.jl:2056-2068`. `MPS([itensor(randn(ComplexF64,2),s[n]) for n=1:N])`; `orthogonalize` adds default link tags. WL-portable: Yes.
11. **`random_mps` — chi=1 default.** `test_mps.jl:200-214`. `random_mps(sites)` and `random_mps(ComplexF64,sites)`; `maxlinkdim==1`, every tensor has unit norm. WL-portable: Yes.
12. **`random_mps` — non-uniform link dims.** `test_mps.jl:227-231`. `random_mps(sites; linkdims=[2,3,4,2,4,3,2,2,2])`. WL-portable: Yes.
13. **`random_mps` from initial QN state.** `test_mps.jl:854-878`. `random_mps(sites,state; linkdims=8)` on QN-conserving S=1/2 sites; verifies `flux(M) == QN("Sz",0)` etc. Inputs: L=20, S=1/2 conserve_qns. WL-portable: Partial (block-sparse).
14. **Deprecated `randomMPS` API.** `test_deprecated.jl`. Many positional / kwarg variants. WL-portable: Yes.

## MPS algebra

1. **`inner(ψ,φ)` and `inner(ψ,ψ)` agree with manual contraction.** `test_mps.jl:241-253`, `:320-329`. Builds `dag(ψ) * φ` site-by-site. WL-portable: Yes.
2. **`loginner` for scaled MPS.** `test_mps.jl:255-266`. `c .* random_mps(s; linkdims=4)` gives `exp(loginner(ψ,ψ)) ≈ c^(2n)`. WL-portable: Yes.
3. **`norm`/`normalize`/`normalize!` MPS for various eltypes.** `test_mps.jl:331-468`. Float32/64, Complex32/64. Includes `lognorm` for L=1000 to avoid float overflow. WL-portable: Yes.
4. **Scaling and sign-flip.** `test_mps.jl:490-502`. `2 * dag(ψ)` gives `inner = 2*<ψ,ψ>`. WL-portable: Yes.
5. **`add(ψ,φ)` / `+ MPS`.** `test_mps.jl:504-545`. `inner(ψ+ψ,ψ+ψ) = 4*inner(ψ,ψ)`; multi-MPS sum; algorithms `densitymatrix` and `directsum`. WL-portable: Yes.
6. **`+ MPS` with complex coefficients.** `test_mps.jl:547-601`. `α₁ψ₁ + α₂ψ₂ + ψ₃` matches manual `inner_add`. WL-portable: Yes.
7. **Broadcasting.** `test_mps.jl:268-286`. `prime.(psi)`, `psi .= addtags(psi,"x")`. WL-portable: Yes.
8. **Copy vs deepcopy semantics.** `test_mps.jl:299-318`. WL-portable: Yes.
9. **`replacebond!`.** `test_mps.jl:629-677`. SVD factorize a 2-site block back into MPS; tag and ortho-limit preservation. WL-portable: Yes.
10. **`orthogonalize!` (regular and QN).** `test_mps.jl:680-754`, `:723-753`. Left/right orthogonality checks: `M[j]*prime(M[j],"Link") == δ`. WL-portable: Yes.
11. **`truncate!` method.** `test_mps.jl:755-794`. Truncate down to maxdim=5 from chi=10; preserves overlap; supports `site_range`, `callback`. WL-portable: Yes.
12. **`movesite` / `movesites`.** `test_mps.jl:1277-1467`. All permutations of L=1..4 sites; verifies `prod(ψ') ≈ prod(ψ)`. WL-portable: Yes.
13. **`swapbondsites`.** `test_mps.jl:1145-1165`. Swap bond 4 with `cutoff=1e-15`. WL-portable: Yes.
14. **`replace_siteinds`.** `test_mps.jl:288-297`. Replaces site indices and verifies `siteinds(y) == t`. WL-portable: Partial (paclet uses positional indices).

## MPO construction

1. **Empty / sized / from Vector{ITensor} MPO.** `test_mpo.jl:34-58`, `test_qnmpo.jl:14-56`. `MPO()`, `MPO(N)`, `MPO(sites)`. WL-portable: Yes.
2. **`MPO(sites,"Sz")`.** `test_mpo.jl:448-453`, `:613-627`. Identity / Sz-string MPO; trace `tr(MPO(s,"Id")) = d^N`. WL-portable: Yes.
3. **`MPO(s,"Id") ./ √2` for purification.** `examples/finite_temperature/purification.jl`. Infinite-T mixed state. WL-portable: Yes.
4. **`MPO` from product of operators (vector form).** `test_mpo.jl:11-21` (`basicRandomMPO`), `:60-101`. Random MPO with chi=4 link, verify `norm`/`lognorm`. WL-portable: Yes.
5. **`MPO(ψ::MPS)` (legacy) and `outer(ψ',ψ)` / `projector(ψ)`.** `test_mpo.jl:613-661`, `examples/mps_mpo_algebra/mps_density_matrix.jl`. Build `|ψ><ψ|`. Includes mixed-state density matrix as `ρ = sum(outer.(ψs))`. WL-portable: Yes.
6. **MPO from ITensor (TT-SVD form).** `test_mpo.jl:471-557`. `MPO(A,sis; orthocenter=4)` for A with all primed/unprimed pairs. WL-portable: Yes.

## MPO algebra

1. **`inner(ψ',H,ψ)` = manual contraction `<ψ|H|ψ>`.** `test_mpo.jl:103-158`. Tests across link dims 2..5. WL-portable: Yes.
2. **`inner(J,ϕ,K,ψ)` = manual `<Jϕ|Kψ>`.** `test_mpo.jl:172-225`. Includes generic-tag variants and dimension-mismatch errors. WL-portable: Yes.
3. **`error_contract`.** `test_mpo.jl:227-254`. Returns `√|1+(<ϕ|ϕ>-2 Re<ϕ|K|ψ>)/<Kψ|Kψ>|`; tested on naive-contracted `Kϕ`. WL-portable: Yes.
4. **`contract(K,ψ; alg=…)`.** `test_mpo.jl:257-310`, `test_solvers/test_contract.jl:6-65`. Algorithms: `densitymatrix`, `naive`, `zipup`, `fit`. Verifies `<ϕ|Kψ>=<ϕ|K|ψ>`. WL-portable: Yes.
5. **`add(K,L)` / `K+L`.** `test_mpo.jl:312-371`. With QN-conserving and basicRandomMPO; verifies inner-add identity. WL-portable: Yes.
6. **`*(K,L)`/`K(L)`/`apply(K,L)` MPO×MPO.** `test_mpo.jl:374-446`. Includes multi-arg `apply(ρ1,ρ2,ρ3)` and `replaceprime(K'*L,2=>1) ≈ apply(K,L; maxdim)`. WL-portable: Yes.
7. **`tr(MPO)`.** `test_mpo.jl:663-679`. `tr(MPO(s,"Id")) = d^N`; with grouped-site MPO. WL-portable: Yes.
8. **`MPO(opsum,sites; splitblocks=true)`.** `test_qnmpo.jl:201-249`. Block sparsity counts: `nnz(H[1])=9`, `nnz(H[2])=18`, etc. WL-portable: Partial (block sparse).
9. **`H'*H` ≡ `expand(ℋ²)`.** `test/Ops/test_ops_mpo.jl:89-98`. `MPO(ℋ², s) ≈ replaceprime(H'*H, 2=>1)`. Heisenberg N=4. WL-portable: Yes.
10. **MPO+MPO directsum.** `test_mpo.jl:840-877`. `+(H₁,H₂; alg="directsum")` (and density-matrix). WL-portable: Yes.
11. **MPO without link indices.** `test_mpo.jl:798-820`. `MPO([op("Id",sn) for sn in s])`; subsequent `orthogonalize`/`truncate`/`apply`. Plus DMRG with `e ≈ 1`. WL-portable: Yes.

## OpSum / Hamiltonian

1. **OpSum addition syntax.** `docs/src/OpSum.md`, `test_autompo.jl:177-285`. `os += "Sz",j,"Sz",j+1` and `os += 0.5,"S+",j,"S-",j+1`; `+` and `-` and `add!`. WL-portable: Yes.
2. **OpSum algebra cross eltype.** `test_autompo.jl:286-335`. `O1 + 2*O2`, `O1 - O2/2` correctness vs manual MPO sum, for Float32/64/Complex32/64. WL-portable: Yes.
3. **Ising N=10 MPO via OpSum vs hand-built MPO.** `test_autompo.jl:348-379`. Reference `isingMPO(sites)` constructed by hand from explicit virtual-bond Index of dim 3; checks `<ψ|H|ψ>` agreement. WL-portable: Yes.
4. **Heisenberg with random Sz fields, comparison to hand-built MPO.** `test_autompo.jl:395-414`. Reference `heisenbergMPO(sites,h,onsite)` chi=5. WL-portable: Yes.
5. **Multiple onsite ops `"Sz * Sz"` vs `"Sz",j,"Sz",j` syntax.** `test_autompo.jl:416-447`. Compares vs `heisenbergMPO(sites,ones(N),"Sz * Sz")`. WL-portable: Yes.
6. **Three-site / four-site spin operators.** `test_autompo.jl:449-482`. Checks against hand-built `threeSiteIsingMPO`, `fourSiteIsingMPO`. WL-portable: Yes.
7. **Next-nearest-neighbor Heisenberg J1-J2.** `test_autompo.jl:484-507`. With QN bonds chi=8. WL-portable: Yes.
8. **Multisite operator with parameters in OpSum.** `test_autompo.jl:188-277`. `os += ("CX",1,2,(ϕ=π/3,))`, `os += (1+2im,"CRz",(ϕ=π/3,),1,2)`. Stores `params` dict. WL-portable: Partial (paclet OpSum lacks parametric ops).
9. **Multisite coordinate index.** `test_autompo.jl:217-222`. `("X",(1,2))` (tuple-as-site). WL-portable: Partial.
10. **Complex OpSum coefs.** `test_autompo.jl:1037-1053`. With Float64 / QN; verifies `inner(ψud',H,ψdu) = +i`, `inner(ψdu',H,ψud) = -i`. WL-portable: Yes.
11. **Non-zero QN MPO from single creation operator.** `test_autompo.jl:1055-1084`. `os += "Adag",j` with Boson conserve_qns; matches hand-built op_mpo. WL-portable: Partial.
12. **Hashing / repeated terms.** `test_autompo.jl:1177-1205`. `os += ("Z",1) + ("Z",1)` — `sortmergeterms` collapses. WL-portable: Yes.
13. **HardCore boson Hamiltonian on product state.** `test_autompo.jl:1120-1156`. L=20, t=1, V1=1e-3, V2=2e-5; `<ψ0|H|ψ0> = 0.00018` ± 1e-10. **Gold validation test.** WL-portable: No (custom HardCore site type, must port).

## AutoMPO

1. **OpSum chemical Hamiltonian (1- and 2-body).** `test_autompo.jl:965-1035`. L=6 Electron, random `t[i,j]`, `V[i,j,k,l]`; with auto-fermion on/off; checks `<ψi|Ht|ψj> = t[i,j]` and 2-body Wick contractions. WL-portable: Yes.
2. **Single creation op.** `test_autompo.jl:337-346`. `os += "Adagup",3` and `os += "Adagup",3` (legacy). Matches manual `cdu_psi[3] = noprime(cdu_psi[3]*op("Adagup"))`. WL-portable: Yes.
3. **AutoMPO `.+=` / `.-=` syntax.** `test_autompo.jl:718-902`. In-place broadcasting equivalents. WL-portable: Yes.
4. **OpSum with empty blocks (issue #963).** `test_autompo.jl:1207-1222`. Fermion N=2, multi-product `c†c†cc`. WL-portable: Partial.
5. **OpSum with zero blocks (issue #1150).** `test_autompo.jl:1243-1257`. Fermion N=4 conserve_qns; `os += (5.555, "Cdag",4,"Cdag",4,"C",2,"C",2)` shouldn't error. WL-portable: Partial.
6. **One-site ops bond-dim test.** `test_autompo.jl:1224-1241`. `os += "Z",j` for all j → `linkdims(H) .== 2`; single-site → ≤2. WL-portable: Yes.
7. **Matrix operator representation.** `test_autompo.jl:1159-1175`. `OpSum() += 1.0, op+opt, j` builds same MPO as separate scalar terms. WL-portable: Yes.

## DMRG (finite)

1. **Heisenberg S=1 N=100 with default sweeps.** README, `docs/src/index.md`, `examples/dmrg/1d_heisenberg.jl`. `nsweeps=5`, `maxdim=[10,20,100,100,200]`, `cutoff=1e-10`. **`Final energy = -138.94008605883985`** — gold validation (Haldane gap region). WL-portable: Yes.
2. **Heisenberg S=1 N=10 small system.** `test_dmrg.jl:7-31`. Checks `energy < -12`. WL-portable: Yes.
3. **Heisenberg S=1 N=10 conserving QN.** `test_dmrg.jl:33-58`. Néel state init; `energy < -12`. WL-portable: Partial (block sparse needed for matching low-D blocks).
4. **Disk-cached Heisenberg S=1 conserve_qns.** `test_dmrg.jl:60-85`. `write_when_maxdim_exceeds=15`. WL-portable: No.
5. **TFI L=32 critical OBC.** `test_dmrg.jl:198-247`. **Exact `E_exact = 1 − 1/sin(π/(4N+2))`** matched to 1e-4 (gold validation reference). WL-portable: Yes.
6. **TFI L=32 conserve_szparity.** `test_dmrg.jl:249-274`. Same exact energy. WL-portable: Partial.
7. **DMRGObserver basic + measurements.** `test_dmrg.jl:276-316`. L=10 S=1/2 transverse-Ising-like; observes Sz/Sx after each sweep. WL-portable: Yes.
8. **Sum of MPOs as Hamiltonian (`ProjMPOSum`).** `test_dmrg.jl:318-344`, `examples/dmrg/2d_hubbard_conserve_particles.jl`. `dmrg([HZ,HXY], psi, sweeps)`; `energy < -12`. WL-portable: Yes.
9. **Excited-state DMRG with weight.** `test_dmrg.jl:346-379`, `docs/src/examples/DMRG.md:285-368`. Two-spin-half ends + spin-1 bulk; `energy1 > energy0`, orthogonality `inner(psi1,psi0) < 1e-5`. **TFI gap test:** `Eg = 2|h-1|`. WL-portable: Yes.
10. **Spinless-fermion DMRG (Cdag…C, with N…N density).** `test_dmrg.jl:381-414`. L=10 t1=1 t2=0.5 V=0.2; `-6.5 < E < -6.4`. WL-portable: Yes.
11. **Hubbard model DMRG (L=10, Npart=8, t1=1, U=1, V1=0.5).** `test_dmrg.jl:416-442`. **`-8.02 < E < -8.01`** (gold validation reference). State `["Up","Dn","Dn","Up","Emp","Up","Up","Emp","Dn","Dn"]`. WL-portable: Partial.
12. **Mixed S=1/2 + S=1 ladder.** `docs/src/examples/DMRG.md:107-167`. `siteinds(n->isodd(n) ? "S=1/2" : "S=1", N)`; couplings `Jho`, `Jhh`, `Joo`. WL-portable: Yes.
13. **2D Heisenberg cylinder.** `examples/dmrg/2d_heisenberg_conserve_spin.jl`, `docs/src/examples/DMRG.md:184-251`. `square_lattice(Nx=12,Ny=6; yperiodic=false)`; QN conservation; bond dim up to 800. WL-portable: Partial.
14. **2D Hubbard cylinder.** `examples/dmrg/2d_hubbard_conserve_particles.jl`, `…_momentum.jl`. Nx=6 Ny=3 t=1 U=4; checkerboard initial state. The `momentum`-conserving variant uses custom `ElecK` site type. WL-portable: No.
15. **Extended 1D Hubbard with t1, t2, U, V1.** `examples/dmrg/1d_hubbard_extended.jl`. L=20 Npart=10. Density profile measurement. WL-portable: Partial.
16. **Disk-cached 1D Heisenberg.** `examples/dmrg/write_to_disk/1d_heisenberg.jl`. `write_when_maxdim_exceeds=25`. WL-portable: No.
17. **Threaded blocksparse 2D Hubbard.** `examples/dmrg/threaded_blocksparse/2d_hubbard_conserve_momentum.jl`. WL-portable: No.
18. **DMRG `which_decomp` (svd vs eigen).** `test_fermions.jl:200-208`. Ensures both reach `correct_energy = -2.859778`. WL-portable: Yes.
19. **DMRG with mismatched ortho center / no ortho center.** `test_dmrg.jl:444-471`. Sets ortho center to wrong site or replaces every tensor with `random_itensor`; DMRG still runs. WL-portable: Yes.
20. **Compact `Sweeps` keyword syntax.** `test_dmrg.jl:223-247`. `dmrg(H,psi0; nsweeps=5, maxdim=[10,20], cutoff=1e-12, noise=1e-10)`. Same exact energy as `Sweeps(5)` form. WL-portable: Yes.
21. **DMRG inferred return-type.** `test_inference.jl`. `@inferred(dmrg(H,psi0,sweeps))` is `Tuple{Float64,MPS}`. WL-portable: N/A.
22. **DMRG with one or two sites total length.** `test_qnmpo.jl:251-306`. For N=1..4 conserve_szparity. Compares to `eigen(prod(H))` smallest eigenvalue (or QN block). **Gold validation** for N=2,3,4. WL-portable: Yes.
23. **Experimental `dmrg` (nsite=1 and 2).** `test/base/test_solvers/test_dmrg.jl`. Cross-validates `Experimental.dmrg(H,ψ; nsweeps,maxdim,cutoff,nsite, updater_kwargs)` vs canonical `dmrg`; ensures `e ≈ e2`. WL-portable: Yes (where nsite=1 single-site update implemented).

## DMRG-X / TDVP

1. **DMRG-X for MBL Heisenberg with random Sz fields.** `examples/solvers/02_dmrg-x.jl`, `test_solvers/test_dmrg_x.jl`. n=10 W=12; checks `<H²>-<H>² ≈ 0` (eigenstate). WL-portable: No (paclet has no DMRG-X solver yet).
2. **Basic TDVP forward/backward.** `examples/solvers/01_tdvp.jl`, `test_solvers/test_tdvp.jl:11-50`. Heisenberg L=10; energy preserved, fidelity `> 0.99` after round-trip. WL-portable: Partial.
3. **TDVP sum of Hamiltonians.** `test_tdvp.jl:52-86`. Energy-conservation across `[H1,H2]`. WL-portable: Partial.
4. **TDVP custom updater (KrylovKit `exponentiate`).** `test_tdvp.jl:87-119`. WL-portable: Partial.
5. **TDVP accuracy vs exact `exp(-iτH)`.** `test_tdvp.jl:120-171`. L=4 Heisenberg, τ=0.1 ttotal=1.0. Dense exact reference via `exp(-im*tau*HM)`. `Sz_tdvp - Sz_exact < 1e-5`. **Gold validation reference.** WL-portable: Yes.
6. **TDVP vs TEBD.** `test_tdvp.jl:172-242`. L=10 Heisenberg conserve_qns. Both methods agree on `<Sz_c>` and `<H>` to 1e-3. WL-portable: Partial.
7. **Imaginary-time TDVP ground state.** `test_tdvp.jl:243-287`. L=10 Heisenberg, ttotal=50, τ=1; `en1 < -4.25`. WL-portable: Yes.

## Expectation value (`expect` / `inner`)

1. **`expect(ψ,"Sz")`.** `docs/src/examples/MPSandMPO.md:120-153`, `test_mps.jl:880-935`. L=8 random S=1/2 MPS; verifies elementwise vs orthogonalized contraction `dag(prime(ψ[j]))*op("Sz",s[j])*ψ[j]`. WL-portable: Yes.
2. **`expect(ψ,"Sz"; sites=…)`.** `test_mps.jl:893-905`. Indexed by range, vector, single site. WL-portable: Yes.
3. **`expect(ψ,"Sz","Sx")` multi-op tuple.** `test_mps.jl:906-927`. Returns tuple-of-vectors / tuple-at-single-site / `Matrix{Vector}` for op grids. WL-portable: Yes.
4. **`expect` complex op on real wavefunction.** `test_mps.jl:937-950`. `expect(ψ,"Sy")` with stable RNG. WL-portable: Yes.
5. **`expect` with matrix-form operator.** `test_mps.jl:952-997`. `expect(ψ, [1/2 0;0 -1/2]) ≈ expect(ψ,"Sz")` and same for products. WL-portable: Yes.
6. **`expect` with composite op string `"S+ * S-"`.** `test_mps.jl:999-1006`, `:1015-1020`. `PM = expect(ψ,"S+ * S-")` matches diag of `correlation_matrix(ψ,"S+","S-")`. WL-portable: Yes.
7. **`inner(ψ',W,ψ)` for MPO operator.** `docs/src/examples/MPSandMPO.md:155-168`, `test_mpo.jl:103-158`. WL-portable: Yes.
8. **`inner(MPO,MPS)`/`inner(rho,H)`.** `examples/finite_temperature/purification.jl` β-loop computes `inner(rho,H)` as `tr(ρH)`; `inner(ψ',H,ψ)` for thermal energy. WL-portable: Yes.

## Ground-state energy validation references

1. **TFI critical OBC `E = 1 − 1/sin(π/(4N+2))`.** `test_dmrg.jl:198-247`, `:271`. WL-portable: Yes.
2. **Heisenberg S=1 N=100 final energy `-138.94008605883985`.** README, `index.md`. WL-portable: Yes.
3. **Heisenberg S=1 N=10 OBC `E < -12`.** `test_dmrg.jl:6-58`. Implicit reference: extrapolated Haldane phase. WL-portable: Yes.
4. **Spinless-fermion N=8 t=1 V=4 `-2.859778`.** `test_fermions.jl:195-208`. WL-portable: Yes.
5. **Hubbard L=10, Npart=8, t=1, U=1, V1=0.5: `-8.02 < E < -8.01`.** `test_dmrg.jl:416-442`. WL-portable: Yes.
6. **`dmrg(H,ψ; nsweeps=2)` on `MPO([op("Id",sn) for sn in s])` → E=1.** `test_mpo.jl:817-820`. Single Id-sum trivial Hamiltonian. WL-portable: Yes.

## Correlation function

1. **`correlation_matrix(ψ,"Sz","Sz")`.** `docs/src/examples/MPSandMPO.md:170-204`, `test_mps.jl:952-1081`. Builds full L×L correlator; cross-checked vs OpSum `MPO("S+",i,"S-",j)`. WL-portable: Yes.
2. **`correlation_matrix` with site range / non-contiguous sites.** `test_mps.jl:1004-1080`. `sites=3:7` and `sites=[1,3,8]`. WL-portable: Yes.
3. **`correlation_matrix` with matrix-form ops.** `test_mps.jl:960-967`. Confirms `[1/2 0; 0 -1/2]` matches `"Sz"`. WL-portable: Yes.
4. **`correlation_matrix` for fermionic operators (`Cdagup`,`Cup` etc.).** `test_mps.jl:1022-1081`. Includes Electron, Fermion, mixed-fermion errors. Energy via `C_energy = sum(j -> -2t*C[j,j+1], 1:N-1)` matches DMRG energy (`test_fermions.jl:211-250`). WL-portable: Yes.
5. **`correlation_matrix` with dangling bonds.** `test_mps.jl:1083-1111`. MPS with extra link indices on the boundary tensors. WL-portable: Yes.

## Entanglement / Schmidt

1. **Bipartite entanglement entropy from SVD.** `docs/src/examples/MPSandMPO.md:321-344`. `orthogonalize`+`svd` then `S_vN = -∑ p log p`. WL-portable: Yes.
2. **Per-step entanglement observer.** `docs/src/examples/DMRG.md:371-466`. `EntanglementObserver` prints SvN at each bond every sweep. WL-portable: Yes.
3. **`Spectrum` from factorizing the local 2-site wavefunction in DMRG.** `docs/src/Observer.md:91-107` (`spec` keyword). WL-portable: Partial (paclet `Spectrum` API differs).

## Sampling

1. **`sample(ψ)` and `sample!(ψ)` for chi=3 random MPS.** `test_mps.jl:798-825`. Throws if not orthogonalized to site 1 / not normalized. WL-portable: Yes.
2. **`sample(MPO)` / `sample(rho)`.** `test_mpo.jl:829-838`. Stable RNG: result `≈ [1,1,2,1,1,1]`. WL-portable: Yes.
3. **METTS sampling alternation X/Z basis.** `examples/finite_temperature/metts.jl`. `Ry(π/2)` gates between Z-basis and X-basis collapses; estimator average ± stderr. WL-portable: Yes.

## Custom site types

1. **`SiteType"S=3/2"` minimal.** `docs/src/examples/Physics.md:208-435`. Defines `space`, `op` for `Sz`, `S+`, `S-`. WL-portable: Yes (textbook).
2. **`SiteType"S=3/2"` with QN.** `docs/src/examples/Physics.md:438-548`. Same site type, conserve_qns adds `[QN("Sz",3)=>1, QN("Sz",1)=>1, QN("Sz",-1)=>1, QN("Sz",-3)=>1]`. WL-portable: Partial.
3. **Custom `op` `"Pup"` for S=1/2.** `docs/src/examples/Physics.md:48-165`. `[1 0; 0 0]`. WL-portable: Yes.
4. **`ElecK` site type for momentum-conserving Hubbard.** `examples/src/electronk.jl`. Defines `space` with three QN labels (Nf, Sz, Ky) and full op overload set. WL-portable: No.

## Observer / sweep callbacks

1. **`DMRGObserver` with `energy_tol`.** `docs/src/DMRGObserver.md:18-32`, `examples/dmrg/1d_ising_with_observer.jl`, `test_dmrg.jl:276-316`. Stops DMRG when energy converges to 1e-7. Tracks Sz/Sx per sweep. WL-portable: Yes.
2. **Custom `DemoObserver` overloading `checkdone!` and `measure!`.** `docs/src/Observer.md`. Stops when `|ΔE/E| < energy_tol`. WL-portable: Yes.
3. **`EntanglementObserver`.** `docs/src/examples/DMRG.md:371-466`. Custom struct, prints SvN per bond per half-sweep. WL-portable: Yes.
4. **`SizeObserver`.** `docs/src/examples/DMRG.md:468-552`. Uses `Base.summarysize(psi)` and `summarysize(projected_operator)`; logs `|psi|`, `|PH|` after each sweep. WL-portable: Partial.
5. **TDVP `step_observer!` / `observer!` (using `Observers.jl`).** `examples/solvers/03_tdvp_observers.jl`, `test_tdvp.jl:289-348`. Records `state`, `current_time`, `<Sz>` over the trajectory. WL-portable: Partial.

## Projector / ProjMPO

1. **`ProjMPO` interface.** `test_dmrg.jl:87-131`, `test_abstractprojmpo.jl`. `position!(PH,ψ,n)` sets site range; checks `lpos`, `rpos`, `nsite`, `eltype`, `size = chi[n-1]*chi[n+1]*d[n]*d[n+1]`. WL-portable: Yes.
2. **`ITensors.disk(PH)` for disk-backed projector.** `test_dmrg.jl:108-128`. WL-portable: No.
3. **`ProjMPOSum`.** `test_dmrg.jl:133-158`, `test_abstractprojmpo.jl:38-53`. Disk caching also tested. WL-portable: Partial.
4. **`set_nsite!` on ProjMPO and ProjMPOSum.** `test_dmrg.jl:160-196`. Independent of copies. WL-portable: Yes.
5. **`projector(ψ; cutoff)` and `outer(ψ',ϕ; cutoff)`.** `test_mpo.jl:629-661`. χ²-bond projector; reproduces `<ψ,Pψ ψ>=<ψ,ψ>²`. WL-portable: Yes.

## Symmetry sectors (QN)

1. **QN-conserving Heisenberg (S=1).** `docs/src/tutorials/QN_DMRG.md`. Initial product state `["Up","Dn",...]` ensures `flux = QN("Sz",0)`. WL-portable: Partial.
2. **QN-conserving 2D Heisenberg.** `examples/dmrg/2d_heisenberg_conserve_spin.jl`. WL-portable: Partial.
3. **`siteinds("Fermion",N; conserve_qns=true)`.** `test_fermions.jl`. Fermion-fermion fluxes through SWAP. WL-portable: Partial.
4. **`siteinds("Electron",N; conserve_qns=true)`.** `examples/dmrg/1d_hubbard_extended.jl`. Demonstrates Up/Dn/UpDn states with QN flux check. WL-portable: Partial.
5. **`flux(ψ)` and `flux(H)` checks.** `docs/src/tutorials/QN_DMRG.md:101-107`, `test_mps.jl:854-878`. Computes total `Sz`. WL-portable: Yes.
6. **Mixed QN names (`Number_odd`/`Number_even`).** `docs/src/faq/QN.md`. Multiple types of qudits. WL-portable: No.

## Random MPS

1. **`random_mps(s; linkdims=10)` Float64.** Many tests. Ensures `inner(ψ,ψ) = 1` after construction. WL-portable: Yes.
2. **`random_mps(rng, s, state; linkdims)` from StableRNG with a flux state.** `test_solvers/test_dmrg.jl`, `test_solvers/test_tdvp.jl`. WL-portable: Yes.
3. **`random_mps(s, n -> isodd(n) ? "↑" : "↓")` with QN.** `test_mps.jl:233-239`. Uniform / non-uniform link dims, both 2 and `[2,3,2,2]`. WL-portable: Partial.
4. **`random_mps(s, "↑")` constant string init for QN sectors.** `examples/solvers/01_tdvp.jl`. WL-portable: Yes.

## Conversion (MPS↔dense)

1. **`prod(ψ)`/`contract(ψ)` to a single ITensor.** `test_mps.jl:1297-1355`. Used as exact reference. WL-portable: Yes.
2. **`dense(ψ)` removes QN block-sparsity but preserves expectation values.** `test_mps.jl:2009-2019`. WL-portable: Yes.
3. **MPS↔fused-tensor with `combiner` tree (binary/unbalanced).** `examples/exact_diagonalization/exact_diagonalization.jl`, `examples/exact_diagonalization/fuse_inds.jl`. Then Krylov `eigsolve(H_full,ψ0_full,1,:SR)` matches DMRG energy `edmrg`. **Gold validation reference for L=14 Heisenberg.** WL-portable: Yes (paclet has fuse/contract).

## Gate evolution / TEBD / METTS / purification

1. **`apply(gates, ψ; cutoff)`.** `docs/src/tutorials/MPSTimeEvolution.md`, `docs/src/tutorials/tebd.jl`. L=100, S=1/2 Heisenberg, τ=0.1, ttotal=5. Records `<Sz>` at center site. WL-portable: Yes.
2. **TEBD on density matrix MPO.** `examples/gate_evolution/mpo_gate_evolution.jl`. Compares `inner(ψ',rho,ψ) ≈ inner(ψ,ψ)` and `tr(rho)`. WL-portable: Yes.
3. **METTS finite-T algorithm.** `examples/finite_temperature/metts.jl`. Heisenberg S=1/2 L=10, β=2; X/Z collapse; warmup 10 / 3000 samples; running mean & stderr. WL-portable: Yes.
4. **Purification (ancilla) finite-T.** `examples/finite_temperature/purification.jl`. `rho = MPO(s,"Id")./√2`; `inner(rho,H)` at each β. WL-portable: Yes.
5. **Quantum simulator gates (single/two/three/four-qubit).** `examples/gate_evolution/quantum_simulator.jl`. Builds X, H, CX gates; `apply(gates, MPS(s,"0"))`. WL-portable: Yes.
6. **Gate-set tests for spinful fermions.** `test_mps.jl:1971-2007`, `test_fermions.jl:253-289`. CCup MPO vs. product gate. WL-portable: Yes.
7. **Trotter formula correctness.** `test/Ops/test_trotter.jl`. Heisenberg N=4, `Trotter{1}(nsteps)` and `Trotter{2}(nsteps)` orders 1 and 2; converges to `exp(im*t*H)*prod(ψ₀)` as `1/nsteps^order`. WL-portable: Partial (paclet Trotter API differs).

## Other

1. **`square_lattice(Nx,Ny; yperiodic)`.** `test_lattices.jl:5-8`. `length == 17` for (3,4). WL-portable: Yes.
2. **`triangular_lattice(Nx,Ny; yperiodic)`.** `test_lattices.jl:10-15`. `length == 23` no-pbc, 28 with pbc-y. WL-portable: Yes.
3. **`sweepnext(N; ncenter)`.** `test_sweepnext.jl`. Sweep schedule: 1-site has `2N` substeps, 2-site `2(N-1)`, 3-site `2(N-2)`. WL-portable: Yes.
4. **`Sweeps` constructor variants.** `test_sweeps.jl`. From a 2-D matrix `[maxdim mindim cutoff noise; ...]` and from kwargs. WL-portable: Yes.
5. **`Algorithm("…")` traits.** `test_algorithm.jl`. `densitymatrix`, `naive`, custom `my_new_algorithm`. WL-portable: Partial.
6. **HDF5 read/write of MPS/MPO.** `test_readwrite.jl`. `h5open(...) write(f,"mpo",mpo)`; round-trip `norm(rmpo[i]-mpo[i])/norm(mpo[i]) < 1e-10`. WL-portable: No.
7. **Threaded block-sparse DMRG agrees with sequential.** `test_threading.jl`. 2D Hubbard 4×2 t=1 U=4. WL-portable: No.
8. **Symmetry-style trait.** `test_symmetrystyle.jl`. `symmetrystyle(MPS(s))=NonQN()` vs `HasQNs()`. WL-portable: N/A.
9. **Fermion DMRG with `which_decomp`.** `test_fermions.jl:200-208`. Both `svd` and `eigen` give `correct_energy = -2.859778`. WL-portable: Yes.
10. **Aqua quality test.** `test_aqua.jl`. Static checks. WL-portable: N/A.
11. **Auto-diff: simple gate parameter optimization.** `examples/autodiff/circuit_optimization/op.jl`. `f(x) = op("Ry",s; θ=x)[1,1]`; `f'(x) = -sin(x/2)/2`; gradient descent on `||state-target||`. WL-portable: Partial.
12. **Variational state preparation.** `examples/autodiff/circuit_optimization/state_preparation.jl`. nsites=20 nlayers=3 random target circuit; LBFGS via OptimKit. WL-portable: No.
13. **VQE: variational TFI.** `examples/autodiff/circuit_optimization/vqe.jl`, `…/ops/vqe.jl`. Compare optimized circuit energy to DMRG ground state. WL-portable: No.
14. **Trotter automatic differentiation.** `examples/autodiff/ops/trotter_ad_1.jl` (β optimization), `trotter_ad_2.jl` (h optimization). WL-portable: Partial.
15. **MPS autodiff energy minimization.** `examples/autodiff/mps_autodiff.jl`. Hand-written `loss(H,ψ)` directly contracted; LBFGS for L=10 TFI. WL-portable: Partial.

## Cross-cutting notes for paclet developers

- **Site types to implement first** (used by the most tests/examples): `S=1/2`, `S=1`, `Qubit`, `Fermion`, `Electron`. Lower priority: `Boson`/`Qudit`, `tJ`. Skip for now: `ElecK`, `HardCore`, `SiteType"S=3/2"` (tutorial-only).
- **Operators that appear ubiquitously:** `Sz`, `S+`, `S-`, `Sx`, `Sy`, `S²`, `Sx2`, `Sy2`, `Sz2`, `Id`, `X`, `Y`, `Z`, `H`, `Phase`, `T`, `Rx`, `Ry`, `Rz`, `CX`/`CNOT`, `CY`, `CZ`, `CCNOT`, `SWAP`, `√SWAP`, `iSWAP`, `Rxx`, `Ryy`, `Rzz`, `Cdag`, `C`, `N`, `F`, `Cdagup/dn`, `Cup/dn`, `Adagup/dn`, `Aup/dn`, `Nupdn`, `Ntot`, `A`, `Adag`. The `"Sz * Sz"` (multi-op string) syntax appears in OpSum tests.
- **Gold validation numbers** (already paste-ready):

   | Test | Numeric |
   |---|---|
   | TFI critical OBC L=N: `1 − 1/sin(π/(4N+2))` | for N=32 ≈ −20.1817 |
   | Heisenberg S=1 N=100 final energy | −138.94008605883985 |
   | Spinless-fermion N=8 t=1 V=4 ground | −2.859778 |
   | Hubbard L=10 Npart=8 t=1 U=1 V1=0.5 | between −8.02 and −8.01 |
   | TFI excited gap (h=4, large) | `Eg = 2|h-1| = 6` (finite-size correction expected) |
   | HardCore boson N=20 t=1 V1=1e-3 V2=2e-5, alternating product `ψ0` | `<ψ0|H|ψ0> = 0.00018` |

- **Tests safe to start porting first** (small, deterministic, dense, no QN): `test_dmrg.jl:198-247` (TFI critical), `test_dmrg.jl:6-31` (Heisenberg S=1 L=10), `test_mps.jl:880-935` (`expect`), `test_mps.jl:952-1081` (`correlation_matrix`), `test_autompo.jl:348-379` (Ising vs hand-built), `test_autompo.jl:395-414` (Heisenberg vs hand-built), `test_qnmpo.jl:251-306` (DMRG vs `eigen(prod(H))`).
- **Skip for paclet for now**: anything with `disk`/`write_when_maxdim_exceeds`, `enable_threaded_blocksparse`, ChainRulesCore (Zygote autodiff), HDF5 round-trip, `ElecK` momentum-conserving Hubbard, METTS sampling RNG-dependence, autodiff variational circuits, packagecompiler.
