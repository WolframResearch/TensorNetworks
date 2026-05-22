# Cotengra Validation-Test Catalog

Source: `tn-external/numerical/cotengra/`. Direct competitor for our `OptimalContractionPath` / Netcon — most entries are FLOP/size cost comparisons.

## Summary

**Total examples cataloged: 67**

Counts per category:
- benchmark network: 14
- contraction tree construction: 9
- path finding: 11 (greedy 4, DP/optimal 2, hyperoptimizer 3, random 1, KaHyPar 1, labels/edgesort 2)
- cost model: 6
- slicing: 7
- simulated annealing: 2
- subtree reconfiguration / dynamic slicing: 6
- contraction execution: 8
- compressed contraction: 5
- parallel evaluation: 4
- plotting: 5

WL portability summary: Yes 28, Partial 23, No 16. (No = requires KaHyPar / cmaes / optuna / quimb / cupy / mpi4py / cotengrust internal optimizers we do not reproduce.)

## 1. Benchmark Networks (canonical TN topologies)

Each is a network description that should be reproducible verbatim in the WL paclet for cost-validation tests. The first 8 are stored as ready-to-load JSON in `examples/benchmarks/`.

1. **cubic_6x6x10** — 3D cubic lattice 6×6×10
   - Source: `examples/benchmarks/cubic_6x6x10.json`
   - Inputs: 360 tensors, 924 indices, all bond dim 2, output empty (closed network).
   - API: `ctg.utils.load_from_json(...)`; intended target for `HyperOptimizer`.
   - WL-portable: Yes.

2. **mps_mpo_L100_chi64_D5** — MPS-MPO sandwich, length 100, χ=64, physical dim 5
   - Source: `examples/benchmarks/mps_mpo_L100_chi64_D5.json`
   - Inputs: 200 tensors, 298 indices; size hist {64×188, 2×102, 4×2, 8×2, 16×2, 32×2}; output empty.
   - WL-portable: Yes.

3. **peps_cluster_r2_D10_a** — PEPS cluster radius-2, bond dim 10
   - Source: `examples/benchmarks/peps_cluster_r2_D10_a.json`
   - Inputs: 32 tensors, 74 indices; sizes {10×58, 2×16}; output empty.
   - WL-portable: Yes.

4. **qucirc_rrzz_n56_d13** — Random-rotation+ZZ quantum circuit, 56 qubits depth 13
   - Source: `examples/benchmarks/qucirc_rrzz_n56_d13.json`
   - Inputs: 924 tensors, 616 indices, all bond 2; output empty (amplitude).
   - WL-portable: Partial (large; pairwise-only safe for Netcon C++).

5. **rand_50_5_a** — Random regular-ish equation, 50 inputs, ~5 indices each
   - Source: `examples/benchmarks/rand_50_5_a.json`
   - Inputs: 50 tensors, 125 indices; sizes mixed {2,3,4,5}; output rank 4 — **only benchmark with non-empty output**.
   - WL-portable: Yes.

6. **randreg_200_3_a** — Random 3-regular graph, 200 nodes
   - Source: `examples/benchmarks/randreg_200_3_a.json`
   - 200 tensors, 300 indices, sizes {2,3}; output empty.
   - WL-portable: Yes.

7. **rtree_100_a** — Random tree, 100 tensors
   - Source: `examples/benchmarks/rtree_100_a.json`
   - 100 tensors, 99 indices, all bond 10 (no cycles → trivial optimum).
   - WL-portable: Yes.

8. **sycamore_n53_m20_s0_e0_pABCDCDAB** — Google Sycamore depth-20 amplitude
   - Source: `examples/benchmarks/sycamore_n53_m20_s0_e0_pABCDCDAB.json`
   - 381 tensors, 754 indices, all bond 2; output empty.
   - Expected: with HyperOptimizer + slicing reconf to W=29 → cost ≈ 5.33×10^18 (matches Huang et al. 2002.01935 reported 6.66×10^18).
   - WL-portable: Partial — geometry portable, but high-quality KaHyPar+slicing path search not.

9. **Square lattice [10,10]** (also generated programmatically via `ctg.utils.lattice_equation([10,10])`)
   - Source: `docs/contraction.ipynb`
   - 100 tensors, square-grid, default bond dims.
   - Expected with `HyperOptimizer(minimize='combo')`: log2[SIZE]=10, log10[FLOPs]=5.28; sliced ([target_slices=32]): log2[SIZE]=8, log10[FLOPs]=5.91, 32 slices, 5 sliced indices.
   - WL-portable: Yes.

10. **Square lattice [4,5]** (small test fixture)
    - Source: `docs/high-level-interface.ipynb`, `tests/test_paths_basic.py:194-205`
    - 20 tensors, equation `ab,cbd,edf,gfh,...`.
    - Default `tree.contract_stats()` → `{'flops': 964, 'write': 293, 'size': 32}`.
    - With `optimize_optimal(minimize='flops')` → cost = **1464** (with d_max=3, seed=42); with `minimize='size'` → width = **5.584962500721156** (i.e. log2 size).
    - WL-portable: Yes — exact integer numbers to compare.

11. **Square lattice [100,100]**
    - Source: `docs/advanced.ipynb`
    - 10000 tensors. With `RandomGreedyOptimizer(max_repeats=32, temperature=(0.01,0.1), seed=42)` → `best_flops` ≈ 65.02 (log10).
    - WL-portable: Partial — large, only random-greedy needed.

12. **Square lattice variants** [3,3], [4,4], [5,5], [5,6], [6,6], [4,8], [8,8], [16,16], [24,30], [5,5,5]
    - Sources: scattered across `docs/visualization.ipynb`, `tests/test_compressed.py`, `tests/test_compute.py`, `tests/test_tree.py`.
    - All via `ctg.utils.lattice_equation(...)`; default bond dim 2 (or `d_max=2/3`).
    - WL-portable: Yes.

13. **Random-regular contraction** `rand_reg_contract(20, 5, seed=42)` (from `tests/test_optimizers.py:26-46`)
    - 20 nodes, degree-5 random regular graph; one tensor per node; shapes (2,2,2,2,2); all bond dim 2; closed network.
    - Each test method (greedy / kahypar / labels / spinglass / labelprop / walktrap / betweenness) must yield `tree.speedup() > 1`.
    - WL-portable: Yes.

14. **`ctg.utils.rand_equation(n, reg, n_out, n_hyper_in, n_hyper_out, d_min, d_max, seed)`** — canonical random-hypergraph generator
    - Used in: `tests/test_paths_basic.py:113-139`, `tests/test_compute.py:127-186`, `tests/test_tree.py:91`, `tests/test_optimizers.py:594-707`, `docs/trees.ipynb`, `examples/ex_jax.py` (n=140, reg=3, n_out=2, seed=666), `examples/ex_mpi_*.py` (n=100, reg=3).
    - Reference fixture: `n=10, reg=3, n_out=2, n_hyper_in=1, n_hyper_out=1, d_min=2, d_max=3` produces (after eq formatting) something like `dn,bhl,afj,cejk,cdefglmno,gh,i,k,im,o->ba`.
    - For `rand_equation(n=50, reg=5, seed=0, d_max=2)`: greedy tree → cost 5.72×10^11, width 27; after slicing target_size=2^20: cost 6.56×10^11 width 20; slicing overhead ≈ 1.147.
    - WL-portable: Yes (graph generator is straightforward; networkx-style random regular).

## 2. Path Finding

### 2a. Greedy

15. **Basic greedy on small fixed eq** — `tests/test_paths_basic.py:97-110` (`test_manual_cases`)
    - 95 hand-curated equations from the `test_case_eqs` list (lines 8-94): includes `"abc,bac"`, `"ea,fb,gc,hd,abcd->efgh"`, GEMM patterns, hadamard products, outer products, and "previously failed" cases.
    - For each: `pb.optimize_greedy(inputs, output, size_dict)` → path; `tree.contract(arrays)` must equal `np.einsum(eq, *arrays, optimize=True)` to allclose.
    - WL-portable: Yes — every eq replicable.

16. **Greedy on random hypergraph** — `tests/test_paths_basic.py:113-139` (`test_basic_rand`)
    - `rand_equation(10, 4, n_out=2, n_hyper_in=1, n_hyper_out=1, d_min=2, d_max=3, seed=0..9)`.
    - Same correctness check vs numpy einsum.
    - WL-portable: Yes.

17. **`GreedyOptimizer` / `RandomGreedyOptimizer`** — top-level API
    - `cotengra.GreedyOptimizer`, `cotengra.OptimalOptimizer` — added in v0.6.0.
    - `RandomGreedyOptimizer(max_repeats, temperature, seed, accel, parallel)` — `tests/test_paths_basic.py:142-172`.
    - Test invariant: `tree.contraction_cost(log=10) == opt.best_flops` (consistency check, the tree's log10-cost equals the opt's tracked log10 flops). Deterministic for fixed seed: same `best_ssa_path` and `best_flops` across runs.
    - On `lattice_equation([4,5], d_min=2, d_max=3, seed)` with `max_repeats=2, temperature=0.1`.
    - WL-portable: Partial — port the random-greedy algorithm; rust accel not needed.

18. **`optimize_random_greedy_track_flops`** — drives `RandomGreedyOptimizer`. Releases GIL, threaded by default when cotengrust installed. WL-portable: Partial.

### 2b. DP / optimal

19. **`OptimalOptimizer` on lattice [4,5]** — `tests/test_paths_basic.py:194-205` (`test_optimal_lattice_eq`)
    - `pb.optimize_optimal(inputs, output, size_dict, minimize='flops')` → tree.contraction_cost() **== 1464** (exact).
    - With `minimize='size'` → `tree.contraction_width() == 5.584962500721156` (i.e. log2(48)).
    - WL-portable: **Yes** — these are perfect validation-test numbers.

20. **`pb.optimize_optimal` on every test_case_eq** — same `test_manual_cases` parametrized with `which='optimal'`. Result: every contracted answer matches `np.einsum(..., optimize=True)`.
    - WL-portable: Yes.

### 2c. HyperOptimizer (Bayesian/CMA-ES sampling of greedy/kahypar trials)

21. **`HyperOptimizer.search` on small 4-tensor demo** — `docs/basics.ipynb`
    - inputs `[("a","b","x"),("b","c","d"),("c","e","y"),("e","a","d")]`, output `("x","y")`, `size_dict={"x":2,"y":3,"a":4,"b":5,"c":6,"d":7,"e":8}`.
    - After search → `tree.contraction_width() ≈ 8.392` (log2 size), `tree.contraction_cost() == 4656`.
    - Contract result: 2×3 array of 6720s.
    - Path returned: `((0,1),(1,2),(0,1))`.
    - WL-portable: **Yes** — exact integer cost 4656 perfectly comparable.

22. **HyperOptimizer with `minimize="combo"`, `reconf_opts={}`, slicing_reconf_opts** on Sycamore m=20
    - `docs/examples/ex_benchmarking.ipynb`
    - `methods=["greedy","kahypar"]` → cost ≈ 10^18.27.
    - `simulated_annealing_opts={}` + `reconf_opts={"subtree_size":6}` → cost ≈ 10^18.04.
    - WL-portable: No (requires KaHyPar; SA portable separately).

23. **HyperOptimizer config matrix** — `tests/test_optimizers.py:139-167`
    - Tested optlibs: `nevergrad, skopt, cmaes, optuna, sses, neldermead, sbplx`. All must yield `tree.speedup() > 1` on `rand_reg_contract(20,5,seed=42)`.
    - WL-portable: Partial — the optimizer interface is portable but the underlying Bayesian libs are not standard in WL.

### 2d. Random / labels / KaHyPar / edgesort

24. **`RandomOptimizer` (`optimize="random"`)** — `tests/test_paths_basic.py:208-219` (`test_random_optimize`)
    - On lattice [4,5], `array_contract_tree(... optimize="random")` returns complete tree.
    - WL-portable: Yes.

25. **`edgesort` / `ncon` optimizer** (`optimize="edgesort"`) — `tests/test_paths_basic.py:221-243`
    - Edge-ordered contraction: the order of indices entirely determines the path.
    - Manual labelling test: `inputs=[(3,2),(2,1),(1,0)], size_dict={0:2,1:2,2:2,3:2}, optimize="edgesort"` → path == `((1,2),(0,1))`.
    - WL-portable: **Yes** — exact path match. Useful low-overhead validation probe.

26. **`labels` / `labelprop` / `spinglass` / `betweenness` / `walktrap` partition methods** — `tests/test_optimizers.py:56-67, 86-98`
    - Hypergraph community-detection drivers; on `rand_reg_contract(20,5)` each must give speedup > 1.
    - WL-portable: Partial (igraph would need re-implementing); `labels` is pure python and portable.

27. **`kahypar` / `kahypar-agglom`** — `tests/test_optimizers.py:56-67`
    - Karlsruhe Hypergraph Partitioning. Highest-quality default driver.
    - WL-portable: **No** — wraps a C++ partitioner.

### 2e. Labels-tree builder

28. **`path_labels.labels_to_tree.trial_fn` / `trial_fn_agglom`** on lattice [4,4] — `tests/test_tree.py:456-473`
    - Both produce a complete contraction tree.
    - WL-portable: Yes — it's a pure python community-detection algorithm.

## 3. Cost Model

### 3a. FLOPs

29. **`tree.contraction_cost()`** — number of scalar multiplications.
    - `docs/basics.ipynb`: 4-tensor demo → 4656.
    - `tests/test_paths_basic.py:201`: lattice [4,5] d_max=3 seed=42 optimal → **1464**.
    - WL-portable: Yes.

30. **`tree.total_flops()` / `tree.total_flops('complex')`** — generic ops, real, or complex.
    - `cotengra` ops = real flops / 2 = complex flops / 4 (per `docs/contraction.ipynb` "Differences with opt_einsum").
    - WL-portable: Yes (just track integer add/mul counts).

31. **`tree.contract_stats()`** — `{'flops','write','size'}`.
    - lattice [4,5] default → `{'flops':964,'write':293,'size':32}` (`docs/high-level-interface.ipynb`).
    - WL-portable: Yes.

### 3b. Size / width

32. **`tree.contraction_width()`** = log2 of largest intermediate. demo example → 8.39231742277876, 4-tensor demo → 4656 cost.
    - `tests/test_paths_basic.py:205`: lattice[4,5] d_max=3 optimal min size → **5.584962500721156**.
    - WL-portable: Yes.

33. **`tree.max_size()`, `tree.peak_size()`, `tree.get_peak_size(node)`, `tree.reorder_for_peak_size()`** — added in v0.8.0
    - `tests/test_tree.py:476-487`: `rand_tree(30,3,seed)`, `pa = tree.peak_size()`; reorder → `pd <= pc, pd <= pb`.
    - WL-portable: Yes.

### 3c. Write / combo

34. **`tree.total_write()`** — sum of intermediate sizes.
    - WL-portable: Yes.

35. **`combo_cost` / `minimize='combo'` and `'combo-{alpha}'`** — α default 64; tree.combo_cost() = flops + α·write.
    - `docs/advanced.ipynb`: cited as "decent baseline performance for typical CPUs and GPUs".
    - `tree.total_cost()` aliases `tree.combo_cost()` (v0.6.1).
    - WL-portable: Yes.

### 3d. Compressed objectives

36. **`minimize="combo-compressed"`, `tree.total_flops(chi)`, `tree.total_write(chi)`, `tree.peak_size(chi)`, `tree.contraction_width(chi)`** — for compressed contraction with bond cap χ.
    - `tests/test_compressed.py:6-91`, `docs/examples/ex_compressed_contraction.ipynb` (3D Ising, 10×10×10, χ=16).
    - Invariants: `flops(chi) < flops_exact()`, etc.; on lattice[10,10] at χ=4: `contraction_width(chi) < 20`.
    - WL-portable: Partial.

## 4. Slicing

37. **Basic slicing** — `tree.slice(target_size=2**N)` or `slicing_opts={"target_size":...}` / `{"target_slices":...}`
    - `docs/trees.ipynb`: `rand_equation(50, 5, seed=0, d_max=2)` greedy tree (cost 5.72e11, width 27); `tree.slice(target_size=2**20)` → 10 sliced inds, 1024 slices, cost 6.56e11, width 20, overhead ≈ 1.147.
    - WL-portable: Yes (greedy slice-finder is portable).

38. **`SliceFinder(tree, target_size, target_overhead)`** — `tests/test_slicer.py:6-13`
    - On `rand_tree(30,5,seed=42,d_max=3)`: `target_size=100_000` → returns inds, cost; `tree.max_size() > 500_000`, sliced `ccost.size <= 100_000`, `ccost.total_flops > original`, `len(inds) > 1`.
    - WL-portable: Yes.

39. **`SliceFinder.search(temperature=...)`** with multi-temperature pass — `examples/Quantum Circuit Example Old.ipynb`
    - Sycamore m=12, `target_size=2**28` → temperatures 1.0, 0.1, 0.01.
    - WL-portable: Yes.

40. **Dynamic slicing** — `slicing_reconf_opts={"target_size":2**N}` / `tree.slice_and_reconfigure(target_size, progbar=True)`
    - `docs/trees.ipynb`: `lattice_equation([24,30], d_max=2)` greedy tree → reconfigure speedup 1253×; forest reconfigure → 4312×; `slice_and_reconfigure(target_size=2**28)` from a reconfigured tree → 1.66× cost-vs-naive-slicing improvement; double-forested → 10.67×.
    - Sycamore reproduction (Huang et al. 2005.06787, target W=29): cost 5.33e18, 24 sliced inds. (Pan & Zhang 2103.03074, W=30, 21-qubit marginal): cost 4.60e18, 23 sliced inds.
    - WL-portable: Partial (reconfigure is portable; the hyperopt loop around it less so).

41. **`tree.remove_ind` / `tree.remove_ind_` / `tree.restore_ind` / `tree.unslice_rand_` / `tree.unslice_all_` / `tree.reslice`** — `tests/test_tree.py:287-386`
    - On hyper random eq seed=42, after slicing: `flops_sliced > flops_orig`; `project=0..d-1` summed → equals unsliced.
    - **`reslice=True`** with `slice_and_reconfigure_(target_size=W//10)` → final size <= target.
    - WL-portable: Yes (slicing identities are exact arithmetic).

42. **Slicing preprocessed indices** — `tests/test_tree.py:398-431`
    - `eq = "abc,bde,dfg,fah->"` (4-tensor cycle of triangles); 4 preprocessing steps initially. Slicing preprocessed ind 'c' drops preprocessing to 3; restoring 'c' raises back to 4. Numerical answer preserved across each transformation.
    - WL-portable: Yes — exact preprocess-count validation test.

43. **`SliceInfo` dict** — `tree.sliced_inds` returns `{ind: SliceInfo(inner, ind, size, project)}`.
    - WL-portable: Yes.

## 5. Simulated Annealing

44. **`tree.simulated_anneal(tstart, tfinal, tsteps, numiter, seed)`** — `tests/test_tree.py:554-585`
    - `rand_tree(10,3,seed=42)`. Low-T (0.001/0.001) for 3 steps × 5 iter → tree_sa.total_flops() ≤ initial; preserves contract output.
    - With `target_size = max_size//4`, post-SA `tree_sa.max_size() <= target_size`.
    - WL-portable: Yes — SA is straightforward to reimplement.

45. **`HyperOptimizer(simulated_annealing_opts={})`** — based on Kalachev et al. arXiv:2108.05665
    - `cotengra.pathfinders.path_simulated_annealing.simulated_anneal_tree`. Main param `tsteps`. Can target_size for slicing.
    - WL-portable: Yes.

## 6. Subtree Reconfiguration / Dynamic Slicing

46. **`tree.subtree_reconfigure(maxiter='auto', subtree_size=N, select=...)`** — `docs/trees.ipynb`, `tests/test_tree.py:114-159`
    - parametrized `select ∈ {descend, random, max, min}` × `minimize ∈ {flops, combo, size}`.
    - Invariant: final ≤ initial (flops/combo strictly less, size monotone non-increasing).
    - On lattice[24,30] d_max=2: greedy → reconfigure → speedup 1253×.
    - WL-portable: Yes (subtree-local re-optimization is portable).

47. **`tree.subtree_reconfigure_forest_(num_trees, subtree_size, parallel)`** — `tests/test_tree.py:171-195`
    - Stochastic multi-tree refinement. parallel options: False, True, 'dask', 'ray'. final cost < initial.
    - WL-portable: Partial.

48. **`tree.slice_and_reconfigure_forest_`** — `docs/trees.ipynb`
    - `lattice[24,30] d_max=2` target=2^28: forest → 1.66×; double-forest with subtree_size=12 → 10.67×.
    - WL-portable: Partial.

49. **`HyperOptimizer(reconf_opts={"subtree_size":6})`** — `tests/test_optimizers.py:613-629`
    - On `rand_equation(30,5,seed=42,d_max=3)`: `optimizer.best['flops'] < best['original_flops']`.
    - WL-portable: Yes.

50. **`tree.contract_nodes(...)`** — `tests/test_tree.py:90-111`
    - Manual incomplete-tree construction; `tree.autocomplete()`; `get_incomplete_nodes()` returns `{childless: [parentless,...]}`.
    - WL-portable: Yes.

51. **`tree.windowed_reconfigure(minimize=CompressedPeakObjective(chi))`** — `tests/test_compressed.py:78-91`
    - On lattice [8,8] / [16,16] χ=4 / 16: peak_size strictly decreases.
    - WL-portable: Partial.

## 7. Contraction Execution

52. **`tree.contract(arrays)` / `tree.contract(arrays, strip_exponent=True)`** — `docs/contraction.ipynb`, `tests/test_compute.py:107-115`
    - lattice[10,10]: returns `8.022173030954557e+22`; with strip_exponent → `(1.0, 22.904292...)`.
    - 95 test_case_eqs cover scalar/hadamard/index-transformations/collapse/outer/inner/GEMM patterns.
    - WL-portable: Yes for the contract-correctness test (compare to symbolic einsum).

53. **`tree.contract_core` / `tree.contract_slice` / `tree.slice_arrays` / `tree.gather_slices` / `tree.gen_output_chunks`** — `docs/contraction.ipynb`, `tests/test_compute.py:188-214`
    - 10-tensor d_max=2 hyper-eq: `(tree.contract(arrays)**2).sum() == sum(chunk**2 sum for chunk in tree.gen_output_chunks(arrays))`.
    - WL-portable: Yes (exact arithmetic identity).

54. **`tree.contract_mpi(arrays, comm=...)`** — `examples/ex_mpi_spmd.py`
    - WL-portable: No.

55. **Backend dispatch via autoray** — `tests/test_backends.py:98-129`
    - lattice[4,4]: `tree.contract(arrays)` over numpy/torch/jax/tensorflow/cupy/autograd × float64/complex128 × strip_exponent × slicing(target=4) → all `assert_allclose(rtol=5e-6, atol=1e-8)`.
    - WL-portable: Partial (numpy parity sufficient).

56. **`autojit="auto"`** — for jax backend; `tests/test_compute.py:251-294`.

57. **`implementation="cotengra"`** — uses bmm/reshape/transpose only; demonstrated in `docs/examples/ex_trace_contraction_to_matmuls.ipynb` (rand_equation n=6, reg=5, n_out=1, n_hyper_in=1, n_hyper_out=1, seed=42). Good for verifying low-level WL implementation matches.

58. **`prefer_einsum=True`** — force einsum even when tensordot would work.

59. **`einsum` + interleaved + ellipses formats** — `tests/test_interface.py:85-114`
    - 5 ellipsis cases: `"c...a,b...c->b...a"` etc. All allclose to `np.einsum`.
    - WL-portable: Partial.

## 8. Compressed Contraction (TN approximate)

60. **`HyperCompressedOptimizer(chi, methods)`** — `tests/test_compressed.py:6-60`, `docs/examples/ex_compressed_contraction.ipynb`
    - methods: `greedy-compressed`, `greedy-span`, `kahypar-agglom`.
    - On lattice[10,10] χ=4 (`greedy-compressed` / `greedy-span`): `contraction_width(chi) < 20`; `flops/write/size/peak (chi) < _exact()` counterparts.
    - On lattice[16,16] χ=4 (`kahypar-agglom`): same invariants.
    - WL-portable: No.

61. **`ReusableHyperCompressedOptimizer(chi, max_repeats=256, minimize='combo-compressed')`** — `docs/examples/ex_compressed_contraction.ipynb`
    - 3D Ising 10×10×10 β=0.3 χ=16 → log2[SIZE]=21, log10[FLOPs]=10.89; contracted Z = 1×10^379.5602 (β=0.3) and 1×10^344.7334 (β=0.25 reuse).
    - WL-portable: No.

62. **`GreedyCompressed(chi)`** + `tree.windowed_reconfigure(minimize)` — `tests/test_compressed.py:64-91`.
    - WL-portable: No.

63. **`tree.get_path_surface()`** for `ContractionTreeCompressed` — `tests/test_tree.py:537-551`
    - lattice[6,6] greedy-compressed: returns N-1 pairs.
    - WL-portable: Partial.

64. **Compressed quantities: `max_size_compressed(N)`** — `tests/test_tree.py:270-279`
    - `rand_tree(30,5,seed=42,d_max=2,optimize='greedy-compressed' or 'greedy-span')`: `max_size_compressed(1) < max_size()`.
    - WL-portable: Partial.

## 9. Parallel Evaluation

65. **`parallel='concurrent.futures' / 'loky' / 'dask' / 'ray' / pool / 'threads'`** — `docs/advanced.ipynb`
    - Worker count from `COTENGRA_NUM_WORKERS` env, then `OMP_NUM_THREADS`, then `os.cpu_count()`.
    - WL-portable: Partial.

66. **MPI executor + SPMD** — `examples/ex_mpi_executor.py`, `examples/ex_mpi_spmd.py`
    - `rand_equation(100, 3, n_out=2, seed=666)`. SPMD uses `comm.allreduce` for best tree, then `tree.contract_mpi(arrays, comm=comm)`.
    - WL-portable: No.

67. **`ThreadPoolExecutor + jax.jit`** — `examples/ex_jax.py`
    - `rand_equation(140, 3, n_out=2, seed=666)`, `slicing_reconf_opts={"target_size":2**28}`, `max_repeats=32`. Submits per-slice contract via `jax.jit(tree.contract_core)`.
    - WL-portable: No.

## 10. Plotting (informational — not validation tests)

- `tree.plot_flat()`, `tree.plot_tent(order=True)`, `tree.plot_circuit()`, `tree.plot_ring()`, `tree.plot_rubberband()`, `tree.plot_contractions()`, `tree.plot_span()` — sources: `docs/visualization.ipynb`, `tests/test_tree.py:238-267`.
- `HyperOptimizer.plot_trials(y='flops')`, `plot_scatter(x='size', y='flops')`, `plot_parameters_parallel('greedy')` — `docs/visualization.ipynb`.
- `HyperGraph.plot(node_color='centrality', edge_color=False, draw_edge_labels=True)`.
- `SliceFinder.plot_slicings()`, `plot_slicings_alt()` — `tests/test_slicer.py`.
- `tree.print_contractions()` and `tree.describe('full'|'concise')` — text-based, useful for validation diff: lattice[5,6] tree shows 28 pairwise contractions with explicit (cost, widths, type) per line.

## 11. Other / Utilities

- **Rust-accelerated path search**: `cotengrust.optimize_random_greedy_track_flops`. Drop-in C-side replacement; releases GIL.
- **`pixi`-based install**, optional deps: `kahypar, cotengrust, optuna, cmaes, nevergrad, skopt, autoray, cytoolz, networkx, opt_einsum, loky, tqdm`.
- **API surface** (top-level `cotengra`): `einsum`, `einsum_tree`, `einsum_expression`, `array_contract`, `array_contract_tree`, `array_contract_expression`, `array_contract_path`, `AutoOptimizer`, `AutoHQOptimizer`, `HyperOptimizer`, `ReusableHyperOptimizer`, `RandomGreedyOptimizer`, `ReusableRandomGreedyOptimizer`, `GreedyOptimizer`, `OptimalOptimizer`, `RandomOptimizer`, `PathOptimizer`, `UniformOptimizer`, `QuickBBOptimizer`, `FlowCutterOptimizer`, `HyperCompressedOptimizer`, `ReusableHyperCompressedOptimizer`, `ContractionTree`, `ContractionTreeCompressed`, `HyperGraph`, `SliceFinder`, `get_hypergraph`, `get_symbol_map`, `register_hyper_function`.
- **Termination kwargs**: `max_repeats`, `max_time={float | 'rate:N' | 'equil:N'}`.
- **DiskDict cache** with sharding (v0.7.1+). `directory=True` auto-keys by hash of options.

## Recommended Validation-Test Sets

**Tier-1 (exact integer/path comparison)** — lowest-risk for cross-checking the WL `OptimalContractionPath`:
- 4-tensor demo (basics) → cost 4656, path `((0,1),(1,2),(0,1))`.
- lattice [4,5] d_max=3 seed=42 optimal → cost **1464**, width **5.584962500721156**.
- edgesort with `inputs=[(3,2),(2,1),(1,0)], all bond=2` → path **`((1,2),(0,1))`**.
- `eq="a,ab,bc,c->", shapes=[(4,),(4,2),(2,5),(5,)], paths=[(0,1),(0,1),(0,1)] or [(2,3),(0,1),(0,1)]` → both yield `total_flops()=20`.
- `eq="abc->abc"` single-input → cost 0, width 24.
- `lattice_equation([4,5])` default → contract_stats `{'flops':964,'write':293,'size':32}`.

**Tier-2 (statistical/qualitative)** — for `HyperOptimizer`-class searches:
- lattice [10,10]: combo HyperOptimizer → log2[SIZE]≈10, log10[FLOPs]≈5.28.
- Sycamore m=20 + slicing W=29 → ≈ 5.33×10^18 cost (24 sliced inds).
- Sycamore m=20 W=30 21-qubit marginal → 4.60×10^18 (23 sliced inds).
- 3D Ising 10³ χ=16 compressed → log2[SIZE]≈21, log10[FLOPs]≈10.89.

**Tier-3 (network-loading sanity)**: load all 8 JSON benchmarks (ID 1-8 above) into the WL paclet and round-trip the topology before any solver.
