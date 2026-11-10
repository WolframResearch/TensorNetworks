# Test audit

Audit date 2026-11-09, against the working tree with the uncommitted rewrite of
`TensorNetworks/Kernel/Contraction.wl`. Every test file was read in full: 14 files in
`Tests/` (11 test files, `test_setup.wl`, `run_tests.wl`, `run_doc_examples.wl`) and 21
under `Tests/external_validation/` (runner, helpers, 11 `paclet_primitives`, 4 `baselines`,
4 `paclet_fuzz`). The suite was then rerun against scratch copies of the paclet with
deliberate bugs planted in the code, to see which tests notice. The copies were taken early
in the session; another session kept editing `Contraction.wl` (label bookkeeping in the pair
contractors) and `MPS.wl` afterwards, but every line mutated below is still present unchanged
in the working tree.

## The short answer

The suspicion is half right. The core contraction tests that compare against a brute-force
index sum (`test_hyperedge_contraction.wl`, `test_network_identities.wl`), and the
Young-tableau and hook-length tests, are genuinely strong: planted bugs in the pair step, the
output order, and exact arithmetic were caught by them, usually by many tests at once. Most
of the rest is weak. Of the 189 "external validation" passes, 24 run no paclet code at all,
about 40 more check only that something has the right length, shape, or sign, and the fuzz
layer mostly compares the paclet with itself. The 2078 documentation examples never compare
an output with anything: an example passes if it returns without a timeout, `$Failed`, or an
unexpected message. Two planted bugs that give plainly wrong numbers on tiny networks survived
every test in every suite (see the mutation table), and both test runners silently drop tests
that end in a message failure or an error, which is already hiding one test today.

Of 14 planted bugs, the unit tests caught 11 and the external suite caught 4. Three survived
everything: a sign error in the real-times-complex product, misaligned batch entries in the
batch step with larger blocks, and a planner that picks the most expensive acceptable plan
(which turns a 0.5 second PEPS norm into an out-of-memory failure). A fourth class of bug, a
conjugated MPS state, is invisible to every MPS test except five in
`test_network_identities.wl`, because every other MPS test uses real random states.

## Verdicts by file

Strong means a wrong result in the covered code makes it fail. Weak means it could pass with
wrong code (self-comparison, length or type checks, symmetric inputs that hide index
mistakes, loose tolerances). Trivial means it tests unimportant code (accessors, display,
argument plumbing) or no paclet code.

### Unit tests (`Tests/`, run by `run_tests.wl`, 293 tests)

| File | Tests | Verdict | Reason |
| --- | --- | --- | --- |
| `test_hyperedge_contraction.wl` | 41 | strong | Random integer networks with hyperedges, repeated and shared-output labels checked exactly against a brute-force sum over every index assignment, through several routes; exact-scaled leaves to 25 digits; closed forms for traces and diagonals. Its weakness is size: oracle networks have at most 5 tensors and dimensions 1 to 3, so large-block code paths are never reached. |
| `test_network_identities.wl` | 48 | strong | Symbolic matrix chains as exact polynomial identities for every engine, MPS Schmidt values and entropies against the SVD of the full state vector, W and GHZ spectra in closed form, optimal path cost against an exhaustive search. The only MPS tests that check the state itself survives canonicalization. |
| `test_hook_factor.wl` | 23 | strong | Hook factor against hand-built hook products, a branching-rule count of standard tableaux, involution counts by brute force over S_n, and Schur-Weyl checks on explicit spin matrices. Exemplary. |
| `test_schur_dimension.wl` | 27 | strong | Closed forms, Schur-Weyl sum, and projector rank as an independent check. Failure tests wrap the call in `Quiet`, so they check the return value but not the message. Calls `Exit[1]` on failure, which kills `run_tests.wl` before its summary. |
| `test_diagonal_reduction.wl` | 18 | strong (mixed) | Grover amplitudes against the closed form are independent and strong; the reduction tests compare the reduced network with the unreduced one through the same paclet contraction, which is acceptable because the unreduced route is itself oracle-tested elsewhere. |
| `test_contraction_containers.wl` | 46 | weak | Every value is compared with the paclet's own `"ArrayDot"` route or another paclet method, so a bug shared by the routes passes. Many tests check only a head (`NetGraph`, `List`, `SparseArray`) or an error message. Covers the NetGraph export and leaf-container plumbing, not contraction math. |
| `test_mps.wl` | 12 | weak | Every check is structural and judged by the paclet's own predicates: `MPSCanonicalQ`, norm > 0, entropy >= 0, Schmidt values summing to 1 (true by construction), truncation returns a network. A canonical form that returned a different state would pass all twelve. |
| `test_add_delete.wl` | 15 | weak | Tracks tensor counts and free-index lists after add/delete; never contracts anything. One test has a dead line (`graphAdded = gAdded`, an undefined symbol). |
| `test_random_tensor_network.wl` | 9 | trivial | Shapes and element types of random networks. |
| `test_array_utilities.wl` | 16 | trivial | The boundary with `Wolfram/Arrays`: which names are defined where, a few shape rules, `ArraySymmetry`. Real checks, low stakes. |
| `test_young_filling_label.wl` | 38 | trivial | 14 tests check which word ("Canonical", "Standard", "Explicit") appears in the formatted box of a tableau; most others are accessor equalities. The 10 `StandardTableauQ` tests are real but small. |

### Documentation examples (`run_doc_examples.wl`, 2078 examples)

Smoke test only. An example passes when it finishes within 30 seconds, does not return
`$Failed`, and emits only messages that the stored notebook also shows. The stored output
cells are never compared, so an example that prints a wrong number passes. It does catch
crashes, hangs, new error messages and broken parsing, which is worth having, but the 2078
count says nothing about correctness. Proof: with mutant M12 below planted (a pair step that
closes to a scalar returns twice the value), the harness reported no failures (2070 passed,
8 skipped for want of a front end), while two examples, `TensorNetworkContract` input 20 and
`TensorNetwork` input 30, returned a different number from the unmutated paclet (two runs of
the unmutated paclet agree on both, so this is not randomness).

### External validation (`Tests/external_validation/`, 189 reported passes)

| File | Tests | Verdict | Reason |
| --- | --- | --- | --- |
| `paclet_primitives/symmetry_textbook_reference.wl` | 21 | strong | `YoungSymmetrize` against a brute-force sum over row and column groups, including non-standard slot orders; Riemann symmetries of the projected tensor. |
| `paclet_primitives/symmetry_basic.wl` | 42 | strong | Irrep dimensions, hook lengths and conjugate partitions against textbook values; projector idempotency and orthogonality in exact arithmetic; error paths. Projector checks stop at n = 3, below the n = 6 regime where the known isotypic-projector pitfall appears. |
| `paclet_primitives/cotengra_benchmarks.wl` | 7 | strong (paths) | Exact optimal path costs against cotengra (4656, 28, the lattice fixture). T7 runs no paclet code: it checks the test's own cost helper against cotengra. T2 uses all-ones tensors (see below). |
| `paclet_primitives/tensor_algebra.wl` | 17 | strong, wrong target | Explicit index sums with random inputs, but through `EinsteinSummation`, not the rewritten contraction engine (only A10 reaches it). A12 contains dead trial lines that emit `EinsteinSummation::output` and `::shape`; it ends as a message failure, which the runner drops silently (reported as 16 passes, 0 failures). |
| `paclet_primitives/tn_expectations.wl` | 3 (+1 skip) | mixed | F7 is strong (quimb random MPS norm and every local Z, from a fixture). F5 and F6 contract product states of basis vectors, where nearly any contraction gives 1 or -1. |
| `paclet_primitives/tn_canonical_states.wl` | 6 (+1 skip) | weak | T2 and T4 call no paclet function (plain dot products). T1, T3, T5 contract basis-state products. T6 is strong (quimb 3x3 PEPS norm and nine local Z values). |
| `paclet_primitives/contraction_paths.wl` | 14 | weak | B5 and B11 compare `TensorNetworkContract[tn]` with itself (the "greedy" and "optimal" results are the same call). B1, B4, B10, B12 check only path length, distinct positions, `NumericQ` or result shape. B9 (optimal no worse than greedy) and B8 (no worse than a cotengra bound) are loose. Bcost1 and Bcost2 (exact costs) and B2, B3, B6 (values) are real. |
| `paclet_primitives/contraction_paths_exact.wl` | 9 | weak | T2 to T5 check path length, which is n - 1 for any valid path. T7 uses all-ones tensors. T8 checks an error message; T9 only that a list comes back. |
| `paclet_primitives/tensor_algebra_edge.wl` | 7 | weak | Identity and all-ones inputs (traces of identities, delta tensors, all-ones rank-4 products), which cannot reveal a swapped or misaligned index. T7 repeats `tensor_algebra.wl` A13. |
| `paclet_primitives/mps.wl` | 10 (+1 skip) | weak | G1 checks a head, G9 that a norm is positive, G8 an entropy bound, G7 a normalization that holds by construction, G2 compares `MPSOverlap` with `MPSNorm` (paclet with paclet). G6 (overlap of state with its canonical form) and G11 (quimb fixture) are real. |
| `paclet_primitives/mps_canonical_states.wl` | 6 (+2 skips) | weak | Product-state entropies and an entropy upper bound. The AKLT tests exercise only a two-tensor outer product in `EinsteinSummation`; the eigenvalues are Mathematica's. T4 is the one real state-preservation check. |
| `baselines/*.wl` (4 files) | 24 (+4 skips) | trivial | No paclet code at all, as the runner's own header admits: Mathematica's `Eigenvalues`, `SingularValueDecomposition`, matrix identities like `H.Z.H = X`, a formula typed into the test and evaluated. D3 uses a tolerance of 1e-2. They still count toward the 189. |
| `paclet_fuzz/fuzz_young_projector.wl` | 6 | strong-ish | Idempotency, orthogonality and full (anti)symmetry are genuine algebraic properties, checked exactly over all partitions up to n = 4. |
| `paclet_fuzz/fuzz_contraction_paths.wl` | 6 | weak | Compares the default, optimal-path and greedy-path contractions with one another: a bug in the pair step shared by every path passes. Path validity is structural. |
| `paclet_fuzz/fuzz_mps.wl` | 6 | weak | Paclet against paclet (`MPSOverlap` vs `MPSNorm`, overlap before and after canonicalization, `MPSCanonicalQ`). Nothing checks the canonical state equals the original. |
| `paclet_fuzz/fuzz_tn_contract.wl` | 6 | weak | Finiteness and shape of random contractions, positivity of `<psi|psi>`, identity-matrix deltas and traces. F-CONTRACT-5 (a random elementwise inner product) is the one value check. |

### Runner defects

Both `run_tests.wl` and `run_external_validation.wl` count only the outcomes "Success" and
"Failure" (the unit runner also "Aborted"). `TestReport` has two more, "MessagesFailure" and
"Error", and tests ending in either vanish from both counts while the exit code stays 0. One
test is hidden this way today (`paclet-tensor-A12-multi-trace`). The unit test files find `test_setup.wl`
through `$InputFileName`, which under `TestReport` names the calling script, so they load
only when the caller sits in `Tests/` (as `run_tests.wl` does) or is the test file itself. `test_schur_dimension.wl` calls `Exit[1]` on failure, ending the whole
run before later files and the summary. Under mutant M01, the self-comparison tests B5 and B11
in `contraction_paths.wl` ended as message failures and were likewise dropped from the
report, which is why that run shows 173 + 14 instead of 189.

## Mutation results

Each bug was planted in a scratch copy of `TensorNetworks/` (never the repository), and both
`run_tests.wl` and `run_external_validation.wl` were run in full against it. The unmutated
copy reproduces the reported baseline (292 of 293 unit, with the known
`E3.symbolic_arraydot_dimensions` failure; 189 external). Counts below exclude E3.

| # | Planted bug (file, function) | Unit tests that fail | External tests that fail | Verdict |
| --- | --- | --- | --- | --- |
| M01 | `matrixPair`: result labels returned as [other, own] while the data is [own, other] | 46 | 14 | caught widely |
| M02 | `matrixProduct`: real times complex recombined with the wrong sign of the imaginary part | 0 | 0 | **survives** |
| M03 | `batchPairEager`, per-entry `Dot` branch (blocks larger than 16): batch entries of the second operand reversed | 0 | 0 | **survives** |
| M04 | `batchBroadcast` (small blocks): second operand's batch entries reversed | 6 (all hyperedge oracle) | 0 | caught |
| M05 | `batchOuter` (nothing summed): second operand's batch entries reversed | 10 | 1 | caught |
| M06 | `batchPairEager`, sparse branch: batch entries reversed | 3 | 0 | caught narrowly |
| M07 | `affordablePlan`: picks the most expensive acceptable plan instead of the cheapest | 0 | 0 | **survives** |
| M08 | `cheapestPlan`: never searches beyond greedy | 1 (a Grover memory limit) | 0 | caught narrowly |
| M09 | `planKey`: plan cache keyed by shape only, ignoring values and sparsity | 1 (`AutomaticPlan_CachedByShape`) | 0 | caught narrowly |
| M10 | Final transpose to the requested output order inverted (differs only for 3-cycles and longer) | 15 | 3 | caught |
| M11 | `ratioScale`: exact common factor loses its sign | 3 (scaled oracle) | 0 | caught narrowly |
| M12 | `matrixPair`: a step that closes to a scalar returns twice the value | 21 | 9 | caught; doc examples miss it |
| M13 | `svdTruncate` (MPS): returns the complex conjugate of the state | 5 (`test_network_identities` D1-D5) | 0 | caught only there |
| M14 | `svdTruncate` (MPS): keeps the smallest singular values instead of the largest | 3 (D4-D6) | 0 | caught only there |

The survivors are real blind spots, not unreachable code. On the M02 copy, a 40x40 real matrix
times a 40x3 complex matrix comes out wrong by about 26 in the largest entry; on the M03 copy,
a three-entry batched matrix product (`{b, i, s}` with `{b, s, k}`, output `{b, i, k}`, blocks
4x5 by 5x6) comes out wrong by about 0.7. On a 5x5 PEPS norm with bond dimension 4, the
unmutated planner finishes in about 0.5 s, M08 in about 5 s, and M07 exceeds a 6 GB memory
limit; no test notices M07.

What the table says about the suites: every bug that both suites caught was caught by the
brute-force oracle or the closed-form identities in the unit tests; the external suite never
caught a bug the unit tests missed. Nothing in `test_mps.wl`, `paclet_primitives/mps.wl`,
`mps_canonical_states.wl` or `fuzz_mps.wl` failed for M13 or M14.

## Important features with no real test

- Batch steps with blocks larger than 16 entries (the per-entry `Dot` branch): hyperedges or
  shared output labels on tensors with real bond dimensions. No test reaches it (M03).
- A real operand meeting a complex one with a summed length of 16 or more: the new split
  product has no test (M02).
- The quality of the Automatic plan: no test checks the chosen path's cost or peak memory
  against anything; values are the same for any path, so value tests cannot see a bad plan
  (M07).
- Oracle checks at a size where the planner actually searches: the brute-force networks have
  at most 5 tensors and dimensions of 1 to 3, below the 8-tensor threshold where randomized
  greedy, half-weight greedy, the sweep and the reduced plans compete.
- Complex MPS states outside `test_network_identities.wl`: every random MPS in the other MPS
  tests is real, so conjugation errors are invisible (M13).
- `MPSTruncate`'s result state, `MPSNormalize`'s result state, and `MPSOverlap` of two
  different states, each against the dense state vector. Only self-overlaps and one quimb norm
  are checked.
- The `IndexArray` sub-context beyond its boundary with `Wolfram/Arrays`: `IndexContract`,
  `IndexJuggling` (raising and lowering), `MetricTensor` geometry. The kernel audit's findings
  F3, F6, F7 and F8 are live bugs that no test fails on.
- `YoungProject` at n = 6, where summing projectors over standard tableaux stops being the
  isotypic projector (the pitfall recorded in project memory); projector checks stop at n = 4.
- Path-search options: `GreedyContractionPath` `"Temperature"`, `"MemoryWeight"`,
  `"RandomSeed"`, and `OptimalContractionPath` with `Method -> "size"` are run but their
  results are never checked for optimality (only `"flops"` is checked against exhaustive
  search).
- Graph form: `TensorNetworkRemoveCycles` and `BinaryTensorNetwork` have one value test
  between them.

## Most valuable tests to add

1. Make both runners count "MessagesFailure" and "Error" as failures, and delete the dead
   trial lines in `tensor_algebra.wl` A12. A few lines; without it any new test can fail
   invisibly.
2. Extend the brute-force oracle in `test_hyperedge_contraction.wl` to batch steps with large
   blocks: random networks with hyperedges and shared outputs at dimensions 4 to 8, dense and
   sparse, checked against the oracle or against an explicit per-batch `Dot`. Catches M03.
3. Real-times-complex contractions in both orientations, summed length 16 to 64, against
   plain `Dot`. Catches M02.
4. Planner guard tests: a fixed set of PEPS norms and brickwork circuits where the chosen
   plan's priced cost must stay within a small factor of the best of many randomized greedy
   trials, run under `MemoryConstrained`. Catches M07 and strengthens M08.
5. A larger oracle tier: a few seeds with 8 to 12 tensors (total index assignments kept under
   about 10^6) so the planner's search runs and its result is checked exactly.
6. Complex MPS in `test_mps.wl` and `fuzz_mps.wl`, comparing canonical, truncated and
   normalized states with the dense state vector (`test_network_identities.wl` already has the
   helpers), plus `MPSOverlap` of two different states against a dense inner product.
   Catches M13 and M14 outside one file.
7. Compare documentation outputs with the stored Output cells for deterministic examples, with
   a numeric tolerance. This turns the 2078 smoke runs into value checks.
8. Replace the self-comparisons (B5, B11) and length-only path tests in
   `contraction_paths.wl` and `contraction_paths_exact.wl` with cost-against-exhaustive-search
   checks in the style of `test_network_identities.wl` C2, and move the 24 `baselines` tests
   out of the pass count (they test Mathematica, not the paclet).
9. `IndexContract` and metric raising and lowering against explicit sums, with one test per
   audit finding F3, F6, F7, F8.
10. `YoungProject` isotypic sums at n = 6 (shapes {4, 2} and {3, 3}).
