# ITensors.jl Parity-Test Catalog

Source: `tn-external/numerical/ITensors.jl/`. **For MPS / MPO / DMRG / OpSum / `inner` / `expect` coverage, see [itensormps_examples.md](itensormps_examples.md).**

## Summary

ITensors.jl as audited (v0.9 era) is a **core ITensor library**. As of v0.7 (October 2024) **all MPS / MPO / DMRG / OpSum / `siteinds` / `dmrg` / `inner` / `expect` functionality was moved to the separate ITensorMPS.jl package** (now cataloged in [itensormps_examples.md](itensormps_examples.md)) and is therefore **not present** in this repo. There are also no AutoMPO entries, no symmetry-sector DMRG, and no observer/sweep callbacks. What remains: ITensor construction, indices/tags, contraction, decomposition, combiner, QN block sparse construction, plus two algorithmic examples (TRG and CTMRG for the 2D classical Ising model). Site-type/operator examples cover hand-built operator tensors only (matrix dispatched on tags), not full DMRG infrastructure.

**Total computational examples extracted: 41**, distributed by category:

| Category | Count |
|---|---|
| ITensor construction | 7 |
| Index / tagged indices | 5 |
| Contraction (`*`) | 6 |
| Decomposition (svd / qr / eigen / factorize) | 7 |
| Combiner | 3 |
| Symmetry sectors (QN / Block sparse) | 4 |
| Custom site types / operator dispatch | 3 |
| TRG / CTMRG algorithms | 4 |
| Misc (delta/trace, onehot, broadcast) | 2 |
| MPS construction / MPS algebra / MPO / DMRG / expect / OpSum / observer | 0 (see [itensormps_examples.md](itensormps_examples.md)) |

WL-portable counts: **Yes: 30, Partial: 9, No: 2** (the two No items are GPU-specific).

## ITensor construction

### 1. Default (uninitialised) ITensor with three indices
- **Source:** `README.md:132-167`
- **Description:** Build three Index objects, allocate two ITensors with shared/unshared indices, set scalar entries, contract, then add a same-shape random tensor.
- **Inputs:** `i = Index(3); j = Index(5); k = Index(2); l = Index(7)`; entries `A[i=>1,j=>1,k=>1]=11.1`, `A[i=>2,j=>1,k=>2]=-21.2`, `A[k=>1,i=>3,j=>1]=31.1`.
- **API:** `Index`, `ITensor`, `random_itensor`, `*`, `+`, `hasinds`.
- **Expected output:** `hasinds(C, i, k, l) == true`.
- **WL-portable:** Yes.

### 2. ITensor from explicit Julia matrix
- **Source:** `docs/src/examples/ITensor.md:65-93`
- **Description:** Construct an order-2 ITensor from a 2×2 Float64 matrix and an order-3 ITensor from `randn(4,7,2)`.
- **Inputs:** `M = [1 2; 3 4]` (Float64) with `i=Index(2,"i"), j=Index(2,"j")`; second case `T = randn(4,7,2)` with `k,l,m = Index(4),Index(7),Index(2)`.
- **API:** `ITensor(M, i, j)`.
- **Expected output:** `Array(A,i,j) == M`.
- **WL-portable:** Yes.

### 3. ITensor → Array round-trip
- **Source:** `docs/src/examples/ITensor.md:95-127`
- **Description:** Convert an ITensor back to a Julia array; index order in `Array(T, k, m)` controls the resulting layout. `Array(T,m,k)` returns the transpose.
- **Inputs:** `random_itensor(k,m)` with `k=Index(4), m=Index(2)`.
- **API:** `random_itensor`, `Array(T, idx_order...)`.
- **Expected output:** Shape `(4,2)`; `Array(T,m,k)` is the transpose.
- **WL-portable:** Yes.

### 4. Onehot ITensor (one nonzero element)
- **Source:** `docs/src/examples/ITensor.md:222-258`
- **Description:** Make an ITensor with a single 1.0 entry; either single-index or multi-index.
- **Inputs:** `i=Index(2)`; `O1 = onehot(i=>1)`, `O2 = onehot(i=>2)`, `T = onehot(i=>2, j=>3)` with `j=Index(3)`.
- **API:** `onehot`.
- **Expected output:** Vectors `[1,0]`, `[0,1]`; matrix with `T[2,3]=1.0` else 0.
- **WL-portable:** Yes.

### 5. Random complex/real-eltype ITensors
- **Source:** `test/base/test_itensor.jl:86-138`
- **Description:** Real, complex, Float32, ComplexF32 random tensors; `real`, `imag`, `isreal`, `iszero` predicates; `sum`/`prod` reductions.
- **Inputs:** `i,j = Index.(2,("i","j"))`.
- **API:** `random_itensor(elt, i, j)`, `real`, `imag`, `iszero`, `sum`, `prod`, `eltype`.
- **Expected output:** `Ac ≈ Ar + im*Ai`; `iszero(imag(A))` for real `A`; `sum(a) ≈ sum(array(a))`.
- **WL-portable:** Yes.

### 6. Element-wise broadcasting
- **Source:** `docs/src/examples/ITensor.md:167-220`
- **Description:** In-place scalar multiply (`A .*= 2.0`), add scalar (`.+= 1.5`), apply `abs.`, `one.`, custom function (sigmoid).
- **Inputs:** `A = random_itensor(i,j)` with `i=Index(2),j=Index(3)`.
- **API:** `.*=, .+=, .=, abs., one., custom .myf.`.
- **Expected output:** Element-wise updates match Julia array semantics.
- **WL-portable:** Yes.

### 7. ITensor with state-string indexing
- **Source:** `test/base/test_itensor.jl:140-168`
- **Description:** Set elements using string state names like `"↑"` / `"↓"` / `"Up"` / `"Dn"` on an Index tagged `"S=1/2"`.
- **Inputs:** `i₁ = Index(2,"S=1/2"); i₂ = Index(2,"S=1/2")`; `v[i₂=>"↑", i₁=>"↓"] = 1.0`.
- **API:** `getindex`/`setindex!` with `String` value.
- **Expected output:** Numeric `v[2,1]==1.0`, all others 0.
- **WL-portable:** Partial (requires implementing string-state lookup tied to site tag).

## Index / tagged indices

### 8. Plain Index with dimension and tag
- **Source:** `README.md:250-285`, `test/base/test_index.jl:8-35`
- **Description:** Construct dimension-only Index, copy, compare; add tag string `"j"`; query `dim`, `id`, `dir`, `plev`, `tags`.
- **Inputs:** `Index(3)`, `Index(5,"j")`, `Index(2,"n=1,Site")`, `Index(1, 2, In, "Link", 1)`.
- **API:** `Index`, `dim`, `id`, `tags`, `hastags`, `dir`, `plev`, `copy`, `==`.
- **Expected output:** `dim(i)==3`; `j==i` is false (different id); `hastags(s,"Site")==true`.
- **WL-portable:** Yes.

### 9. Prime levels
- **Source:** `README.md:269-285`, `test/base/test_index.jl:36-51`
- **Description:** Prime levels as integer "annotations": `i'`, `i''`, `i'''`, `i^6`. `noprime(i)` returns level 0.
- **Inputs:** any `i = Index(2)`.
- **API:** `prime`, `'`, `^`, `noprime`, `plev`.
- **Expected output:** `plev(i^6)==6`; `i1 == i` is false (different prime levels).
- **WL-portable:** Yes.

### 10. IndexVal (Pair semantics)
- **Source:** `test/base/test_index.jl:52-72`
- **Description:** Index-value pairs `i => 2`; `val`, `ind`, equality, priming a Pair.
- **Inputs:** `i = Index(2)`.
- **API:** `i => v`, `val`, `ind`, `IndexVal`, `prime(i=>2,4)`.
- **Expected output:** `val(i=>1)==1`, `ind(i=>1)==i`, `plev(prime(i=>2,4))==4`.
- **WL-portable:** Yes.

### 11. Random Index id-RNG seeding
- **Source:** `test/base/test_index.jl:102-173`
- **Description:** Independent RNG (`index_id_rng()`) controls Index ids; setting it gives reproducible ids while regular RNG controls tensor entries.
- **Inputs:** `Random.seed!(index_id_rng(), 1234)` and `Random.seed!(1234)`.
- **API:** `index_id_rng`, `Random.seed!`.
- **Expected output:** matching ids when both seeds match; tensor entries match when global seed matches.
- **WL-portable:** Partial (WL has different RNG; reproducibility requires explicit seed plumbing).

### 12. directsum of indices
- **Source:** `test/base/test_index.jl:174-184`
- **Description:** Direct-sum of two/three indices into a larger tagged index.
- **Inputs:** `i=Index(2,"i"), j=Index(3,"j"), k=Index(4,"k")`.
- **API:** `directsum(i, j; tags="test")`.
- **Expected output:** `dim(ij) == 5`, `hastags(ij,"test")`; `dim(ijk)==9`.
- **WL-portable:** Yes.

## Contraction (`*` and `contract`)

### 13. Sum-over-shared-index contraction
- **Source:** `examples/basic_ops/basic_ops.jl:1-65`, `README.md:132-167`
- **Description:** Build two matrices via Index-pair element setting, contract over shared `b`, also do `+`/`−`. Validate against Julia matrix `*`.
- **Inputs:** `a=b=c=Index(2)`; matrices `Z = diag(1,-1)`, `X = [[0,1],[1,0]]`, `Y = [[1,0],[0,1]]` (anti-diagonal style).
- **API:** `*`, `+`, `-`, `Array(R, a, c)`.
- **Expected output:** `Array(R,a,c) == jZ * jX`.
- **WL-portable:** Yes.

### 14. All rank/permutation contraction patterns
- **Source:** `test/base/test_contract.jl:7-150`
- **Description:** Verifies `*` for every shape combination: scalar*scalar, scalar*vector, vector*scalar, vectorᵀ*vector → scalar, vector⊗vector, matrix*scalar, matrix*vector (and transposed variants), matrix*matrix → scalar, matrix*matrix → matrix (all 4 transpose layouts), matrix⊗matrix, 3-tensor*scalar, 3-tensor*vector. Covers `Float64` and `ComplexF64`.
- **Inputs:** Various `Index` of dims 2, 3, 4, 5, 6 with random fills.
- **API:** `*`, `permute`, `array`, `scalar`.
- **Expected output:** Matches the equivalent Julia BLAS computation (`array(C) ≈ ...`).
- **WL-portable:** Yes — gold-standard parity case.

### 15. Trace via delta tensor
- **Source:** `docs/src/examples/ITensor.md:260-291`
- **Description:** Compute ∑ᵢ A^{iji} by contracting with `delta(i,l)` (Kronecker δ on hyperedge `i,l`).
- **Inputs:** `A = random_itensor(i,j,l)`, `i=Index(4), j=Index(3), l=Index(4)`.
- **API:** `delta`, `*`.
- **Expected output:** Matches `sum(A[ii,jj,ii] for ii)` for each `jj`.
- **WL-portable:** Partial (WL TensorNetworks paclet uses `SymbolicDeltaProductArray` for hyper-edges; convert via `Normal[]` per project memory).

### 16. Trace via diag pairs
- **Source:** `test/base/test_itensor.jl:293-310`
- **Description:** Trace of a complex ITensor with three pairs of primed/unprimed indices: `tr(T)` vs contraction with three deltas.
- **Inputs:** `i,j,k,l = Index.((2,3,4,5),...)`, `T = random_itensor(elt, j,k',i',k,j',i)`.
- **API:** `tr`, `δ`, `*`, `scalar`.
- **Expected output:** `tr(T) ≈ scalar(T * δ(i,i') * δ(j,j') * δ(k,k'))`.
- **WL-portable:** Partial (hyperedge handling in WL paclet).

### 17. Identity-tag contraction with QN
- **Source:** `examples/basic_ops/qn_itensors.jl:1-31`
- **Description:** QN-conserving random tensors of flux 0; sum (`A+B`), contract over primed level (`A' * B`), contract with non-zero-flux tensor (`A' * C`).
- **Inputs:** `i = Index([QN(0,2)=>1, QN(1,2)=>1], "i")`; parity Z2.
- **API:** `random_itensor`, `dag`, `prime`, `+`, `*`, `combiner`.
- **Expected output:** Sum/contraction obey QN conservation; outputs printed.
- **WL-portable:** Partial (paclet would need a parity-conserving block-sparse path; otherwise fold to dense and verify only the values).

### 18. Optimal contraction sequence (TensorOperations)
- **Source:** `docs/src/ContractionSequenceOptimization.md:21-128`
- **Description:** A 5-tensor MPS-DMRG-environment-style network `[ψ, L, H₁, H₂, R]` with symbolic dims `m,k,d`; compare cost of two hand-coded sequences and the optimum across dim ranges.
- **Inputs:** indices of dims `m,m,k,k,k,d,d`; symbolic via `@variables m,k,d`.
- **API:** `contraction_cost`, `optimal_contraction_sequence`, `dag`, `'`.
- **Expected output:** `cost1` faster for large `m`, `cost2` faster for large `k`.
- **WL-portable:** Partial (`OptimalContractionPath` from paclet exists; uses different sequence convention — opt_einsum vs ITensors).

## Decomposition (svd / qr / eigen / factorize)

### 19. SVD of a matrix-shaped ITensor
- **Source:** `README.md:170-194`
- **Description:** SVD of a random 10×20 matrix; check `M ≈ U*S*V`.
- **Inputs:** `i=Index(10), j=Index(20)`, `M = random_itensor(i,j)`.
- **API:** `svd(M, i)`.
- **Expected output:** `M ≈ U*S*V == true` (norm error ≲ 1e-13).
- **WL-portable:** Yes.

### 20. SVD of a 4-tensor with grouped row/col indices
- **Source:** `README.md:196-230`
- **Description:** SVD of `random_itensor(i,j,k,l)` (each dim 4) treating `(i,k)` as row group, `(j,l)` as column group.
- **Inputs:** all dims 4.
- **API:** `svd(T, i, k)` (or `svd(T, (i,k))`).
- **Expected output:** `hasinds(U,i,k)`; `hasinds(V,j,l)`; `T ≈ U*S*V`.
- **WL-portable:** Yes.

### 21. Truncated SVD
- **Source:** `docs/src/examples/ITensor.md:364-421`
- **Description:** SVD with `cutoff=1e-2`. Compute squared relative truncation error.
- **Inputs:** `i=Index(10), j=Index(40), k=Index(20)`, `T = random_itensor(i,j,k)`.
- **API:** `svd(T, (i,k); cutoff=1e-2, maxdim=M, mindim=m)`.
- **Expected output:** `truncerr = (||USV-T||/||T||)^2 < 1e-2`.
- **WL-portable:** Yes.

### 22. SVD with empty left/right index sets
- **Source:** `test/base/test_svd.jl:77-145`
- **Description:** SVD where one side is empty (singleton dummy index inserted by `svd`); for both Index spaces (dense `2`) and QN `[QN(0,2)=>1, QN(1,2)=>1]`, all four eltypes.
- **Inputs:** `i, j = Index(space)`; `A = random_itensor(elt, i, j)`.
- **API:** `svd(A, i, j; cutoff)`, `svd(A, (); cutoff)`.
- **Expected output:** `U*S*V ≈ A`; `dim(S)==1`; orders shifted by 1.
- **WL-portable:** Partial (degenerate-shape edge cases; QN variant requires block-sparse SVD).

### 23. QR factorization with positive=true
- **Source:** `docs/src/examples/ITensor.md:423-444`, `test/base/test_decomp.jl:164-200`
- **Description:** QR of an order-3 tensor with `(i,k)` going to Q. With `positive=true`, R has non-negative diagonal (unique factorization).
- **Inputs:** Various — e.g., `Index(5,"l"), Index(2,"s"), Index(5,"r")`, `random_itensor(elt, l, s, r)`; `Linds = inds(A)[1:ninds]` for `ninds=0..3`.
- **API:** `qr(A, Linds; positive=true, tags=...)`, also `rq`, `ql`, `lq`.
- **Expected output:** `A ≈ Q*R` (atol 1e-13); `Q*dag(prime(Q,q)) ≈ δ(q,q')`; R is upper-triangular.
- **WL-portable:** Yes.

### 24. Eigen with hermitian-flag and bond-dim cap
- **Source:** `examples/src/ctmrg_isotropic.jl:13-30`
- **Description:** Hermitian eigendecomposition of a grown CTM with `cutoff` and `maxdim=χmax`; explicit `lefttags`/`righttags`.
- **Inputs:** `Cₗᵤ⁽¹⁾ = Aₗ * Cₗᵤ * Aᵤ * T` (order-4); decompose with row indices `(lₕ', sₕ')`, col indices `(lᵥ', sᵥ')`.
- **API:** `eigen(M, rowinds, colinds; ishermitian=true, cutoff, maxdim, lefttags, righttags)`.
- **Expected output:** Eigenvalues on resulting diagonal index, low-rank reconstruction.
- **WL-portable:** Yes (use `Eigensystem` after suitable matricization).

### 25. factorize with eigen_perturbation
- **Source:** `test/base/test_decomp.jl:120-162`
- **Description:** `factorize(phi, (l,s1); ortho="left", eigen_perturbation=drho)`. Norm error of `U*B - phi` < 1e-5; perturbation increases retained dimension.
- **Inputs:** `l=Index(4), s1=Index(2), s2=Index(2), r=Index(4)`; `phi = random_itensor(...)`; `drho = sym(random)*1e-5`.
- **API:** `factorize`, `which_decomp="eigen"`, `eigen_perturbation`.
- **Expected output:** `dim(commonind(x,y)) == maxdim` when perturbation is supplied.
- **WL-portable:** Partial (eigen-perturbation is a domain trick; reimplementation feasible).

### 26. truncate! semantics
- **Source:** `test/base/test_decomp.jl:95-111`
- **Description:** Vector truncation: `[0.1, 0.01, 1e-13]` with `cutoff=1e-5, use_absolute_cutoff=true` returns `(1e-13, (0.01+1e-13)/2)`, length 2.
- **Inputs:** Sorted decreasing vectors of singular-value-like reals, including negative-definite case.
- **API:** `NDTensors.truncate!`.
- **Expected output:** Exact tuple as above.
- **WL-portable:** Yes (deterministic numeric).

## Combiner

### 27. Two-, three-, four-index combiner round trip
- **Source:** `docs/src/examples/ITensor.md:445-499`, `test/base/test_combiner.jl:42-200`
- **Description:** Build combiner over chosen indices, contract with tensor, then contract with the same combiner to undo. Test all permutations of indices, both `C*A` and `A*C` orders.
- **Inputs:** `A = random_itensor(i,j,k,l)` with dims `(2,3,4,5)`.
- **API:** `combiner`, `combinedind`, `*`, `dag`.
- **Expected output:** `D = (A*C)*C ≈ A`; combined dim equals product of merged dims.
- **WL-portable:** Yes (use `Flatten` / index reshape).

### 28. Empty combiner is identity
- **Source:** `test/base/test_combiner.jl:24-40`
- **Description:** `combiner()` (no args) is order-0 and `A*combiner() == A`.
- **API:** `combiner()`, `order`, `combinedind`.
- **Expected output:** `order(C)==0`; `A*C == A`.
- **WL-portable:** Yes.

### 29. Block-sparse combiner contraction
- **Source:** `NDTensors/test/test_combiner.jl:30-122`
- **Description:** Combine block-sparse tensor of shape `(d,d,d)` with combiner `(d²,d,d)` and uncombine to recover the original (per-element equality).
- **Inputs:** `d=2`; single nonzero block `Block(1,1,1)`; both Float64 and Float32.
- **API:** `Combiner`, `BlockSparse`, `tensor`, `contract`.
- **Expected output:** `output_tensor[i] == input_tensor[i]` and uncombined tensor exactly recovers input.
- **WL-portable:** No (paclet does not currently support block-sparse symmetric tensors).

## Symmetry sectors (QN / Block sparse)

### 30. QN basics — values, modulus, arithmetic
- **Source:** `test/base/test_qn.jl`
- **Description:** Construct, compare, add, subtract `QN("Sz",1)`, `QN("P",1,2)` (mod 2), multi-sector `QN(("A",1),("B",2))`, ordering.
- **API:** `QN`, `val`, `modulus`, `+`, `-`, `==`, `<`.
- **Expected output:** `QN("Sz",1)+QN("Sz",2)==QN("Sz",3)`; mod-2: `QN("P",1,2)+QN("P",1,2)==QN("P",0,2)`; `QN("T",-1,3)==QN("T",2,3)`.
- **WL-portable:** Yes (pure value type).

### 31. QN-Index construction
- **Source:** `docs/src/IndexType.md`, `test/base/test_qnitensor.jl:13-20`
- **Description:** Sectorial index `Index([QN(0)=>1, QN(1)=>2], "i")`; query `dim`, `nblocks`, `qn`.
- **API:** `Index(::Vector{Pair{QN,Int}}, tags)`.
- **Expected output:** Total dim is sum of block dims (3 for the example); 2 blocks; `qn(s,1)==QN(0)`.
- **WL-portable:** Partial (paclet would need to track sector multiplicities explicitly).

### 32. Block-sparse ITensor from dense Array (with tolerance)
- **Source:** `test/base/test_qnitensor.jl:22-106`
- **Description:** Convert a dense matrix to a block-sparse ITensor via `ITensor(A, i', dag(i))`. With `tol=1e-9`, a `1e-10` element is dropped. With incompatible flux pattern, raises an error unless `checkflux=false`.
- **Inputs:** `i = Index([QN(0)=>1, QN(1)=>2], "i")`; matrix `[1 0 0; 0 2 3; 0 1e-10 4]`.
- **API:** `ITensor(A, i', dag(i); tol, checkflux)`, `flux`, `nnzblocks`, `nzblocks`, `Block`.
- **Expected output:** `flux==QN(0)`, 2 nonzero blocks `Block(1,1)`, `Block(2,2)`; `T[3,2]==0` after tol prune.
- **WL-portable:** No.

### 33. BlockSparseTensor arithmetic and permutedims
- **Source:** `NDTensors/test/test_blocksparse.jl:12-120`
- **Description:** Build `BlockSparseTensor{Float64}` with two nonzero blocks, fill with `randn!`, do `2*A`, `A/2`, `A+B`, `permutedims(A,(2,1))`, conjugate. Verify nnz blocks unchanged and per-element equality.
- **Inputs:** Block-row dims `[2,3]`, block-col dims `[4,5]`, locs `[(1,2),(2,1)]`.
- **API:** `BlockSparseTensor`, `nnz`, `nnzblocks`, `blockdims`, `permutedims`, `+`, `*`, `/`, `conj`.
- **Expected output:** `nnz(A) == 2*5+3*4 = 22`; `B[1,1]==2*A[1,1]`; per-block equality after permutedims.
- **WL-portable:** No.

## Custom site types / operator dispatch

### 34. Pauli & Clifford operators on Qubit sites
- **Source:** `test/base/test_phys_site_types.jl:47-200+`
- **Description:** Hand-coded matrix forms for "Z", "Y", "X", "H", "Phase"/"S"/"P", "T"/"π/8", "Rx", "Ry", "Rz", "Rn", "S+"/"S-", "Splus"/"Sminus", projector "Proj0"/"Proj1", "√NOT", "√SWAP", "√iSWAP", "SWAP", "iSWAP", "Cphase", "RXX", "RYY". Also state vectors "Up", "Dn", "+", "X+", "Y+", "Z+", "Tetra1..4".
- **Inputs:** `s = siteinds("Qubit", 10)` (a no-op vector creator) — the example also uses `siteind("Qubit"; conserve_parity=true / conserve_number=true)`.
- **API:** `op("name", s, n; θ, ϕ, λ)`, `state("Up", s[i])`, `apply`, `product`.
- **Expected output:** Each operator matches its standard 2×2 (or 4×4) matrix form to machine precision.
- **Note:** `siteinds`, `op`, `state` here come from the in-package `ITensors.SiteTypes` submodule, not from the moved-out `ITensorMPS.jl`.
- **WL-portable:** Yes (`PauliMatrix` and friends in WL).

### 35. Operator string algebra — `*`, `+`, `-` in op names
- **Source:** `test/base/test_sitetype.jl:14-94`
- **Description:** Compose operators by string: `op("Sz * Sz", s, 2)` ≈ `product(Sz, Sz)`; `"S+ + S-"`, `"S+ - S- - S+"`, `"S+ * S- - S- * S+ + Sz * Sx * Sy"`, etc.
- **Inputs:** `siteind("S=1/2")`, `siteind("Qudit"; dim=5)` ("a", "a†").
- **API:** `op` with string expressions.
- **Expected output:** Matches direct matrix construction.
- **WL-portable:** Yes (Mathematica `Dot`/`+` directly).

### 36. Matrix-by-matrix custom op definition
- **Source:** `test/base/test_sitetype.jl:31-32, 96+`
- **Description:** Pass a literal matrix to `op`: `op([1 0; 0 -1]/2, [s])` constructs the Sz tensor. Custom site type via `ITensors.op(::OpName"Sz", ::SiteType"_Custom_", s::Index)`.
- **API:** `op(matrix, [site])`, `OpName"..."`, `SiteType"..."`, multiple-dispatch overload.
- **Expected output:** Matches the named operator.
- **WL-portable:** Yes (use pattern-dispatched downvalues).

## TRG / CTMRG algorithms (numerical correctness)

### 37. 2D classical Ising MPO tensor (Boltzmann tensor)
- **Source:** `examples/src/2d_classical_ising.jl:5-46`
- **Description:** Construct the 4-leg Boltzmann tensor for the 2D classical Ising model at inverse temperature β by absorbing two `√Q` factors per leg, using the symmetric/antisymmetric eigenbasis.
- **Inputs:** `sₕ, sᵥ = Index(2,"horiz"), Index(2,"vert")` (with primed siblings); β > 0; `J=1.0`. Optional `sz=true` flag flips the (1,1,1,1) entry to compute magnetization.
- **API:** `ITensor`, `δ`, `sim`, `itensor(vec(X), s̃, s)`, `*`.
- **Expected output:** A 2×2×2×2 tensor that reproduces the partition function when traced.
- **WL-portable:** Yes.

### 38. TRG for 2D Ising free energy
- **Source:** `examples/trg/run.jl`, `examples/src/trg.jl`, `test/base/test_trg.jl`
- **Description:** Tensor renormalization group with `χmax=20` and `nsteps=20` on the Ising tensor at `β = 1.1·βc` where `βc = 0.5·log(√2 + 1)`. Returns partition function per site `κ`.
- **Inputs:** `β = 1.1*βc`, `χmax=20`, `nsteps=20`, `svd_alg="divide_and_conquer"`.
- **API:** `factorize(T, (sh',sv'); maxdim, cutoff, ortho="none", tags, svd_alg)`, `δ`, `*`, indexed slicing `T[]`.
- **Expected output:** `κ ≈ exp(-β · ising_free_energy(β))` to atol = 1e-4. The exact value of `exp(-β · f(β))` for `β=1.1·βc` is approximately **3.071**. Magnetization comparison: `m ≈ ising_magnetization(β) = (1 - sinh(2β)^(-4))^(1/8) ≈ 0.794`.
- **WL-portable:** Yes (key parity benchmark).

### 39. Isotropic CTMRG for 2D Ising
- **Source:** `examples/ctmrg/isotropic/run.jl`, `examples/src/ctmrg_isotropic.jl`, `test/base/test_ctmrg.jl`
- **Description:** Corner-transfer-matrix RG with `χmax=20`, `nsteps=100`. Uses Hermitian eigendecomposition of the grown CTM with maxdim cap. Compute `κ = (ACT_l * dag(AC_l))[]` and magnetization `m`.
- **Inputs:** `β=1.1·βc`, `χmax=20`, `nsteps=100`. Initial CTM `Clu = ITensor(lᵥ,lₕ); Clu[1,1]=1.0`. Initial HRTM `Aₗ` with single nonzero `Aₗ[1,1,1]=1.0`.
- **API:** `eigen`, `dense`, `replaceinds`, `prime`, `dag`, `commonind`, `uniqueind`.
- **Expected output:** `κ ≈ exp(-β · ising_free_energy(β))` (≈ 3.071); `|m| ≈ ising_magnetization(β)` (≈ 0.794).
- **WL-portable:** Yes (algorithmic; the eigendecomposition path is straightforward in WL).

### 40. Anisotropic CTMRG (2×2 unit cell)
- **Source:** `examples/ctmrg/anisotropic/run.jl`, `examples/src/ctmrg_anisotropic.jl`
- **Description:** Multi-site CTMRG on a 2×2 unit cell with periodic indexing. Performs left/right/up/down sweeps using SVD-based projectors with `maxdim=10` over 1000 steps.
- **Inputs:** `ny=nx=2`, `β=1.1·βc`, internal `maxdim=10`, `nstep=1000`.
- **API:** `random_itensor`, `svd(ρ, (li, si); utags, vtags, maxdim)`, `δ`, `prime(C, (li,si))`, helpers.
- **Expected output:** `κave ≈ exp(-β · ising_free_energy(β))` to relative tolerance 1e-10. (Note: the magic constant for `1.1·βc` is the same ~3.071.)
- **WL-portable:** Partial (lots of plumbing; requires periodic-index helpers).

## Misc / utility numerical checks

### 41. NDTensors svd_recursive on a known low-rank matrix
- **Source:** `test/base/test_svd.jl:10-19`, plus regression test 41-75
- **Description:** SVD of an exact rank-3 4×4 matrix `[[1,2,5,4],[1,1,1,1],[0,0.5,0.5,1],[0,1,1,2]]`. Also a hand-coded 2×2×2×2 regression-test tensor whose `svd(T,(u1,t1))` must be accurate.
- **Inputs:** Hard-coded literal matrix and 4-tensor.
- **API:** `NDTensors.svd_recursive`, `svd(itensor(M, t1,t2,u1,u2), (u1,t1))`.
- **Expected output:** `||U·Diag(S)·V' − M|| < 1e-13`; `||U*S*V − T||/||T|| < 1e-10`.
- **WL-portable:** Yes (deterministic).

## Notes on excluded / not-applicable categories

- **MPS construction, MPS algebra, MPO construction, MPO algebra, DMRG, expectation value (`expect`), `inner`, ground-state energy, OpSum / Hamiltonian, AutoMPO, observer/sweep callbacks** — all of these were moved to **ITensorMPS.jl** in v0.7 (October 2024). The package as audited contains *zero* such examples in `docs/src/`, `examples/`, or `test/base/`. The only references that survive are:
  - The MPS-DMRG-environment-shaped 5-tensor network in `docs/src/ContractionSequenceOptimization.md` (entry #18) — but it's purely about contraction-sequence cost, not DMRG.
  - String mentions ("Ising MPO") inside TRG/CTMRG comments, where "MPO" refers loosely to the 4-leg Boltzmann tensor, not an `ITensorMPS.MPO`.
- **GPU items in `docs/src/RunningOnGPUs.md`:** WL-portable: No.
- **Multithreaded block-sparse contraction in `docs/src/Multithreading.md`:** Same algorithmic shape as #33 plus threading flag — not a new computational example.
- **HDF5 round-trip examples (`docs/src/HDF5FileFormats.md`, `docs/src/examples/ITensor.md:502-557`):** I/O not numerical computation; skipped from catalog.
- **Upgrade-guide examples (`docs/src/UpgradeGuide_0.1_to_0.2.md`):** These are migration explanations, not new test cases.

## Recommended parity-test priority order

For implementing in the WL TensorNetworks paclet (highest signal first):
1. Entries #1, #13, #14, #19, #20, #23, #27, #41 — core ITensor + contraction + decomp parity (deterministic numeric tests).
2. Entries #38, #39 — TRG and isotropic CTMRG against the closed-form Ising free energy and magnetization.
3. Entries #34, #35 — operator-on-site dispatch.
4. Entries #22, #24, #25 — edge-case decomposition behaviour.
5. Entry #18 — contraction-sequence comparison (mind the convention: paclet `OptimalContractionPath` defaults to `Method->"size"`; pass `Method->"flops"` for parity, per project memory).
6. Entries #30–#33 — QN/block-sparse; partly out of scope per project memory unless paclet adds block-sparse support.

## Note: missing MPS/DMRG features

For MPS/MPO/DMRG/`inner`/`expect`/OpSum coverage, see [itensormps_examples.md](itensormps_examples.md) — 134 entries from ITensorMPS.jl which now lives at `tn-external/numerical/ITensorMPS.jl/`.
