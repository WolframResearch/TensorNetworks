# Quimb Validation-Test Catalog

Source: `tn-external/numerical/quimb/`. All paths below are relative to that root.

## Summary

**Total entries: 142**

Per category:
- tensor algebra: 22
- MPS construction: 11
- MPS algebra: 12
- MPO: 8
- PEPS: 11
- MERA: 5
- contraction path: 9
- decomposition: 11
- gauge: 7
- circuit construction: 13
- gate application: 12
- expectation value: 11
- sampling/measurement: 8
- optimization: 9
- other (matrix/state ops, generators, evolution): 23

Conventions:
- "WL-portable: Yes" means standard linear algebra / tensor-contraction; "Partial" means doable but with workarounds (e.g., needs custom approximate contraction); "No" means inseparable from JAX/Torch tracing or external solvers (slepc, GPU, etc.).

## tensor algebra

1. **Construct rank-3 tensor & its conjugate.** Source: `tests/test_tensor/test_tensor_core.py:36-52`. Inputs: shape (2,3,4), inds [0,1,2], tags "blue". API: `Tensor(data, inds, tags)`, `.H`. Expected: `a.size == 24`, `a.H.data == data.conj()`. WL-portable: Yes.
2. **Pauli-paulis bell-state TN contraction.** Source: `docs/tensor/tensor-basics.ipynb`. Inputs: bell singlet psi-, X on k0, Y on k1, random bra. API: `qtn.Tensor`, `&`, `^...`. Expected: scalar (≈ -0.0017 - 0.0266j for the random bra; the absolute value depends on bra, but `(bra | X | Y | ket) ^ ...` is a deterministic 4-tensor contraction). WL-portable: Yes.
3. **Tensor `@` matmul aligning by name.** Source: `docs/tensor/tensor-basics.ipynb`, `tests/test_tensor/test_tensor_core.py:380-455`. Inputs: `rand_tensor([2,3], "ax", "A")`, `rand_tensor([4,3], "bx", "B")`. API: `t1 @ t2`. Expected: shape (2,4), inds (a, b). WL-portable: Yes.
4. **Triple contraction via tensor_contract.** Source: `tests/test_tensor/test_tensor_core.py:421-430`. Inputs: shapes (2,3,4)/(3,4,5)/(5,2,6), inds [0,1,2]/[1,2,3]/[3,0,4]. API: `tensor_contract(a,b,c)`. Expected: shape (6,), inds (4,), tags merged. WL-portable: Yes.
5. **Sum over hyper-indices (`output_inds` required).** Source: `docs/tensor/tensor-design.ipynb`. Inputs: three (2,2) tensors, inds (a,x), (b,x), (c,x). API: `qtn.tensor_contract(T1,T2,T3, output_inds=["a","b","c"])`. Expected: `T[a,b,c] = sum_x T1[a,x]T2[b,x]T3[c,x]`, shape (2,2,2). WL-portable: Yes.
6. **Fuse indices.** Source: `tests/test_tensor/test_tensor_core.py:125-135`. Inputs: shape (2,3,4,5), inds "abcd". API: `t.fuse({"bra": ["a","c"], "ket": ["b","d"]})`. Expected: shape (8,15), inds ("bra","ket"). WL-portable: Yes.
7. **Trace pair of indices.** Source: `tests/test_tensor/test_tensor_core.py:185-203`. Inputs: shape (3,3,3), inds "abc". API: `t.trace("a","c")`. Expected: ≈ `np.trace(t.data, axis1=0, axis2=2)`. WL-portable: Yes.
8. **Multi-index trace.** Source: `tests/test_tensor/test_tensor_core.py:205-211`. Inputs: shape (3,3,3,3,3), inds "abcde". API: `t.trace(["a","c"], ["e","b"])`. Expected: equals `t.trace("a","e").trace("c","b")`. WL-portable: Yes.
9. **Sum-reduce one index.** Source: `tests/test_tensor/test_tensor_core.py:213-226`. Inputs: shape (2,3,4), inds "abc". API: `t.sum_reduce("a")`. Expected: shape (3,4) = `t.data.sum(axis=0)`. WL-portable: Yes.
10. **Vector reduce (single-index inner product).** Source: `tests/test_tensor/test_tensor_core.py:228-234`. Inputs: shape (2,3,4), inds "abc"; vector g of size 3. API: `t.vector_reduce("b", g)`. Expected: shape (2,4) = `einsum("abc,b->ac", t, g)`. WL-portable: Yes.
11. **Index selection (`isel`).** Source: `tests/test_tensor/test_tensor_core.py:259-264`. Inputs: shape (2,3,4,5,6) inds "abcde". API: `T.isel({"d":2, "b":0})`. Expected: shape (2,4,6) = `T[:,0,:,2,:]`. WL-portable: Yes.
12. **Squeeze size-1 dims.** Source: `tests/test_tensor/test_tensor_core.py:283-295`. Inputs: shape (1,2,3,1,4) inds "abcde". API: `t.squeeze()`. Expected: shape (2,3,4), inds "bce". WL-portable: Yes.
13. **`reindex` rename inds.** Source: `tests/test_tensor/test_tensor_core.py:1117-1138`. Inputs: 3-tensor TN. API: `tn.reindex({4:"foo", 2:"bar"})`. Expected: outer ind 4 → "foo", inner 2 → "bar". WL-portable: Yes.
14. **Tensor arithmetic (`+ - * / **`) with index alignment.** Source: `tests/test_tensor/test_tensor_core.py:704-716`. Inputs: two (2,3,4) tensors with same/differing inds. API: `op(a,b)`. Expected: matches `op(a.data, b.data)` if same inds, else broadcasts. WL-portable: Yes.
15. **Connect ind names between two tensors.** Source: `tests/test_tensor/test_tensor_core.py:718-733`. Inputs: shape (2,3) inds "ab", shape (3,2) inds "cd". API: `qtn.connect(x,y,0,1); qtn.connect(x,y,1,0)`. Expected: outer_inds() reduces to 0. WL-portable: Yes.
16. **Tensor direct product.** Source: `tests/test_tensor/test_tensor_core.py:752-779`. Inputs: pairs of random tensors. API: `tensor_direct_product(a1,a2, sum_inds=("a"))`. Expected: `(a1 @ b1) + (a2 @ b2) == direct_prod(a1,a2) @ direct_prod(b1,b2)`. WL-portable: Yes.
17. **Multiply diagonal gauge inserted on a bond.** Source: `tests/test_tensor/test_tensor_core.py:798-807`. Inputs: 2 random tensors sharing bond "b" of size 4. API: `t.multiply_index_diagonal("b", s)` and inverse on neighbor. Expected: contraction unchanged. WL-portable: Yes.
18. **Inner product of normalized MPS == 1.** Source: `docs/tensor/tensor-basics.ipynb`. Inputs: `MPS_rand_state(10, 7)`. API: `psi.H @ psi`. Expected: 1.0. WL-portable: Yes.
19. **Frobenius norm via `t.H @ t`.** Source: `docs/tensor/tensor-basics.ipynb`. Inputs: any tensor / TN. API: `tn.H @ tn`. Expected: `tr(A^† A)`. WL-portable: Yes.
20. **Hermitian conjugate `.H`.** Source: `tests/test_tensor/test_tensor_core.py:39-40`. Inputs: complex (2,3,4). API: `a.H`. Expected: `a.data.conj()`. WL-portable: Yes.
21. **Transpose by named order.** Source: `tests/test_tensor/test_tensor_core.py:167-174`. Inputs: shape (2,3,4,5,2,2), inds "abcdef". API: `a.transpose(*"cdfeba")`. Expected: shape (4,5,2,2,3,2) inds "cdfeba". WL-portable: Yes.
22. **Tensor network sum via `tensor_network_sum`.** Source: `tests/test_tensor/test_tensor_core.py:1015-1022`. Inputs: random TN A, copy B with randomized data. API: `qtn.tensor_network_sum(A, -1*B)`. Expected: norm equals `A.distance(B)`. WL-portable: Partial.

## MPS construction

1. **Random MPS.** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: L=20, bond_dim=50. API: `qtn.MPS_rand_state(20, 50)`. Expected: 20 tensors, max_bond=50, site_tag_id="I{}", site_ind_id="k{}". WL-portable: Yes.
2. **Computational basis MPS.** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: bitstring "0"*10. API: `qtn.MPS_computational_state("0000000000")`. Expected: bond dim 1, all-zero physical state, `H@psi=1`. WL-portable: Yes.
3. **Neel state MPS.** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: L=20. API: `qtn.MPS_neel_state(20)`. Expected: `<Z_i> = (-1)^i`. WL-portable: Yes.
4. **Random PBC MPS.** Source: `docs/tensor/tensor-optimization.ipynb`. Inputs: L=64, D=16, cyclic=True. API: `qtn.MPS_rand_state(64, 16, cyclic=True)`. Expected: 64 tensors with PBC. WL-portable: Yes.
5. **Custom MPS from raw arrays.** Source: `docs/tensor/tensor-design.ipynb`. Inputs: list of arrays of shape (7,2),(7,7,2),(7,7,2),(7,2). API: `qtn.MatrixProductState(arrays, site_ind_id="b{}")`. Expected: L=4, OBC, site_ind_id "b{}". WL-portable: Yes.
6. **MPS from dense vector.** Source: `docs/examples/ex_tensorflow_optimize_pbc_mps.ipynb`, `tests/test_tensor/test_circuit.py:641`. Inputs: dense ket of size 2^n. API: `qtn.MatrixProductState.from_dense(ket, [2]*n)`. Expected: MPS bond dim ≤ 2^(n/2). WL-portable: Yes.
7. **Dense1D wrapper.** Source: `docs/examples/ex_tensorflow_optimize_pbc_mps.ipynb`. Inputs: groundstate(L=16 PBC heisenberg). API: `qtn.Dense1D(gs)`. Expected: 1-tensor TN with 16 phys inds. WL-portable: Yes.
8. **MPS that doubles bond dim under +.** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: random MPS p with bond 50, compute (p+p)/2. API: `(p + p) / 2`. Expected: bond dim 100, norm still 1. WL-portable: Yes.
9. **Two-site repeating-tensor MPS unit cell (A,B).** Source: `docs/tensor/tensor-optimization.ipynb`. Inputs: L=64, two distinct random tensors. API: tag every other site "A"/"B"; `psi.equalize_norms_()`. Expected: 1024 free params instead of 32768. WL-portable: Yes.
10. **MPS from product state via `TN_from_sites_product_state`.** Source: `docs/examples/ex_real_time_simple_update.ipynb`. Inputs: site→[1,0] map for 121 sites. API: `qtn.TN_from_sites_product_state({...})`. Expected: 121-tensor product state. WL-portable: Yes.
11. **Random MERA.** Source: `docs/examples/ex_MERA.ipynb`. Inputs: n=128 (power of 2). API: `qtn.MERA.rand_invar(128)`. Expected: 128 phys inds, isos+unis layered, normalized. WL-portable: Partial.

## MPS algebra

1. **Left-canonicalize MPS.** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: random MPS L=20 D=50. API: `p.left_canonize()`. Expected: bond growth 2,4,8,16,32,50,...; `p.H @ p ≈ 1.0`. WL-portable: Yes.
2. **Compress with orthogonality center.** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: doubled MPS bond=100. API: `p2.compress(form=10)`. Expected: bonds reduce back to 50 from both ends towards site 10. WL-portable: Yes.
3. **MPS site tensor norm at orthogonality center.** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: canonicalized MPS. API: `p2[10].H @ p2[10]`. Expected: ≈ 1.0 (full state norm). WL-portable: Yes.
4. **Inner product for normalized MPS.** Source: `docs/tensor/tensor-1d.ipynb`, `tests/test_tensor/test_tensor_core.py:1453`. Inputs: random MPS L=10 D=7. API: `psi.H @ psi`. Expected: ≈ 1.0. WL-portable: Yes.
5. **Z-magnetization on Neel state.** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: `MPS_neel_state(20)`. API: `[psi0.gate(Z, i).H @ psi0 for i in range(10)]`. Expected: `[1, -1, 1, -1, 1, -1, 1, -1, 1, -1]`. WL-portable: Yes.
6. **Schmidt entropy at a bond.** Source: `tests/test_tensor/test_tensor_core.py:667-687`. Inputs: random MPS L=5 D=32. API: `p.entropy(bond)` matches dense `qu.entropy(p_dense.ptr([2]*5,[0,1,2]))`. WL-portable: Yes.
7. **Schmidt gap.** Source: `docs/examples/ex_TEBD_evo.ipynb`. API: `psit.schmidt_gap(j)`. Expected: scalar in [0,1]. WL-portable: Yes.
8. **Block-canonicalize between two sites.** Source: `tests/test_tensor/test_tensor_core.py:1464-1477`. Inputs: random MPS L=4 D=3. API: `k.canonize_between("I1","I2")`. Expected: `t.H @ t == 3` for the donor tensor. WL-portable: Yes.
9. **Compress all bonds to max_bond.** Source: `tests/test_tensor/test_tensor_core.py:1444-1453`. Inputs: random MPS doubled (k+k)/2. API: `k.compress_all_(max_bond=7, method=method)`. Expected: max_bond=7, `H@k ≈ 1`. WL-portable: Yes.
10. **`.show()` ASCII bond plot.** Source: `docs/tensor/tensor-1d.ipynb`. API: `p.show()`. Output: ASCII MPS schematic with bond sizes. WL-portable: qualitative.
11. **Correlation function.** Source: `docs/examples/ex_dmrg_periodic.ipynb`. Inputs: DMRG groundstate of 300-site PBC Heisenberg, sz operators. API: `gs.correlation(sz, 0, 1)`. Expected: ≈ -0.1565. WL-portable: Yes.
12. **`align_` indices on three MPS for energy overlap.** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: random MPS L=20 + random MPO. API: `p.align_(A, pH); (pH & A & p) ^ ...`. Expected: scalar (≈ 4.96e-7 for random hermitian MPO). WL-portable: Yes.

## MPO

1. **Random hermitian MPO.** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: L=20, bond_dim=7. API: `qtn.MPO_rand_herm(20, bond_dim=7, tags=["HAM"])`. Expected: 20-tensor MPO with upper/lower phys inds. WL-portable: Yes.
2. **Heisenberg MPO Hamiltonian (OBC).** Source: `docs/tensor/tensor-1d.ipynb`, `docs/examples/ex_TEBD_evo.ipynb`. API: `qtn.MPO_ham_heis(L)`. Expected: standard L-site spin-1/2 Heisenberg, MPO bond dim 5. WL-portable: Yes.
3. **Heisenberg MPO PBC.** Source: `docs/examples/ex_dmrg_periodic.ipynb`. Inputs: L=300. API: `MPO_ham_heis(300, cyclic=True)`. Expected: L=300 cyclic MPO; `heisenberg_energy(300) ≈ -132.947`. WL-portable: Yes.
4. **SpinHam1D builder → MPO.** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: spin-1, terms 1/2(+,-), 1/2(-,+), 1(z,z), L=100. API: `builder.build_mpo(L=100)`. Expected: 100-tensor spin-1 Heisenberg MPO. WL-portable: Yes.
5. **MPO from circuit (direct contraction).** Source: `docs/examples/ex_circuit_to_mpo.ipynb`. Inputs: 1D random circuit depth 8, n=10. API: `circ.get_uni()`, contract per site, `view_as_(MatrixProductOperator,...)`, `compress(cutoff=1e-6)`. Expected: bond profile 4,16,64,128,125,128,64,16,4. WL-portable: Yes.
6. **MPO from circuit (ALS fitting).** Source: `docs/examples/ex_circuit_to_mpo.ipynb`. Inputs: same circuit. API: `qtn.tensor_network_1d_compress(tn_uni, max_bond=32, method="fit")`. Expected: MPO with max_bond=32 and frobenius distance error ~0.09. WL-portable: Partial (ALS is portable; the expected error 0.09 is data-dependent on RNG).
7. **MPO @ MPS expectation.** Source: `docs/examples/ex_TEBD_evo.ipynb`. Inputs: MPS at time t, MPO Heisenberg. API: `qtn.expec_TN_1D(psi.H, H, psi)`. Expected: conserved energy under Heisenberg evolution (8.75 → 8.749...). WL-portable: Yes.
8. **`MPO_rand` & compress_all_1d.** Source: `tests/test_tensor/test_tensor_core.py:1455-1462`. Inputs: L=10 D=7. API: `mpo.compress_all_1d(max_bond=4)`. Expected: max_bond=4, `mpo1.H @ mpo == mpo2.H @ mpo`. WL-portable: Yes.

## PEPS

1. **Random PEPS.** Source: `docs/tensor/tensor-2d.ipynb`. Inputs: Lx=Ly=5, D=3, seed=666. API: `qtn.PEPS.rand(5, 5, 3, seed=666)`. Expected: 25 tensors, max_bond=3, site_tag "I{},{}", site_ind "k{},{}". WL-portable: Yes.
2. **Exact PEPS norm contraction.** Source: `docs/tensor/tensor-2d.ipynb`. Inputs: 5×5 PEPS. API: `(peps.H & peps).contract(all, optimize="auto-hq")`. Expected: ≈ 0.5078 for that random seed. WL-portable: Yes.
3. **Boundary contraction approx norm.** Source: `docs/tensor/tensor-2d.ipynb`. Inputs: same. API: `norm.contract_boundary(max_bond=32)`. Expected: ≈ 0.507 (close to 0.5078 exact). WL-portable: Partial (DMRG-style boundary needed).
4. **Local 2-site expectation on PEPS.** Source: `docs/tensor/tensor-2d.ipynb`. Inputs: 5×5 PEPS, H2=ham_heis(2), coords (2,2)-(2,3). API: `peps.compute_local_expectation({(coo_a,coo_b):H2}, max_bond=64, normalized=True)`. Expected: ≈ 0.000487 for that PEPS. WL-portable: Partial.
5. **All-bonds expectation.** Source: `docs/tensor/tensor-2d.ipynb`. Inputs: same PEPS, H2 on all `gen_bond_coos()`. API: `peps.compute_local_expectation(terms, max_bond=64, normalized=True)`. Expected: ≈ 0.2675. WL-portable: Partial.
6. **2D Heisenberg LocalHam2D.** Source: `docs/tensor/tensor-2d.ipynb`. Inputs: Lx=Ly=4, H2=ham_heis(2). API: `qtn.LocalHam2D(4, 4, H2=H2)`. Expected: 24-edge dict of terms. WL-portable: Yes.
7. **Exact 4×4 Heisenberg ground energy/site.** Source: `docs/tensor/tensor-2d.ipynb`. API: `qu.groundenergy(qu.ham_heis_2D(4,4,sparse=True)) / 16`. Expected: -0.5743254415745597. WL-portable: Yes.
8. **Simple Update PEPS evolution.** Source: `docs/tensor/tensor-2d.ipynb`. Inputs: 4×4 D=4 random PEPS, H Heisenberg, taus 0.3,0.1,0.03,0.01 each 100 steps, chi=32. API: `qtn.SimpleUpdate(psi0,ham,chi=32,...).evolve(...)`. Expected: best energy/site ≈ -0.563. WL-portable: Partial.
9. **Full Update PEPS evolution.** Source: `docs/tensor/tensor-2d.ipynb`. Inputs: SU best state, taus 0.1,0.03,0.01 50 steps. API: `qtn.FullUpdate`. Expected: energy/site ≈ -0.5736. WL-portable: No (autodiff fitter).
10. **Operator builder → PEPS local terms.** Source: `docs/operator/operator-basics.ipynb`. Inputs: 4×5 spin-1/2 Heisenberg via SparseOperatorBuilder. API: `H.build_local_ham()` → SimpleUpdate. Expected: 100 SU iterations, energy ≈ -31.97 vs exact -32.014 (rel err ≈ 0.0014). WL-portable: Partial.
11. **Random TN3D.** Source: `docs/tensor/tensor-drawing.ipynb`. Inputs: Lx=Ly=Lz=4, D=2. API: `qtn.TN3D_rand(4,4,4, D=2)`. Expected: 64 tensors with cube layout. WL-portable: Yes.

## MERA

1. **Random invariant MERA.** Source: `docs/examples/ex_MERA.ipynb`. Inputs: n=128. API: `qtn.MERA.rand_invar(128)`. Expected: TN with `_ISO`/`_UNI`/`_LAYER{i}` tags. WL-portable: Partial.
2. **Causal-cone norm of one site.** Source: `docs/examples/ex_MERA.ipynb`. Inputs: random MERA n=128. API: `mera.select(80).H & mera.select(80) ^ all`. Expected: 0.9999999999999938. WL-portable: Yes.
3. **Two-site Pauli expectation `<X_i Z_j>`.** Source: `docs/examples/ex_MERA.ipynb`. Inputs: i=50, j=100, gates X & X (note both labelled "X" in the notebook). API: `mera.gate(X,i).gate(Z,j).select(...).& mera.H ^ all`. Expected: ≈ 0.1588. WL-portable: Yes.
4. **MERA 20-site reduced density matrix as LinearOperator.** Source: `docs/examples/ex_MERA.ipynb`. Inputs: subsystem range(20). API: `rho.aslinearoperator(left_ix, rght_ix, backend="torch")`. Expected: 1048576×1048576 LinearOperator. WL-portable: Partial.
5. **MERA Heisenberg energy via global autodiff (L=64,D=8).** Source: `docs/examples/ex_MERA.ipynb`. API: `qtn.TNOptimizer(...).optimize`. Expected: converge towards `heisenberg_energy(64)= -28.374`. WL-portable: No (requires torch+jax+cuda).

## contraction path

1. **Greedy contraction tree.** Source: `docs/tensor/tensor-contraction.ipynb`. Inputs: 4-tensor TN T0..T3. API: `tn.contraction_tree(optimize="greedy")`. Expected: log10[FLOPs]=3.19, log2[SIZE]=6.75. WL-portable: Partial.
2. **`auto-hq` preset.** Source: `docs/tensor/tensor-circuit.ipynb`. Inputs: 10-qubit shallow circuit. API: `circ.amplitude(...)` default optimize="auto-hq". Expected: contraction width ≈ 7. WL-portable: Partial.
3. **`cotengra.HyperOptimizer`.** Source: `docs/tensor/tensor-contraction.ipynb`. API: `ctg.ReusableHyperOptimizer(reconf_opts={}, minimize="combo", ...)`. Expected: improved path stats. WL-portable: No (requires cotengra).
4. **Path caching.** Source: `docs/examples/ex_tn_qaoa_energy_bayesopt.ipynb`. API: `ctg.ReusableHyperOptimizer`. Expected: subsequent calls reuse cached path. WL-portable: No.
5. **`contraction_width` & `contraction_cost`.** Source: `tests/test_tensor/test_tensor_core.py:1095-1101`. Inputs: chain of (8,8) tensors a,b,c with shared bonds. API: `tn.contraction_width()`, `tn.contraction_cost()`. Expected: width=6, cost=2*8^3=1024. WL-portable: Yes.
6. **Boundary contract from each side.** Source: `docs/tensor/tensor-2d.ipynb`. API: `contract_boundary_from_{bottom,left,top,right}(max_bond=…)`. Expected: scalars matching exact within bond-truncation error. WL-portable: Partial.
7. **`contract_around` for local environments.** Source: `docs/tensor/tensor-2d.ipynb`. API: `norm.contract_boundary_(max_bond=64, layer_tags=["KET","BRA"], around=((2,2),(2,3)))`. Expected: TN reduced to 15 tensors. WL-portable: Partial.
8. **`contract_compressed` with HyperCompressedOptimizer.** Source: `docs/examples/ex_htn_to_tn_2d.ipynb`. Inputs: 10×11 cyclic uniform classical-Ising-like HTN. API: `tn.contract_compressed(ctree, progbar=True)`. Expected: ≈ 3.93e-38 (data-dependent). WL-portable: No.
9. **HOTRG / CTMRG on PEPS-style TN.** Source: `docs/examples/ex_htn_to_tn_2d.ipynb`. API: `tn.contract_hotrg(max_bond=8)`, `tn.contract_ctmrg(max_bond=16)`. Expected: 3.93e-38 (matches compressed contraction). WL-portable: No.

## decomposition

1. **`tensor_split` SVD with truncation.** Source: `docs/tensor/tensor-basics.ipynb`. Inputs: shape (2,3,4,5,6), inds "abcde", left_inds=["a","c","d"]. API: `t.split(["a","c","d"], max_bond=10, cutoff=1e-6, cutoff_mode="rel", method="svd", info=info)`. Expected: error ≈ 10.49 in `info["error"]`. WL-portable: Yes.
2. **Singular values from a tensor.** Source: `tests/test_tensor/test_tensor_core.py:559-565`. Inputs: psim = (eye(2)*2^-1/2). API: `psim.singular_values("a", method="svd")`. Expected: [√0.5, √0.5]. WL-portable: Yes.
3. **`split` with absorb=None returns separate svals.** Source: `tests/test_tensor/test_tensor_core.py:584-617`. Inputs: shape (4,5,6,7), inds "abcd". API: `x.split(["a","c"], absorb=None)`. Expected: TN with 3 tensors, hyper-index for svals. WL-portable: Yes.
4. **Rank-revealing methods comparison.** Source: `tests/test_tensor/test_tensor_core.py:466-486`. Inputs: random shape (2,3,4,5,6). API: `a.split(linds, method=m)` for m in svd, svd:eig, isvd, svds. Expected: contracted result equals original. WL-portable: Yes (svd); Partial (isvd/svds).
5. **QR/LQ split.** Source: `tests/test_tensor/test_tensor_core.py:488-502`. Inputs: same. API: `a.split(linds, method="qr"|"lq")`. Expected: contracted equals original. WL-portable: Yes.
6. **Low-rank random SVD via `svd:rand`.** Source: `tests/test_tensor/test_tensor_core.py:504-536`. Inputs: shape (10,10,10,10) uniform. API: `t.split(["a","c"], method="svd:rand", max_bond=50, cutoff=0.0)`. Expected: norm error ≤ 0.3, isometric factor norm² = 50. WL-portable: Partial.
7. **Renormalization on truncation.** Source: `tests/test_tensor/test_tensor_core.py:619-658`. Inputs: 10×10 matrix x = U·diag(1..10)·U^†. API: `t.split("a", method="svd", cutoff=0.1, renorm=True, cutoff_mode="rsum2")`. Expected: bond size 6, frobenius norm² preserved at 385.0; or `cutoff_mode="rsum1"` preserves trace 55.0. WL-portable: Yes.
8. **`tensor_compress_bond` reducing two-tensor bond.** Source: `tests/test_tensor/test_tensor_core.py:1322-1334`. Inputs: tensor A(7,2,2), expanded to bond 3, B(3,2,7). API: `qtn.tensor_compress_bond(A, B, absorb="left")`. Expected: bond reduces to 4, contraction unchanged. WL-portable: Yes.
9. **`split` returning truncation error.** Source: `docs/tensor/tensor-basics.ipynb`. API: as above; check `info["error"] == t.distance(tn)`. WL-portable: Yes.
10. **`TNLinearOperator` SVD with `svds`.** Source: `docs/tensor/tensor-basics.ipynb`. Inputs: 4-tensor low-rank network. API: `tn_decomp = qtn.tensor_split(tnlo, ..., method="svds", max_bond=4)`. Expected: 1000×1000-bond → bond 4. WL-portable: No.
11. **`replace_with_svd` inside TN.** Source: `docs/examples/ex_dmrg_periodic.ipynb`. API: `qp.replace_section_with_svd(20, 300, eps=1e-6, ltags="L", rtags="R")`. Expected: TN reduced to 2 boundary SVD tensors. WL-portable: Partial.

## gauge

1. **Canonize bond between two random tensors.** Source: `docs/tensor/tensor-basics.ipynb`. Inputs: tensors A(4,4,4) "abc" and B(4,4,4,4) "cdef". API: `qtn.tensor_canonize_bond(ta, tb)`. Expected: A becomes isometric. WL-portable: Yes.
2. **Compress bond between two tensors with reduced factors.** Source: `docs/tensor/tensor-basics.ipynb`, `tests/test_tensor/test_tensor_core.py:1336-1417`. Inputs: tensors A(4,4,10) "abc" and B(10,4,4,4) "cdef". API: `qtn.tensor_compress_bond(ta, tb, max_bond=2, absorb="left")`. Expected: shared bond becomes 2. WL-portable: Yes.
3. **Insert gauge `G G^-1` into MPS.** Source: `tests/test_tensor/test_tensor_core.py:1565-1581`. Inputs: random unit-bond gauge U on bond (4,5). API: `kU.insert_gauge(U, 4, 5)`. Expected: tensors at sites 4-5 change but `H @ k == H @ kU`. WL-portable: Yes.
4. **`canonize_around_` propagation in tree TN.** Source: `tests/test_tensor/test_tensor_core.py:1479-1540`. Inputs: hand-built tree TN (C, L1, L2, R1, R2, U1, U2). API: `ttn.canonize_around_("C", max_distance=k)`. Expected: tensors within distance k become isometries (norm² = bond size). WL-portable: Yes.
5. **`balance_bonds` between two tensors.** Source: `tests/test_tensor/test_tensor_core.py:809-822`. Inputs: t1(3,4) t2(4,5) sharing "b". API: `qtn.tensor_balance_bond(t1, t2, smudge=1e-6)`. Expected: column norms of t1 vs t2 become equal; product unchanged. WL-portable: Yes.
6. **`gauge_all_simple_` for SU PEPS gauges.** Source: `docs/examples/ex_real_time_simple_update.ipynb`. API: `psi.gauge_all_simple_(gauges=gauges)`. Expected: dict of bond gauge vectors. WL-portable: Partial.
7. **PTensor isometrize via Cayley.** Source: `docs/tensor/tensor-optimization.ipynb`. Inputs: 10×10 identity initial params. API: `qtn.PTensor(fn=qtn.decomp.isometrize_cayley, params=eye(10), ...)`. Expected: keeps tensor unitary. WL-portable: Partial.

## circuit construction

1. **Empty Circuit.** Source: `docs/tensor/tensor-circuit.ipynb`. Inputs: N=10. API: `qtn.Circuit(10)`. Expected: 10-qubit |0...0> base state. WL-portable: Yes.
2. **Circuit.from_qsim_str.** Source: `tests/test_tensor/test_circuit.py:148-156`. Inputs: 18-qubit 3-regular graph QAOA qsim string. API: `qtn.Circuit.from_qsim_str(qsim)`. Expected: norm 1.0. WL-portable: Yes.
3. **Circuit.from_openqasm2_str.** Source: `tests/test_tensor/test_circuit.py:154-156`. Inputs: 4-qubit QFT qasm. API: `qtn.Circuit.from_openqasm2_str(qasm)`. Expected: norm 1.0. WL-portable: Yes.
4. **circ_qaoa.** Source: `docs/examples/ex_tn_qaoa_energy_bayesopt.ipynb`. Inputs: 3-regular graph N=54, p=4, random gammas/betas. API: `qtn.circ_qaoa(terms, p, gammas, betas)`. Expected: applies H, ZZ-exp, RX. WL-portable: Yes.
5. **circ_ansatz_1D_zigzag/brickwork/rand.** Source: `tests/test_tensor/test_circuit.py:842-874`. Inputs: n,depth=3, gate_opts contract=False. API: `qtn.circ_ansatz_1D_*`. Expected: count of CZ gates equals depth*num_pairs. WL-portable: Yes.
6. **GHZ via H + CNOT chain + multi-controlled X.** Source: `docs/tensor/tensor-circuit.ipynb`. Inputs: N=80, randomly permuted CNOT chain, multi-controlled X. API: `circ.apply_gate("H", q0)`, `circ.apply_gate("CNOT", a, b)`, `circ.apply_gate("X", target, controls=[...])`. Expected: samples 0...0 / 1...1. WL-portable: Yes.
7. **`apply_gate_raw`.** Source: `tests/test_tensor/test_circuit.py:648-656`. Inputs: random unitary U(4) acting on (0,1). API: `circ.apply_gate_raw(U, [0,1], tags="UCUSTOM")`. Expected: fidelity 1 vs U @ |k0>. WL-portable: Yes.
8. **Multi-controlled gates.** Source: `tests/test_tensor/test_circuit.py:658-682`. Inputs: 3-qubit "x with controls (0,1)". API: `circ.apply_gate("x", qubits=(2,), controls=(0,1))`. Expected: equals `qu.toffoli()`. Also `circ.apply_gate("swap", (1,2), controls=(0,)) == qu.fredkin()`. WL-portable: Yes.
9. **Circuit with gate_round tag.** Source: `docs/tensor/tensor-circuit.ipynb`. Inputs: 10 qubits, 9 round entangling layers (CX, RZ(1.234), CZ, RX(1.234)). API: `circ.apply_gate("CX", i, i+1, gate_round=r)`. Expected: 252 gates total; psi has tags ROUND_0..ROUND_9. WL-portable: Yes.
10. **GHZ-3 prepare.** Source: `tests/test_tensor/test_circuit.py:129-146`. Inputs: 3-qubit (H, H, CNOT(1,2), CNOT(0,2), H, H, H). API: `qc.apply_gates(gates)`. Expected: `qu.expec(qc.psi.to_dense(), qu.ghz_state(3)) ≈ 1`. WL-portable: Yes.
11. **CircuitMPS construction.** Source: `docs/tensor/tensor-circuit-mps.ipynb`. Inputs: long-range circuit gen_gates(N=64, depth=10, x=0.1). API: `qtn.CircuitMPS.from_gates(gates, max_bond=None, cutoff=1e-6)`. Expected: max bond ≈ 143, error ≈ 0.003. WL-portable: Yes.
12. **CircuitPermMPS lazy swap tracking.** Source: `docs/tensor/tensor-circuit-mps.ipynb`. Inputs: same circuit. API: `qtn.CircuitPermMPS.from_gates(...)`. Expected: max_bond ≈ 99, error ≈ 0.00175 (lower than MPS). WL-portable: Yes.
13. **Circuit ansatz_circuit (CZ-coupled U3).** Source: `docs/examples/ex_tn_train_circuit.ipynb`. Inputs: n=6, depth=9, gate2='CZ'. API: builds U3 layers + CZ with gate_round tags. Expected: 105 gates. WL-portable: Yes.

## gate application

1. **Lazy gate (`contract=False`).** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: 10-site computational state, H on each, CNOT pairs. API: `psi0.gate_(H, i, tags="H")`, `psi0.gate_(CNOT, (i,i+1))`. Expected: norm preserved, additional tensors visible in TN. WL-portable: Yes.
2. **Eager gate (`contract=True`).** Source: `docs/tensor/tensor-1d.ipynb`. API: `psi0.gate(CNOT, (1, n-2), contract=True)`. Expected: rank-6 tensor formed. WL-portable: Yes.
3. **Swap+split gate (preserves MPS form).** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: H on every site, then RZ phase 0.42, CNOT chains, one long-range CNOT(2,n-2). API: `psi0.gate_(g, q, contract="swap+split")`. Expected: MPS form retained, max_bond=4. WL-portable: Yes.
4. **'auto-split-gate' for diagonal 2-qubit gates.** Source: `tests/test_tensor/test_circuit.py:362-393`. Inputs: 3-qubit U3+CZ+iSWAP+CX. API: contract='auto-split-gate'. Expected: max_bond=2 (vs 4 for split-gate / swap-split-gate). WL-portable: Yes.
5. **Parametrized U3 gate.** Source: `docs/tensor/tensor-circuit.ipynb`. Inputs: Circuit(2), random params. API: `circ.u3(*params, q, parametrize=True)`. Expected: gate tensor stored as `PTensor`. WL-portable: Partial (PTensor needs custom support).
6. **Parametrized FSIM.** Source: `docs/tensor/tensor-circuit.ipynb`. API: `circ.apply_gate("FSIM", a, b, qa, qb, parametrize=True, contract=False)`. Expected: PTensor of shape (2,2,2,2). WL-portable: Partial.
7. **Apply controlled-X (CX) gate.** Source: `docs/tensor/tensor-1d.ipynb`. API: `circ.apply_gate("CX", i, i+1)`. Expected: standard CNOT matrix. WL-portable: Yes.
8. **Three-qubit gates (CCX, CSWAP, Toffoli, CCY, CCZ, Fredkin).** Source: `tests/test_tensor/test_circuit.py:350-360`. API: `circ.ccx(0,1,2)`, etc. Expected: norm preserved. WL-portable: Yes.
9. **Apply random unitary on MPS (50 sites, 250 gates).** Source: `docs/examples/ex_tn_rand_uni_gate_graphs.ipynb`. Inputs: L=50 D=4, OBC random uni(4) gates. API: `psi.gate_(U, where=[i,i+1], tags=t, propagate_tags="sites")`. Expected: norm = 1 within 1e-15. WL-portable: Yes.
10. **All gate methods (53 gates).** Source: `tests/test_tensor/test_circuit.py:240-308`. Inputs: 2-qubit MPS, all gate names from `g_nq_np` list. API: `getattr(circ, g)(*args)`. Expected: norm 1.0 after all applied; final state ≠ initial. WL-portable: Yes.
11. **SU4 = decomposition into 4 U3's + 3 CNOTs + 3 single-rotations.** Source: `tests/test_tensor/test_circuit.py:310-348`. Inputs: 15 random params. API: `circ.su4(*params, 0, 1)` vs explicit decomp via U3, CNOT, RZ, RY. Expected: fidelity 1.0. WL-portable: Yes.
12. **Apply MPO acting on PEPS via `gate_simple_`.** Source: `docs/examples/ex_tn_circuit_sample_explore.ipynb`. Inputs: PEPS on hexagonal 5×5, 990 gates. API: `peps.gate_simple_(gate.array, gate.qubits, gauges=gauges, max_bond=16, cutoff=1e-6)`. Expected: PEPS with bond 16, normalization ≈ 0.99997. WL-portable: Partial.

## expectation value

1. **`local_expectation` of ZZ on circuit.** Source: `docs/tensor/tensor-circuit.ipynb`. Inputs: 10-qubit shallow circuit. API: `circ.local_expectation(qu.pauli("Z") & qu.pauli("Z"), (4,5))`. Expected: -0.018188965 (deterministic given fixed RNG seed). WL-portable: Yes.
2. **`local_expectation` of multiple operators.** Source: `docs/tensor/tensor-circuit.ipynb`, `tests/test_tensor/test_circuit.py:559-568`. Inputs: list [XX,YY,ZZ]. API: `circ.local_expectation([XX,YY,ZZ], (4,5))`. Expected: tuple of three scalars. For Bell-state circuit (H+CNOT+Y): all three are -1. WL-portable: Yes.
3. **`partial_trace` of circuit qubits.** Source: `docs/tensor/tensor-circuit.ipynb`, `tests/test_tensor/test_circuit.py:454-464`. API: `circ.partial_trace((4,5))`. Expected: 4×4 hermitian density matrix; equals `qu.partial_trace(circ.to_dense(), [2]*L, keep=(i,i+1))`. WL-portable: Yes.
4. **Compute `<x|ψ>` amplitude.** Source: `docs/tensor/tensor-circuit.ipynb`, `tests/test_tensor/test_circuit.py:444-452`. API: `circ.amplitude("0101010101")`. Expected: complex scalar. For all bitstrings of L=5 random circuit, matches `circ.to_dense()[i, 0]`. WL-portable: Yes.
5. **`compute_marginal`.** Source: `docs/tensor/tensor-circuit.ipynb`. Inputs: circ.compute_marginal((1,2), fix={0:'1',3:'0',4:'1'}, dtype="complex128"). Expected: shape (2,2) probability tensor. WL-portable: Yes.
6. **DMRG2 ground-state energy of L=100 spin-1 Heisenberg.** Source: `docs/tensor/tensor-1d.ipynb`. API: `qtn.DMRG2(H, bond_dims=[10,20,100,100,200], cutoffs=1e-10).solve(tol=1e-6)`. Expected: energy ≈ -138.940086. WL-portable: Partial.
7. **DMRG2 PBC L=300 Heisenberg energy.** Source: `docs/examples/ex_dmrg_periodic.ipynb`. Inputs: cyclic=True. API: `dmrg.solve(max_sweeps=4, cutoffs=1e-6)`. Expected: energy ≈ -132.94082; rel error vs `heisenberg_energy(300)` ≈ 4.57e-5. WL-portable: Partial.
8. **`compute_local_expectation` on PEPS norm.** Source: `docs/tensor/tensor-2d.ipynb`. (Already in PEPS.) WL-portable: Partial.
9. **MPS `expec_TN_1D`.** Source: `docs/examples/ex_TEBD_evo.ipynb`. API: `qtn.expec_TN_1D(psi.H, H, psi)`. Expected: <psi|H|psi>; energy conserved during TEBD. WL-portable: Yes.
10. **`circ.simulate_counts(C)`.** Source: `tests/test_tensor/test_circuit.py:142-146`. Inputs: 3-qubit GHZ circuit, C=1024. API: `qc.simulate_counts(1024)`. Expected: counts only 000 and 111, sum=1024. WL-portable: Yes.
11. **`gs.entropy(50)` half-chain entropy of DMRG state.** Source: `paper/paper.md`. Inputs: 100-site Heisenberg DMRG ground state. API: `gs.entropy(50)`. Expected: ≈ 1.2030. WL-portable: Yes.

## sampling/measurement

1. **`circ.sample(C)`.** Source: `tests/test_tensor/test_circuit.py:466-487`. Inputs: 5-qubit random circuit depth 3, C=1024. API: `circ.sample(C, group_size=group_size, seed=42)`. Expected: chi-squared GoF (`power_divergence(f_obs, f_exp)[0] < 100`). WL-portable: Yes.
2. **`circ.sample_gate_by_gate(C)`.** Source: `tests/test_tensor/test_circuit.py:489-510`. Same setup as above. Expected: chi-square stat < 100. WL-portable: Yes.
3. **`circ.sample_chaotic`.** Source: `tests/test_tensor/test_circuit.py:512-542`. Inputs: 5-qubit, depth=2, marginal_qubits ∈ {3,4,5}. Expected: GoF improves with more marginal qubits. WL-portable: Yes.
4. **MPS sampling on prepared 6-qubit state.** Source: `tests/test_tensor/test_circuit.py:790-801`. Inputs: GHZ-like circuit (H+CX chain). API: `qtn.CircuitMPS(6).sample(10, seed=42)`. Expected: every sample in {"000010", "111101"}. WL-portable: Yes.
5. **`CircuitPermMPS.sample`.** Source: `tests/test_tensor/test_circuit.py:810-822`. Same expected output. WL-portable: Yes.
6. **`sample_bitstring_from_prob_ndarray`.** Source: `docs/tensor/tensor-circuit.ipynb`. API: `qtn.circuit.sample_bitstring_from_prob_ndarray(p / p.sum())`. Expected: bitstring drawn proportional to p. WL-portable: Yes.
7. **PEPS `sample_configuration_cluster`.** Source: `docs/examples/ex_tn_circuit_sample_explore.ipynb`. Inputs: PEPS, gauges, max_distance=0. API: `peps.sample_configuration_cluster(gauges, seed, max_distance=0)`. Expected: tuple (config, omega). WL-portable: No.
8. **Local cluster expectation on PEPS.** Source: `docs/examples/ex_tn_circuit_sample_explore.ipynb`. API: `peps.local_expectation_cluster(G=ZZ, where=tuple(...), gauges, max_distance=0)`. Expected: scalar (≈ 0.347 for one edge). WL-portable: Partial.

## optimization

1. **Global TNOptimizer for PBC MPS Heisenberg.** Source: `docs/tensor/tensor-optimization.ipynb`. Inputs: L=64 D=16 cyclic random MPS. API: `qtn.TNOptimizer(psi, loss_fn, norm_fn, loss_constants={"ham":ham}, optimizer="adam", autodiff_backend="jax")`. Expected: 32768 params; converge to ≈ -28.30 vs `heisenberg_energy(64)` analytic. WL-portable: No.
2. **Shared-tag (unit-cell) optimization.** Source: `docs/tensor/tensor-optimization.ipynb`. Inputs: same MPS but only A,B tagged tensors free, shared via shared_tags. API: `TNOptimizer(..., tags=["A","B"], shared_tags=["A","B"])`. Expected: 1024 params, energy ≈ -28.297. WL-portable: No.
3. **TNOptimizer for PEPS energy minimization.** Source: `docs/tensor/tensor-2d.ipynb`. Inputs: 4×4 D=4 PEPS. API: `loss_fn = compute_local_expectation(...)`, `TNOptimizer(..., autodiff_backend="jax")`. Expected: energy/site ≈ -0.5742 ≈ exact. WL-portable: No.
4. **Optimize Circuit (parametrize=True U3 gates).** Source: `docs/tensor/tensor-optimization.ipynb`. Inputs: 2-qubit (U3, U3, CNOT, U3, U3) circuit. API: `qtn.TNOptimizer(circ, loss, ..., autodiff_backend="autograd")`. Expected: energy → -3/4 (Heisenberg ground state on 2 qubits). WL-portable: No.
5. **PTensor + isometric Cayley parameterization.** Source: `docs/tensor/tensor-optimization.ipynb`. Inputs: 10×10 G non-symmetric matrix, two PTensors. API: `qtn.TNOptimizer({"Ua":Ua,"Ub":Ub}, loss, optimizer="newton-cg", autodiff_backend="jax")`. Expected: off-diagonal frobenius ≈ 1.7e-6. WL-portable: No.
6. **Tensor fitting via ALS.** Source: `docs/examples/ex_tn_tensor_fitting.ipynb`. Inputs: 10x10x10x10 uniform target normalized; ring of 4 rank-5 tensors. API: `tn.fit(t_target, method="als", steps=1000)`. Expected: distance ≈ 0.47, overlap ≈ 0.895. WL-portable: Yes.
7. **Tensor fitting via autodiff.** Source: `docs/examples/ex_tn_tensor_fitting.ipynb`. API: `tn.fit_(t_target, method="autodiff", steps=1000)`. Expected: similar distance. WL-portable: No.
8. **Train ansatz to match Ising propagator.** Source: `docs/examples/ex_tn_train_circuit.ipynb`. Inputs: n=6 depth=9 CZ ansatz, target U = expm(-i*2*ham_ising(n=6, jz=1, bx=0.7)). API: `qtn.TNOptimizer(...optimize_basinhopping(n=500, nhop=10))`. Expected: fidelity ≈ 99.57%. WL-portable: No.
9. **flax+optax JAX-jit MERA optimization.** Source: `docs/examples/ex_quimb_within_jax_flax_optax.ipynb`. Inputs: L=16 D=8 MERA, ham_1d_heis(16). API: optax.adabelief lr=0.01, 1000 steps. Expected: energy → -6.904. WL-portable: No.

## other (matrix/state ops, generators, evolution)

1. **`bell_state("psi-")`.** Source: `docs/matrix/matrix-basics.ipynb`. API: `qu.bell_state("psi-")`. Expected: 4-vector (0, 1/√2, -1/√2, 0). WL-portable: Yes.
2. **Pauli matrices `pauli("X"|"Y"|"Z")`.** Source: `docs/matrix/matrix-generate.md`. Expected: standard 2×2. WL-portable: Yes.
3. **Hadamard, T, S, controlled, CNOT, swap, iswap.** Source: `docs/matrix/matrix-generate.md`. Expected: standard quantum gate matrices. WL-portable: Yes.
4. **`ikron`: tensor-product with identities.** Source: `docs/matrix/matrix-basics.ipynb`. Inputs: dims=[2]*10, X, inds=[3,4]. API: `ikron(X, dims, inds=[3,4])`. Expected: 1024×1024 matrix = I ⊗ I ⊗ I ⊗ X ⊗ X ⊗ I^5. WL-portable: Yes.
5. **`pkron`: kron with permutation.** Source: `docs/matrix/matrix-basics.ipynb`. Inputs: dims=[2]^3, XZ = X⊗Z, inds=[2,0]. API: `pkron(XZ, dims, inds=[2,0])`. Expected: 8×8 matrix Z ⊗ I ⊗ X. WL-portable: Yes.
6. **`partial_trace` (`ptr`) of 10-qubit random ket on (0,9).** Source: `docs/matrix/matrix-basics.ipynb`. API: `ptr(psi, dims=[2]*10, [0,9])`. Expected: 4×4 ρ_AB ≈ I/4. WL-portable: Yes.
7. **`expec(psi, X)`, `expec(psi,psi)`.** Source: `docs/matrix/matrix-basics.ipynb`. API: `qu.expec(...)`. Expected: <ψ|X|ψ>; <ψ|ψ>=1.0. WL-portable: Yes.
8. **2D Heisenberg Hamiltonian.** Source: `docs/examples/ex_2d.ipynb`. Inputs: n=4, m=5, plus z-field on (1,2). API: `ham_heis_2D(4, 5, cyclic=False)`. Expected: ground energy ≈ -11.66. WL-portable: Yes.
9. **`MyTimeDepIsingHam` time-dependent Ising.** Source: `docs/matrix/matrix-dynamics and evolution.ipynb`. Inputs: L=16 Ising + cos(t)·field. API: `qu.Evolution(neel_state(L), fn_ham_t, progbar=True, compute={...})`. Expected: half-chain entropy generated, fidelity to initial ≈ 0.0033. WL-portable: Partial.
10. **Random Heisenberg quench.** Source: `docs/examples/ex_quench.ipynb`. Inputs: n=20 sparse Heisenberg + random product state. API: `qu.Evolution(psi0, H, compute={...}).update_to(5)`. Expected: energy preserved at 0.3002. WL-portable: Yes.
11. **TEBD on Heisenberg L=20.** Source: `docs/tensor/tensor-1d.ipynb`. Inputs: MPS_neel_state(20), `ham_1d_heis(20, bz=0.1)`, cutoff 1e-12. API: `qtn.TEBD(psi0, H).update_to(T=3, tol=1e-3)`. Expected: max-bond=34, error ≈ 4.89e-8 from norm conservation. WL-portable: Partial.
12. **TEBD long-time L=44.** Source: `docs/examples/ex_TEBD_evo.ipynb`. Inputs: bitstring with two flipped spins. API: `qtn.TEBD(psi0, ham_1d_heis(44)).at_times(np.linspace(0,80,101), tol=1e-3)`. Expected: ballistic propagation; trotter error < 1e-3; energy conserved 8.75 → 8.749999702. WL-portable: Partial.
13. **TEBD MBL Hamiltonian.** Source: `docs/examples/ex_TEBD_evo.ipynb`. Inputs: SpinHam1D + per-site random Z field, seed=2. API: `builder.build_local_ham(L)` then TEBD. Expected: confined dynamics. WL-portable: Partial.
14. **Approximate spectral function for Tr(f(A)).** Source: `docs/matrix/matrix-calculating quantities.ipynb`. Inputs: 2D Heisenberg 4x4 with bz=1.7. API: `qu.approx_spectral_function(H, f=lambda x:exp(-beta*x), tol=1e-2, info=info, plot=True)`. Expected: estimate of partition function Z. WL-portable: Partial.
15. **`tr_sqrt_approx` for ρ.** Source: `docs/matrix/matrix-calculating quantities.ipynb`. Inputs: rand_rho(2^12). API: `qu.tr_sqrt_approx(rho)`. Expected: ≈ Σ √λ_i (tested ≈ 54.46 vs 54.32). WL-portable: Partial.
16. **`logneg_subsys_approx` for 20-qubit ket.** Source: `docs/matrix/matrix-calculating quantities.ipynb`. Inputs: rand_ket(2^20), dims=[2^8,2^4,2^8]. API: `qu.logneg_subsys_approx(psi, dims, sysa=0, sysb=2)`. Expected: ≈ 5.74. WL-portable: Partial.
17. **MERA partition into reduced ρ + log-neg.** Source: `docs/examples/ex_MERA.ipynb`. Inputs: 20-site sub-region of 128-site MERA. API: `rho.aslinearoperator(left_ix, rght_ix, backend="torch")` then `qu.approx_spectral_function(rho_lo, abs)` and `log2`. Expected: log-neg ≈ 1.55. WL-portable: No.
18. **`bound_spectrum(H)`.** Source: `docs/examples/ex_quench.ipynb`. Inputs: H = ham_heis(20, sparse=True). API: `qu.bound_spectrum(H)`. Expected: (-8.682, 4.75) for n=20. WL-portable: Yes.
19. **`zspin_projector` lazy operator.** Source: `docs/examples/ex_distributed_shift_invert.ipynb`. Inputs: n=18 spin-1/2, half-filled. API: `qu.zspin_projector(n=18)`. Expected: 2^18 × C(18,9)=48620 projector. WL-portable: Yes.
20. **MBL Hamiltonian via `ham_mbl`.** Source: `docs/examples/ex_distributed_shift_invert.ipynb`. Inputs: n=18, dh=3.0, sparse=True, seed=9. API: `qu.ham_mbl(n=18, dh=3.0, sparse=True, seed=9)`. Expected: sparse 2^18 × 2^18 hermitian. WL-portable: Yes.
21. **TRG free energy of 2D Ising at critical β.** Source: `docs/examples/ex_tn_TRG.ipynb`. Inputs: β=log(1+√2)/2, χ=64, 16 iterations (lattice 2^16 × 2^16). API: custom TRG via `qtn.tensor_builder.classical_ising_T_matrix` and `Tensor.split`. Expected: f ≈ -2.10965, rel error ≈ 7e-8 vs Onsager exact. WL-portable: Partial.
22. **2D Heisenberg PEPS with U1 symmetry sector + DMRG2.** Source: `docs/operator/operator-basics.ipynb`. Inputs: 4×5 lattice, U1 symmetry, half-filled sector. API: `qop.HilbertSpace`, `qop.SparseOperatorBuilder`, `H.build_sparse_matrix()`, `qu.eigh(H_sparse, k=1)`. Expected: groundstate energy ≈ -32.014. Then `H.build_mpo()`, `qtn.DMRG2(H_mpo).solve(verbosity=1)` → energy -31.8195 (rel err 0.006). WL-portable: Partial.
23. **Fermi-Hubbard + Jordan-Wigner.** Source: `docs/operator/operator-basics.ipynb`. Inputs: 4×3 spinful (24 sites), t=1, U=8, half-filling. API: `H.jordan_wigner_transform(); H.build_sparse_matrix(); qu.eigh(...)`. Expected: energy/(Lx*Ly) ≈ -0.4094. WL-portable: Partial.

## Notes on validation testing

- DMRG/TEBD/SU/FU/TRG numerics are deterministic given matched RNG seeds (where shown). For random-seed-dependent values (e.g., random PEPS contraction = 0.5078), parity is checked by running the *same* RNG seed on both sides — quimb honors `seed=` kwargs in `MPS_rand_state`, `PEPS.rand`, `MERA.rand`, `rand_tensor`, `rand_ket`, `rand_uni`, `rand_herm`, etc.
- For Heisenberg-energy comparisons, both sides should call `qu.heisenberg_energy(L)` (analytic Bethe ansatz) or compute via `qu.groundenergy(qu.ham_heis(L, ...))` independently.
- Boundary contraction tolerances (`max_bond`, `cutoff`) introduce systematic offsets; treat these as soft equality (within ~1e-3 for max_bond=64).
- All "WL-portable: No" entries depend on autodiff (jax/torch/autograd) infrastructure that has no direct WL analog; either skip or compare only the loss surface qualitatively.
- The canonical small numerical checks for parity (recommended priority list): GHZ-3 (entry circuit-construction #10), QFT unitary check (`tests/test_tensor/test_circuit.py:575-593`), 2-qubit Heisenberg ground = -3/4 (optimization #4), pkron/ikron simple cases, Bell state expectation (matrix-basics), `partial_trace` on 10-qubit random state, exact 4×4 Heisenberg ground -0.5743 (PEPS #7), correlation/entropy of canonical MPS (test_tensor_core #667-687), and Onsager TRG (other #21).
