# ITensorNetworks.jl Validation-Test Catalog

Source: `tn-external/numerical/ITensorNetworks.jl/`. General-graph TN built on ITensors.jl. The package's `examples/` and `benchmark/` directories are essentially empty (Literate stub); concrete computations live in `docs/src/*.md` (Documenter `@example` blocks) and `test/*.jl` — both are fully audited below, so the test suite is the source of truth.

## Summary

**Total distinct examples cataloged: 41**

Counts per category:
- General-graph TN construction & manipulation: 9
- Tree tensor network (TTN) construction & ortho: 5
- PEPS / 2D lattice TN: 4
- Belief propagation (BP): 6
- Boundary MPS / contraction sequences: 2
- TTN-DMRG / eigsolve: 2
- TDVP / time evolution / applyexp: 2
- Expectation values on general graph: 4
- Gauge fixing on graph (rescale/normalize): 2
- TEBD / gate application: 3
- OpSum→TTN (operator) construction: 4
- Form networks (linear/bilinear/quadratic): 1
- Sampling: 0 (not present)
- Partition functions / classical TN: 0 (not present)
- Finite-temperature TN: 0 (not present; TEBD imaginary-time used instead)
- Other (utilities, ITensorsExtensions): 4

## Category 1: Tree Tensor Network construction

### 1. Comb-tree TTN, zero-init and product state
- **Source:** `docs/src/tree_tensor_networks.md:21-45`
- **Description:** Build comb-tree TTN with `siteinds("S=1/2", g)`, then make a zero-init `ttn(sites)` and a product `|↑⟩` state via `ttn(v -> "Up", sites)`; also a 1D MPS via `mps(v -> "Up", siteinds("S=1/2", 6))`.
- **Inputs:** `named_comb_tree((3, 2))`; spin-½; product state, no truncation.
- **API calls:** `named_comb_tree`, `siteinds`, `ttn`, `mps`.
- **Expected output:** Qualitative — bond dim 1 product state.
- **WL-portable:** Yes.

### 2. Convert dense ITensor to TTN (cycle-free factorization)
- **Source:** `docs/src/tree_tensor_networks.md:65-78`; `test/test_ttns.jl:22-34`
- **Description:** Decompose a random rank-3 dense ITensor into a TTN over a 3×1 comb tree by successive QR/SVD with cutoff 1e-10; then re-contract to root and check `norm(S - S1) < 1e2 * cutoff`.
- **Inputs:** `named_comb_tree((3, 1))`, random ITensor over 3 site indices.
- **API calls:** `random_itensor`, `ttn(A, sites; cutoff)`, `contract(s1, root_vertex)`, `ortho_region`.
- **Expected output:** Reconstruction error ≲ 1e-8.
- **WL-portable:** Partial — needs tree-graph SVD sequencing not yet in the paclet.

### 3. ITensorNetwork ↔ TreeTensorNetwork conversion
- **Source:** `docs/src/tree_tensor_networks.md:50-56`; `test/test_ttns.jl:36-47`
- **Description:** `ITensorNetwork(psi)` strips gauge metadata; `TreeTensorNetwork(itn)` re-wraps. Vertex data should match.
- **Inputs:** `named_comb_tree((3, 2))`, `siteinds("S=1/2", g)`, product state.
- **API calls:** `ttn`, `ITensorNetwork(::TTN)`, `TreeTensorNetwork(::ITensorNetwork)`.
- **Expected output:** `vertex_data(itn) == vertex_data(psi.tensornetwork)`.
- **WL-portable:** Yes.

### 4. Orthogonalize TTN to single-site / two-site center
- **Source:** `docs/src/tree_tensor_networks.md:81-103`; `test/test_ttns.jl:49-61`
- **Description:** `orthogonalize(psi, v1)` puts gauge center at v1; `orthogonalize(psi, [v1, v2])` puts a 2-site center; `ortho_region` queries the result.
- **Inputs:** Comb-tree (3,2), `S=1/2` product state.
- **API calls:** `orthogonalize`, `ortho_region`.
- **Expected output:** `ortho_region == [v1]` or `[v1, v2]`.
- **WL-portable:** Partial — requires tree-graph QR sweep.

### 5. TTN sweep-based whole-network truncation
- **Source:** `docs/src/tree_tensor_networks.md:107-118`
- **Description:** Recompress an entire TTN with `truncate(psi; cutoff=1e-10, maxdim=50)` after addition.
- **Inputs:** Comb-tree state.
- **API calls:** `truncate(::AbstractTreeTensorNetwork; cutoff, maxdim)`.
- **Expected output:** Qualitative.
- **WL-portable:** Partial.

## Category 2: General-graph TN construction & manipulation

### 6. 3×3 square-lattice spin-½ TN, zero / product / staggered
- **Source:** `docs/src/itensor_networks.md:26-44`
- **Description:** Build TN on `named_grid((3,3))` with `link_space=2`, then "Up" product, then `v -> isodd(sum(v)) ? "Up" : "Dn"` staggered.
- **Inputs:** 3×3 grid, S=1/2, bond dim 2.
- **API calls:** `named_grid`, `siteinds`, `ITensorNetwork(s; link_space)`, `ITensorNetwork("Up", s)`, `ITensorNetwork(v -> ..., s)`.
- **Expected output:** Qualitative.
- **WL-portable:** Yes (paclet has lattice TN constructors).

### 7. ITensorNetwork from list of `ITensor`s, integer / named vertices
- **Source:** `docs/src/itensor_networks.md:49-55`; `test/test_itensornetwork.jl:76-89`
- **Description:** `ITensorNetwork([A, B, C])` infers chain edges from shared `Index` objects; `ITensorNetwork(Dict("A" => A, ...))` for named vertices.
- **Inputs:** Three rank-2 ITensors sharing pairwise `Index(2)`.
- **API calls:** `ITensorNetwork(tensors)`, `ITensorNetwork(Dict(...))`.
- **Expected output:** Vertices `{1,2,3}` or `{"A","B","C"}`; edges inferred from shared indices.
- **WL-portable:** Yes.

### 8. Add two ITensorNetworks (direct-sum bond dims)
- **Source:** `docs/src/itensor_networks.md:80-87`; `test/test_additensornetworks.jl:11-55`
- **Description:** `ψ_GHZ = ψ↑ + ψ↓` on 2×2 grid; result has summed bond dims; can be tested via expectation `⟨Sz⟩ = 0` for a pure GHZ. Also sums of random states with mismatched edges.
- **Inputs:** `named_grid((2,2))`, S=1/2.
- **API calls:** `+(::ITensorNetwork, ::ITensorNetwork)`, `add`, `inner_network`, `scalar`.
- **Expected output:** `<Sz>=0` exactly for GHZ.
- **WL-portable:** Yes.

### 9. Sum of QN-conserving product states (regression test)
- **Source:** `test/test_additensornetworks.jl:64-87`
- **Description:** Sum two product states that differ in flux per site on a 2×2 comb tree; check `ITensors.allfluxequal` on each output tensor.
- **Inputs:** `named_comb_tree((2,2))`, `siteinds("S=1/2", g; conserve_qns=true)`.
- **API calls:** `ttn(state, sites)`, `ψ1 + ψ2`, `ITensors.allfluxequal`.
- **Expected output:** All output tensors flux-consistent.
- **WL-portable:** No — paclet has no QN sectors.

### 10. Single-edge truncation of a generic ITensorNetwork
- **Source:** `docs/src/itensor_networks.md:95-101`
- **Description:** Truncate a single bond `(1,2)=>(1,3)` of a 3×3 grid TN by SVD with cutoff/maxdim.
- **Inputs:** 3×3 grid, S=1/2, bond dim ≤ 2.
- **API calls:** `truncate(tn, edge; cutoff, maxdim)`.
- **Expected output:** Qualitative.
- **WL-portable:** Yes.

### 11. Contract two adjacent vertices into one (`contract(tn, edge)`)
- **Source:** `test/test_itensornetwork.jl:91-100`
- **Description:** Contract along edge `((1,2),"ket") => ((1,2),"bra")` and verify the merged tensor equals the product of the two source tensors; the source vertex disappears.
- **Inputs:** 2×2 grid, `disjoint_union("bra"=>ψ, "ket"=>...)`.
- **API calls:** `contract(tn, edge)`, `disjoint_union`, `has_vertex`.
- **Expected output:** `tn_2[((1,2),"bra")] ≈ tn[((1,2),"ket")] * tn[((1,2),"bra")]`.
- **WL-portable:** Yes.

### 12. Vertex removal and induced subnetwork
- **Source:** `test/test_itensornetwork.jl:102-117`
- **Description:** `rem_vertex!(ψ, (1,2))` removes the vertex; `norm_sqr_network` rebuilds bra/ket only on remaining vertices.
- **Inputs:** 2×2 grid, S=1/2 product state.
- **API calls:** `rem_vertex!`, `norm_sqr_network`, `has_vertex`.
- **Expected output:** Vertices removed from both bra and ket layers.
- **WL-portable:** Partial.

### 13. Custom-eltype ITensorNetwork (Float32, ComplexF32, etc.)
- **Source:** `test/test_itensornetwork.jl:119-159`; `test/test_itensornetworksadaptext.jl:13-22`
- **Description:** Build `ITensorNetwork(g; kwargs...) do v ...` with custom eltype on (chain, 3×3, IndsNetwork variants); test `eltype`, `conj`, `dag`, `random_tensornetwork`, `Adapt.adapt(SinglePrecisionAdaptor(), tn)`.
- **Inputs:** `grid((4,))`, `named_grid((3,3))`; eltypes `{Float32, Float64, ComplexF32, ComplexF64}`.
- **API calls:** `ITensorNetwork(g; kwargs...) do v`, `random_tensornetwork`, `conj`, `dag`, `convert_scalartype`.
- **Expected output:** Eltype propagation correct.
- **WL-portable:** Yes (numeric only — paclet uses native Complex).

### 14. Custom-distribution random tensor network
- **Source:** `test/test_itensornetwork.jl:227-234`
- **Description:** `random_tensornetwork(rng, Uniform(-1,1), named_grid(4); link_space=2)`.
- **Inputs:** Chain of 4, bond dim 2, uniform[-1,1].
- **API calls:** `random_tensornetwork(rng, distribution, g; link_space)`.
- **Expected output:** Eltype Float64.
- **WL-portable:** Yes.

## Category 3: PEPS / 2D lattice TN

### 15. 2×2 grid GHZ-state expectation `⟨Sz⟩=0`
- **Source:** `test/test_additensornetworks.jl:11-26`
- **Description:** PEPS-on-2×2 GHZ via state-sum; `inner_network(ψ_GHZ, ψ_GHZ)` and `inner_network(ψ_GHZ, Oψ_GHZ)`, `scalar` ratio = 0.
- **Inputs:** `named_grid((2,2))`, S=1/2.
- **API calls:** `inner_network`, `scalar`, `apply(op("Sz",s[v]), …)`.
- **Expected output:** Exactly `0.0`.
- **WL-portable:** Yes.

### 16. PEPS-TEBD imaginary-time on 2×3 transverse-Ising
- **Source:** `test/test_tebd.jl:12-56`
- **Description:** PEPS imaginary-time evolution `tebd(group_terms(ℋ, g), ψ_init; β=2.0, Δβ=0.2, cutoff=1e-8, maxdim=2)` for transverse-Ising at h=0.1; compare ortho on/off energies. Test marked `@test_broken`.
- **Inputs:** `named_grid((2,3))`, S=1/2, β=2.0.
- **API calls:** `tebd`, `group_terms`, `ModelHamiltonians.ising`.
- **Expected output:** Qualitative — ground-state energy lowered; current Julia test is broken.
- **WL-portable:** Partial — TEBD on PEPS is heavy.

### 17. 3×3 PEPS BP cache and 2-site RDM
- **Source:** `test/test_belief_propagation.jl:23-77`
- **Description:** Random PEPS on `named_grid((3,3))` with bond dim 2, build `ψψ = ψ ⊗ prime(dag(ψ); sites=[])`, partition by ket/bra grouping, run `update(bpc; alg="bp", maxiter=25, tol=eps)`; build a 2-site RDM at `[(2,2),(2,3)]`, normalize trace, check shape `(2^2, 2^2)`, real eigenvalues, PSD.
- **Inputs:** 3×3 grid, S=1/2, bond dim χ=2; eltypes Float32/64, ComplexF32/64.
- **API calls:** `BeliefPropagationCache`, `update`, `environment`, `split_index`, `combiner`, `eigvals`.
- **Expected output:** RDM is 4×4, trace 1, PSD; messages converged.
- **WL-portable:** No — BP not implemented in paclet.

### 18. PEPS gate apply with BP environments (simple/general)
- **Source:** `test/test_apply.jl:12-75`
- **Description:** Apply 5 random unitaries on `((2,2),(1,2))` to a 2×2 PEPS, with two BP-environment groupings ("simple" by row, "general" by column = exact column env). Compare fidelity to exact-truncation result.
- **Inputs:** `named_grid((2,2))`, S=1/2, bond dim 2.
- **API calls:** `BeliefPropagationCache`, `update`, `environment`, `apply(o, ψ; envs, maxdim, normalize, callback)`, `inner`.
- **Expected output:** Fidelity GBP ≥ Fidelity SBP; non-zero truncation error.
- **WL-portable:** No — BP environment not in paclet.

## Category 4: Belief propagation (BP)

### 19. BP convergence + factor update on 3×3 PEPS
- **Source:** `test/test_belief_propagation.jl:30-58`
- **Description:** Mutate a factor in the cache via `@preserve_graph bpc[vket] = new_A`, run `update(bpc; alg="bp", maxiter=25, tol=eps)`, verify `message_diff(updated_message, message) < 10*eps`; then `update_factor` and check that underlying `tensornetwork(bpc)` has the new tensor.
- **Inputs:** 3×3 grid, S=1/2, χ=2.
- **API calls:** `BeliefPropagationCache`, `@preserve_graph setindex!`, `update`, `updated_message`, `message_diff`, `update_factor`, `tensornetwork`.
- **Expected output:** Convergence to machine precision.
- **WL-portable:** No.

### 20. BP scalar of zero-ed network
- **Source:** `test/test_belief_propagation.jl:79-86`
- **Description:** Set `ψ[(1,1)] = 0 * ψ[(1,1)]` on a 3×1 chain; `scalar(ψ; alg="bp")` returns 0.
- **Inputs:** `named_grid((3,1))`, χ=2.
- **API calls:** `scalar(; alg="bp")`.
- **Expected output:** `iszero == true`.
- **WL-portable:** No.

### 21. BP vs exact `inner` and `loginner` on tree
- **Source:** `test/test_inner.jl:11-49`
- **Description:** On a `uniform_tree(4)`, compute `inner(x,y; alg="bp")`, `inner(x,y; alg="exact")`, `loginner`. Then 3-layer matrix element `inner(x, A, y; alg="bp"|"exact")` with `A = ITensorNetwork(ttn(heisenberg(g), s))`.
- **Inputs:** Tree of 4 nodes, S=1/2, χ=2; Heisenberg operator from `OpSum`.
- **API calls:** `inner`, `loginner`, `scalar`, `inner_network`, `logscalar`.
- **Expected output:** `bp == exact == exp(logbp)` (BP exact on trees).
- **WL-portable:** Partial — paclet has exact contraction; BP needed for validation test only.

### 22. BP rescaling — `rescale_messages`, `rescale_partitions`, `rescale`
- **Source:** Documented `developer_methods.md:333-350`; not directly exercised in tests, but `test/test_normalize.jl` uses `rescale(tn; alg="bp")`.
- **Description:** Rescale messages/partitions so the local region scalar is 1.
- **Inputs:** Random TN on `named_comb_tree((2,3))` and `named_grid((3,2))`, χ=2.
- **API calls:** `rescale(tn; alg="bp", cache_update_kwargs)`, `edge_scalars`, `vertex_scalars`.
- **Expected output:** `scalar(tn_r; alg="exact") ≈ 1`.
- **WL-portable:** No.

### 23. BP vs exact `expect("Sz")` on tree, on grid (column-grouped), and with QNs
- **Source:** `test/test_expect.jl:11-50`
- **Description:** `expect(ψ, "Sz"; alg="bp")` vs `alg="exact"` on (a) `uniform_tree(4)` random state (BP exact on tree), (b) 2×2 grid with column-grouping (makes BP exact on this graph), (c) 2×2 QN-conserving product state.
- **Inputs:** L=4, χ=2; L=2, χ=2.
- **API calls:** `expect(ψ, "Sz"; alg, cache_construction_kwargs, cache_update_kwargs)`.
- **Expected output:** `bp ≈ exact` in all three cases.
- **WL-portable:** Partial — exact path portable; BP not.

### 24. BP environment / form-network gradient
- **Source:** `test/test_forms.jl:59-71`
- **Description:** On a 1×4 grid quadratic form, compare `environment(qf, …; alg="exact")` to `alg="bp"` with `update_cache=true|false`; with `update_cache=true` they agree (after normalization).
- **Inputs:** `named_grid((1,4))`, χ=2.
- **API calls:** `environment`, `state_vertices`, `update_cache`.
- **Expected output:** BP env ≈ exact env after one cache update; differs without one.
- **WL-portable:** Partial.

## Category 5: Boundary MPS / contraction sequences

### 25. Contraction-sequence backends comparison on PEPS norm-network
- **Source:** `test/test_contraction_sequence.jl:9-44`
- **Description:** Build `norm_sqr_network(ψ)` for a 2×3 PEPS at χ=10; compare contraction results across `alg ∈ {"optimal", "greedy", "tree_sa", "sa_bipartite", "kahypar_bipartite"(non-Windows)}`.
- **Inputs:** 2×3 grid, S=1/2, χ=10.
- **API calls:** `contraction_sequence(tn; alg, ...)`, `contract(tn; sequence)`.
- **Expected output:** All ≈ optimal.
- **WL-portable:** Partial — paclet has its own optimal-path / netcon; no SA/KaHyPar backends.

### 26. Path through chain TN — Dijkstra and mincut
- **Source:** `test/test_itensornetwork.jl:258-283`
- **Description:** `dijkstra_shortest_paths(tn, [1])` on `ITensorNetwork(named_grid(4); link_space=2|3)`; `GraphsFlows.mincut(tn, 2, 3)` with default and log-bond weights.
- **Inputs:** Chain of 4 vertices.
- **API calls:** `dijkstra_shortest_paths`, `weights(tn)` (returns `log2(bonddim)`), `GraphsFlows.mincut`.
- **Expected output:** Distances `[0,1,2,3]`; mincut weight `log2(3)`.
- **WL-portable:** Partial — needs graph algorithms.

## Category 6: TTN-DMRG / eigsolve

### 27. DMRG on Heisenberg comb-tree (manual)
- **Source:** `docs/src/solvers.md:18-57`
- **Description:** Heisenberg `OpSum` over edges of `named_comb_tree((3,2))`; build `H = ttn(h, s)`; random initial `ttn`; `dmrg(H, psi0; nsweeps=2, nsites=2, factorize_kwargs=(; cutoff=1e-10, maxdim=10), outputlevel=1)`.
- **Inputs:** Comb-tree (3,2), S=1/2, χ_max=10.
- **API calls:** `OpSum`, `ttn(h, s)`, `dmrg`, `eigsolve`.
- **Expected output:** Numerical (energy printed). Qualitative for validation.
- **WL-portable:** Partial — paclet has DMRG only on MPS.

### 28. DMRG on tree graph (3 branches × 3 sites) cross-checked against exact diagonalization
- **Source:** `test/solvers/test_eigsolve.jl:12-103`
- **Description:** Build a tree with central vertex `(0,0)` and 3 branches × 3 sites (`build_tree`); Heisenberg `OpSum`; alternating Up/Dn product state; compare DMRG energy to ED via `ed_ground_state` (`exp(-20H)` power iteration).
- **Inputs:** 10-vertex tree, S=1/2, cutoff 1e-5, maxdim 40, nsweeps 5; both 1-site (with subspace expansion) and 2-site DMRG; vector-of-cutoff/maxdim per sweep.
- **API calls:** `dmrg(H, psi0; factorize_kwargs, nsites, nsweeps, outputlevel, sweep_callback, extract!_kwargs)`, `SweepIterator`.
- **Expected output:** `E ≈ Ex atol = 1e-5`.
- **WL-portable:** Partial — tree-DMRG.

## Category 7: TDVP / time evolution / applyexp

### 29. Tree TDVP on chain-plus-ancilla, ground state phase
- **Source:** `test/solvers/test_applyexp.jl:25-78`
- **Description:** Heisenberg `OpSum` on a 10-site chain plus an ancilla vertex `0` attached to the middle (`chain_plus_ancilla`); compute ground state via DMRG; then `time_evolve(H, 0:0.02:0.1, gs_psi; factorize_kwargs, nsites=1|2)`. Verify `norm > 0.999`, `|⟨ψ_t|ψ_0⟩| > 0.99`, accumulated phase `atan(Im/Re) ≈ E*tmax`.
- **Inputs:** 10+1 site graph, S=1/2.
- **API calls:** `time_evolve(H, time_points, psi)`, `dmrg`, `inner`.
- **Expected output:** Phase test atol 1e-4.
- **WL-portable:** Partial — paclet TDVP for MPS only.

### 30. `applyexp` time-point handling on 10-site path graph
- **Source:** `test/solvers/test_applyexp.jl:80-143`
- **Description:** Heisenberg `OpSum` on `named_path_graph(10)`; verify `time_evolve` calls `sweep_callback` at exactly `[0.0, 0.1, 0.25, 0.32, 0.4]`, and `applyexp` with custom `exponent_points` calls callback at exactly those.
- **Inputs:** Chain of 10, S=1/2.
- **API calls:** `applyexp`, `time_evolve`, `current_time`, `current_exponent`, `sweep_callback`.
- **Expected output:** `times ≈ time_points` to `10*eps(Float64)`.
- **WL-portable:** Partial.

## Category 8: Expectation values on general graph / TTN

### 31. TTN `expect("Sz", state)` on comb-tree alternating Up/Dn
- **Source:** `test/test_ttn_expect.jl:1-22`
- **Description:** `c = named_comb_tree([2,2])`; `siteinds("S=1/2", c)`; alternating Up/Dn product `state`; verify `expect("Sz", state)[v]` is `±0.5` per the alternating pattern.
- **Inputs:** Comb-tree (2,2)=4 sites, S=1/2.
- **API calls:** `ttn(states, s)`, `expect("Sz", state)`.
- **Expected output:** Per-vertex magnetizations alternate `+0.5, -0.5`.
- **WL-portable:** Yes (exact for product state).

### 32. ITensorNetwork `expect(ψ, "Sz")` on grid via BP / exact
- **Source:** `docs/src/computing_properties.md:88-97`; `test/test_expect.jl`
- **Description:** `expect(psi, "Sz")` over a 4-site chain TTN; selected vertices; exact alg.
- **Inputs:** Chain TTN, χ=2.
- **API calls:** `expect(ψ, "Sz")`, `expect(ψ, "Sz", [(1,),(3,)])`, `expect(ψ, "Sz"; alg="exact")`.
- **Expected output:** Numerical match exact ≈ BP for tree.
- **WL-portable:** Partial — exact yes, BP no.

### 33. Inner products: `inner`, `loginner`, `norm` (BP default vs exact)
- **Source:** `docs/src/computing_properties.md:36-55`
- **Description:** `inner(phi, psi)`, `norm(psi)`, `loginner(phi, psi)`; for TTN: `inner(x, y)` and `norm(psi)` exploit ortho.
- **Inputs:** Chain `named_grid((4,))`, S=1/2, χ=2.
- **API calls:** `inner`, `norm`, `loginner`.
- **Expected output:** Numerical.
- **WL-portable:** Partial.

### 34. Form-network scalar reconstructs `inner`
- **Source:** `test/test_forms.jl:74-92`
- **Description:** On `named_comb_tree((3,3))` with non-uniform site indices (one vertex empty, one with single site), build `BilinearFormNetwork(ψbra, ψket)`, `LinearFormNetwork`, `QuadraticFormNetwork`, and check `scalar(form; alg="exact")` agrees with `inner(ψbra, ψket; alg="exact")`.
- **Inputs:** Comb-tree (3,3), ComplexF64, χ=2; mismatched site-index counts.
- **API calls:** `BilinearFormNetwork`, `LinearFormNetwork`, `QuadraticFormNetwork`, `scalar`, `inner`.
- **Expected output:** All four scalars equal.
- **WL-portable:** Partial.

## Category 9: Gauge fixing on graph (rescale / normalize)

### 35. `rescale` on comb tree (exact and BP) → unit scalar
- **Source:** `test/test_normalize.jl:14-26`
- **Description:** Random TN on `named_comb_tree((2,3))`, χ=2; `rescale(tn; alg="exact")` and `rescale(tn; alg="bp", cache_update_kwargs=(; maxiter=20))` both produce a TN whose exact scalar is `≈ 1`.
- **Inputs:** Comb-tree (2,3) flat tree.
- **API calls:** `rescale`, `scalar`.
- **Expected output:** `scalar ≈ 1.0`.
- **WL-portable:** Partial.

### 36. BP-`normalize` of complex random PEPS
- **Source:** `test/test_normalize.jl:28-53`
- **Description:** Random ComplexF32 TN on `named_grid((3,2))`, χ=2; `normalize(x; alg="exact")` then `normalize(x; alg="bp", cache!=Ref(BPC), update_cache=true, cache_update_kwargs)`. Verify all messages still ComplexF32, `edge_scalars ≈ 1`, `vertex_scalars ≈ 1`, `scalar(QuadraticFormNetwork(ψ); alg="bp") ≈ 1`.
- **Inputs:** 3×2 grid, ComplexF32, χ=2.
- **API calls:** `normalize`, `BeliefPropagationCache`, `QuadraticFormNetwork`, `messages`, `edge_scalars`, `vertex_scalars`.
- **Expected output:** Unit normalization through BP; eltype preserved.
- **WL-portable:** Partial.

## Category 10: TEBD / gate application

### 37. TEBD imaginary-time Ising on 2×3 PEPS (same as #16)

### 38. Apply `op("RandomUnitary",…)` two-site gate to PEPS with BP env (same as #18)

### 39. Single-edge contract / factor / svd / qr / truncate operations
- **Source:** `docs/src/interface_methods.md:43-71`; `test/test_itensornetwork.jl:235-256`
- **Description:** `contract(tn, edge)`, `factorize(tn, edge)`, `qr(tn, edge)`, `svd(tn, edge)`, `truncate(tn, edge)`. Test `factorize(tn, 4=>3)` followed by `tree_orthogonalize(tn, [3,4])` preserves `norm_sqr`.
- **Inputs:** Chain `named_grid(4)`, χ=2.
- **API calls:** `factorize`, `tree_orthogonalize`, `norm_sqr`, `inner`.
- **Expected output:** `Z ≈ Z̃` after factorize; after tree_orthogonalize.
- **WL-portable:** Yes.

## Category 11: OpSum→TTN (operator) construction

### 40. Build TTN operator from random rank-N ITensor (TTNO)
- **Source:** `test/test_ttno.jl:9-38`
- **Description:** Build random rank-N operator ITensor on a comb tree; `ttn(O, is_isp; cutoff=1e-10)` produces a TTN operator; contract back; verify `norm(O - O1) < 1e2*cutoff`.
- **Inputs:** Random comb tree of `tooth_lengths = rand(2:4)`, random per-site dim 1:3, double-priming for operator inds.
- **API calls:** `union_all_inds(is, prime(is; links=[]))`, `ttn(O, is_isp; cutoff)`, `contract`.
- **Expected output:** Reconstruction error ≲ 1e-8.
- **WL-portable:** Partial.

### 41. TTN multi-onsite OpSum addition (regression)
- **Source:** `test/test_opsum_to_ttn.jl:7-24`
- **Description:** `H1 = ttn(1.0*"Sx"@(1,1), s)`, `H2 = ttn(1.0*"Sy"@(1,1), s)`, `H3 = ttn(os1+os2, s)`; verify `H1 + H2 ≈ H3 rtol=1e-6` under `with_auto_fermion`.
- **Inputs:** `named_grid((2,1))`, S=1/2.
- **API calls:** `OpSum`, `ttn(os, s)`, `with_auto_fermion`.
- **Expected output:** `H1 + H2 ≈ H3`.
- **WL-portable:** Partial.

### 42. Cross-check `ttn(OpSum)` against `ITensorMPS.MPO`
- **Source:** `test/test_opsum_to_ttn_mpo_cross_check.jl:29-232`
- **Description:** On a 6-site comb tree linearized via `[4,1,2,5,3,6]`, build (a) Ising J1J2 + 4 longer-range Z…Z…Z terms, (b) Heisenberg J1J2 with QN, (c) tight-binding Fermion `t,t',h`, (d) Ising on a comb tree with an internal vertex with no site index. For each `root_vertex ∈ leaf_vertices(c)`, compare `contract(ttn(H, is; root_vertex, cutoff=1e-10))` to `prod(ITensorMPS.MPO(replace_vertices(v->vmap[v], H), sites))`.
- **Inputs:** Various 6-site combs; S=1/2 (with/without QN), Fermion (`conserve_nf`).
- **API calls:** `ttn(H, is; root_vertex, cutoff)`, `ITensorMPS.MPO`, `contract`, `replace_vertices`, `with_auto_fermion`, `removeqns`.
- **Expected output:** `Tttno ≈ Tmpo rtol = 1e-6`; for fermions `norm(Tmpo) ≈ norm(Tttno)`.
- **WL-portable:** No — needs `ITensorMPS` and QN/fermion.

### 43. ProjTTN out-of-place position update
- **Source:** `test/test_ttn_position.jl:12-46`
- **Description:** Build Heisenberg TTN `H` on comb tree `[2,2,2]` with `conserve_qns=true`, alternating Up/Dn state; `PH = ProjTTN(H); PH = position(PH, psi, [vs[2]]); PHc = position(PH, psi, [vs[2], vs[5]])`; verify `keys(environments(PH))` unchanged; `PHc` keys differ.
- **Inputs:** Comb tree (3 teeth × length 2), S=1/2, QN.
- **API calls:** `ProjTTN`, `position`, `environments`, `with_auto_fermion`.
- **Expected output:** Out-of-placeness verified.
- **WL-portable:** No.

### 44. ProjTTN construction edge case (empty pos / empty environments)
- **Source:** `test/test_ttn_position.jl:47-53`
- **Description:** `pos=Indices{Tuple{String,Int}}()`, `g=named_path_graph(2)`, `operator=ttn(ITensorNetwork{Any}(g))`, empty `Dictionary{NamedEdge{Any}, ITensor}`; check construction returns `ProjTTN{Any, Indices{Any}}`.
- **API calls:** `ProjTTN(pos, operator, environments)`.
- **WL-portable:** No.

## Category 12: Other (utilities, ITensorsExtensions)

### 45. `ITensorsExtensions.map_eigvals` (sqrt/inv) — bosonic and fermionic
- **Source:** `test/test_itensorsextensions.jl:7-134`
- **Description:** For random Hermitian rank-2 / rank-4 ITensors with QN sectors and with autofermion enabled, test `map_eigvals(sqrt, P, linds, rinds; ishermitian=true)` recovers `P` via `sqrtP * sqrtP'`; same for `inv`, `inv∘sqrt`. Includes index-permutation tests and bosonic-with-fermion-enabled mixed test.
- **Inputs:** dims n ∈ {2,3,5,10}; eltypes Float32/64, ComplexF32/64; QN`("Nf",0/1,-1)`.
- **API calls:** `map_eigvals`, `eigendecomp`.
- **Expected output:** `P ≈ sqrtP*sqrtP'`, `inv(P)*P ≈ I`.
- **WL-portable:** Yes (sqrt/inv via SVD/eigen).

### 46. IndsNetwork construction and merging on comb-tree
- **Source:** `test/test_indsnetwork.jl:10-182`
- **Description:** On `named_comb_tree((3,2))`, exhaustively test all combinations of `site_space` and `link_space` specs — uniform integer, integer vector, integer dictionary, Index dictionary, Index vector dictionary, multi-Index per vertex/edge. Also `union_all_inds(is1, is2)`.
- **API calls:** `IndsNetwork`, `union_all_inds`.
- **Expected output:** Per-vertex/edge dim/index correctness.
- **WL-portable:** Partial (paclet has IndsNetwork analog).

### 47. `siteinds` accepts string, int, Dictionary, function (with `addtags`)
- **Source:** `test/test_sitetype.jl:10-62`
- **Description:** On `named_grid((2,2))`, test `siteinds(value, g; addtags="TestTag")` for: uniform string sitetype, dictionary, integer dim, function returning string, function returning dim. Verify `IndsNetwork`, dim, tag set.
- **Inputs:** `["S=1/2", "S=1", "Boson", "Fermion"]` randomly per-vertex.
- **API calls:** `siteinds`.
- **Expected output:** Per-vertex `Index` properties.
- **WL-portable:** Partial.

### 48. Rooted directed graph utilities
- **Source:** `test/test_abstractgraph.jl:1-17`
- **Description:** Build a `NamedDiGraph([1,2,3])`; assert `is_rooted`, `root_vertex==1`, `is_binary_arborescence`; add a 4th vertex/edge — no longer binary.
- **API calls:** `NamedDiGraph`, `is_rooted`, `root_vertex`, `is_binary_arborescence`.
- **WL-portable:** Yes (Graph utilities are simple).

## Notes for the Wolfram paclet validation catalog

- The Julia package's `examples/` and `benchmark/` directories contain no real examples — every concrete computation lives either in `docs/src/*.md` (Documenter `@example main` blocks) or `test/*.jl`. So the Mathematica side cannot mimic an `examples/` workload — the test suite is the source of truth.
- The major gating capabilities for validation testing are: (a) BP cache infrastructure (Items 17-24, 32-34, 36, 38), (b) tree-graph DMRG/TDVP (Items 28-30), (c) QN-symmetric tensors (Items 9, 41-44), (d) auto-fermion logic (Items 42, 44, 45). None of these are implemented in the paclet; the rest of the catalog (≈25 examples) is portable directly via the paclet's existing `BinaryTensorNetwork` / `OptimalContractionPath` / `ArrayContract` machinery.
- "Partial" ratings indicate the result is reproducible numerically (e.g., expectation on a tree, contract-merge, single-bond truncate, Heisenberg on tree via exact diag) but the underlying gauge / cache machinery would need to be re-implemented to match Julia API semantics rather than just numerical output.
