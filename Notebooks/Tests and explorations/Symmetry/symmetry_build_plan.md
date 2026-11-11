# Plan: making symmetry pay off in tensor-network contraction

Companion to `symmetry_questions.md`, which holds the measurements behind each step.

## Where things stand

A `SymmetrizedArray` stores one value per group of entries that the symmetry forces to be equal (or opposite). A fully symmetric rank-6 tensor at dimension 20 needs 177,100 such values instead of 64 million. Contraction does not use this. Inside a network, a symmetric tensor is expanded to the full array before it is contracted, so it costs exactly what an ordinary array costs. Calling `TensorContract` on a `SymmetrizedArray` directly does keep the right symmetry on the result. But its time grows like the sixth power of the dimension, and it runs thousands of times slower than `ArrayDot` on the full arrays. Since a symmetric network costs the same as its dense copy, the choice of contraction order takes no account of symmetry either.

The savings exist on paper and are not used. Each step below is new code that would use them.

## Steps, cheapest first

**1. Measure where the full array is the real limit.**
Before building anything, find the rank and dimension at which the full array no longer fits in memory or takes most of the time, while the independent values still fit easily. Test: time and memory for building, then contracting, a fully symmetric tensor at rank 6 to 8 and dimension 10 to 40. Done when we have a table that shows where the compact form is the only option.

**2. Check whether `SparseArray` already gives the U(1) saving.**
A conserved charge, such as particle number in an XXZ chain, makes most entries zero in a known pattern. `SparseArray` may already skip those zeros well enough. Test: contract the same MPS in three ways (dense, `SparseArray`, and arrays split into charge blocks by hand) and compare time and memory. Done when we know whether a block format is worth writing.

**3. A contraction function that works on the independent values only.**
It takes two symmetric tensors and loops over their stored values once each. For every value it adds in all the terms that the symmetry copies of that value would contribute. Example: for a symmetric S, Σ S_ij v_i w_j becomes the sum over i ≤ j of S_ij (v_i w_j + v_j w_i), with the diagonal counted once. The result comes out in compact form. Test: agreement with `ArrayDot` on the expanded arrays at small sizes, then time and memory against both `ArrayDot` and `TensorContract` as rank and dimension grow. Done when it beats the expanded route at the sizes found in step 1.

**4. A rule for the symmetry of the result.**
Step 3 needs to know which symmetry survives a contraction, so it can store the result compactly. Start with single permutations of slots, including the extra swap symmetry when the same tensor is used twice (1540 independent values instead of 3025 at dimension 10). Test: compare the rule's prediction with the symmetry measured on the computed result, over random cases. Done when the two agree on every case tried.

**5. A planner cost that counts independent values.**
Price each intermediate tensor by its number of independent values and by the multiplications step 3 actually does. Test: the change of basis of a symmetric rank-4 tensor by the same matrix on all four slots, where the right order needs about 6 times fewer multiplications. Done when the planner picks that order and the measured time follows.

**6. Young's orthogonal form, for SU(2).**
An SU(2)-invariant Hamiltonian on n spins splits into one small matrix per Young shape. Young's orthogonal form gives the matrix for each slot swap directly in that small space. Example: a 12-spin ring needs matrices no larger than 297 by 297 instead of one 4096 by 4096 matrix. Test: the energies from the small matrices must match the full diagonalization at small n. Then time both methods as n grows. Done when the small-matrix route gives the same energies and is faster.

**7. The correct projector onto each Young shape, and fixing the demos.**
Adding `YoungProject` over all standard tableaux of one shape is not the orthogonal projector onto that shape once the rank is 5 or more. Demos 1 to 3 rely on that sum. Build the projector from the characters of the symmetric group, or from step 6, and redo the demos with it. Test: the projector squares to itself and is symmetric, and the projectors for all shapes add to the identity, at ranks 5 and 6. Done when the demos pass these checks.

**8. The projector as a small network, and symmetry-resolved entanglement.**
Write the projector from step 7 as a matrix product operator, so it can be applied to many copies of a state without forming the full matrix. Use it, together with charge labels on the bonds, for entanglement split by charge or by Young shape. Test: a 20-site XX chain, comparing against the exact free-fermion answer. Done when the network result matches at sizes where the full matrix cannot be stored.

## Not planned yet

Relations that tie several permuted copies together, like the Bianchi identity, need more than single slot permutations. For the Riemann tensor they save at most 1.5 times over its single-swap symmetries, so they wait until steps 3 to 5 work. For shapes made of k antisymmetric pairs the saving grows fast with k. Revisit these if such tensors become a real use case.
