(* Tests/test_hook_factor.wl

   Tests for HookFactor in Wolfram`TensorNetworks`Symmetry`.

   HookFactor[lambda] is 1 / (product of hook lengths), so that
   f^lambda = n! HookFactor[lambda] is the dimension of the S_n irrep V_lambda.
   The kernel evaluates it through the Vandermonde form of the Frobenius
   formula, with shifted parts l_i = lambda_i + r - i:

       HookFactor[lambda] = Prod_{i<j} (l_i - l_j) / Prod_i l_i!

   Every expected value below is computed without HookFactor, HookLengths or
   TableauDimension (TableauDimension is defined as n! HookFactor, so it
   cannot check HookFactor). Sweeps cover every row count up to n, because
   a wrong normalization of the Frobenius determinant stays invisible on
   one-row shapes, flips only the sign on two-row shapes, and changes the
   magnitude from three rows on.

   A.  Hook-length formula, with hooks built from arm and leg lengths here.
   B.  Counting standard Young tableaux through the branching rule
       (Young's lattice): f^lambda as a number of basis states.
   C.  Regular representation: Sum_lambda (f^lambda)^2 = n!.
   D.  Frobenius-Schur: Sum_lambda f^lambda = number of involutions of S_n,
       counted by brute force over the group.
   E.  Tensoring with the sign representation: f^lambda = f^(lambda').
   F.  Closed-form families at large n (one-dimensional irreps, hooks,
       two-row ballot numbers).
   G.  n spin-1/2 particles: the degeneracy of total S^2 = S(S+1),
       measured as a null-space dimension of the spin operators, equals
       (2S + 1) f^(n/2 + S, n/2 - S) (Schur-Weyl duality at d = 2).
   H.  Tableau input and malformed partitions.
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];
Needs["Wolfram`TensorNetworks`Symmetry`"];


(* ============================================ *)
(* Independent references                       *)
(* ============================================ *)

(* Irrep dimension read off HookFactor. *)
hookDimension[p_List] := Total[p]! HookFactor[p]

allPartitions[nmax_Integer] := Catenate[IntegerPartitions /@ Range[nmax]]

(* Conjugate partition: column j has as many cells as rows of length >= j. *)
conjugate[p_List] := Table[Count[p, x_ /; x >= j], {j, First[p]}]

(* Product of hook lengths: hook(i, j) = arm + leg + 1 with
   arm = lambda_i - j and leg = lambda'_j - i. *)
hookProduct[p_List] :=
    With[{c = conjugate[p]},
        Times @@ Flatten @ Table[(p[[i]] - j) + (c[[j]] - i) + 1, {i, Length[p]}, {j, p[[i]]}]
    ]

(* Branching rule: in a standard tableau the largest entry n sits in a
   removable corner, so f^lambda = Sum over corners of f^(lambda - corner).
   Row i ends in a corner when it is the last row or longer than row i + 1. *)
removeCorners[p_List] :=
    DeleteCases[ReplacePart[p, # -> p[[#]] - 1], 0] & /@
        Select[Range[Length[p]], # == Length[p] || p[[#]] > p[[# + 1]] &]

standardTableauCount[{}] = 1;
standardTableauCount[p_List] :=
    standardTableauCount[p] = Total[standardTableauCount /@ removeCorners[p]]

(* Number of sigma in S_n with sigma^2 = identity, by enumerating the group. *)
involutionCount[n_Integer] := Count[Permutations[Range[n]], s_ /; s[[s]] === Range[n]]

(* Total spin component S_a = Sum_k sigma_a^(k) / 2 on n spin-1/2 sites. *)
siteOperator[op_, k_Integer, n_Integer] :=
    KroneckerProduct @@ ReplacePart[ConstantArray[IdentityMatrix[2, SparseArray], n], k -> SparseArray[op]]

totalSpinComponent[a_Integer, n_Integer] :=
    Total[siteOperator[PauliMatrix[a] / 2, #, n] & /@ Range[n]]

totalSpinSquared[n_Integer] := Total[With[{s = totalSpinComponent[#, n]}, s . s] & /@ {1, 2, 3}]

(* Degeneracy of the eigenvalue S(S+1) of total S^2: the dimension of the
   null space of S^2 - S(S+1). *)
spinDegeneracy[s2_, spin_] := Length[s2] - MatrixRank[s2 - spin (spin + 1) IdentityMatrix[Length[s2], SparseArray]]


(* ============================================ *)
(* A. Hook-length formula                       *)
(* ============================================ *)

(* A1. HookFactor[lambda] = 1 / Prod hook(i, j) for every partition of
   n = 1..10 (138 shapes, row counts 1 through 10). *)
VerificationTest[
    Select[allPartitions[10], HookFactor[#] =!= 1 / hookProduct[#] &],
    {},
    TestID -> "A1.hook_length_formula_n_le_10"
]

(* A2. The result is a positive unit fraction 1/k with k | n!: a hook
   product divides n! because f^lambda is an integer. *)
VerificationTest[
    Select[allPartitions[10],
        ! (Numerator[HookFactor[#]] === 1 && Divisible[Total[#]!, Denominator[HookFactor[#]]]) &
    ],
    {},
    TestID -> "A2.positive_unit_fraction"
]


(* ============================================ *)
(* B. Standard Young tableaux count             *)
(* ============================================ *)

(* B1. f^lambda = n! HookFactor[lambda] counts the standard Young tableaux
   of shape lambda, i.e. the paths in Young's lattice from the empty
   diagram to lambda. This is the dimension of V_lambda as the size of its
   Young (Gelfand-Tsetlin) basis, computed with no hook lengths at all. *)
VerificationTest[
    Select[allPartitions[10], hookDimension[#] =!= standardTableauCount[#] &],
    {},
    TestID -> "B1.branching_rule_n_le_10"
]

(* B2. Staircases {k, k-1, ..., 1} with k <= 4 lie inside the B1 sweep;
   k = 5 (n = 15) is the first beyond it, where a mis-normalized
   determinant is off by Prod_{j<5} j! = 288. Checked against the
   branching-rule count for k = 1..5. *)
VerificationTest[
    hookDimension[Range[#, 1, -1]] & /@ Range[5],
    standardTableauCount[Range[#, 1, -1]] & /@ Range[5],
    TestID -> "B2.staircase_shapes"
]


(* ============================================ *)
(* C. Regular representation                    *)
(* ============================================ *)

(* C1. C[S_n] contains each irrep V_lambda f^lambda times, so
   Sum_lambda (f^lambda)^2 = |S_n| = n!. Checked up to n = 20
   (627 partitions of 20), where no enumeration of S_n is possible. *)
VerificationTest[
    Total[hookDimension[#]^2 & /@ IntegerPartitions[#]] & /@ Range[20],
    Range[20]!,
    TestID -> "C1.sum_of_squares_n_le_20"
]


(* ============================================ *)
(* D. Frobenius-Schur involution count          *)
(* ============================================ *)

(* D1. Every irrep of S_n is real (Frobenius-Schur indicator +1), so
   Sum_lambda f^lambda = #{sigma in S_n : sigma^2 = 1}. The right side is
   counted by running over all n! permutations. The sum is linear in
   f^lambda, so a sign error on any shape shows up here (it cancels in C1). *)
VerificationTest[
    Total[hookDimension /@ IntegerPartitions[#]] & /@ Range[8],
    involutionCount /@ Range[8],
    TestID -> "D1.involution_count_n_le_8"
]

(* D2. The same identity at larger n against the recurrence
   I(n) = I(n-1) + (n-1) I(n-2): site n is either fixed or paired with one
   of the other n - 1 sites. *)
VerificationTest[
    Total[hookDimension /@ IntegerPartitions[#]] & /@ Range[20],
    (* {I(k-1), I(k)} -> {I(k), I(k+1)}, starting from {I(0), I(1)} = {1, 1} *)
    FoldList[{#1[[2]], #1[[2]] + #2 #1[[1]]} &, {1, 1}, Range[19]][[All, 2]],
    TestID -> "D2.involution_recurrence_n_le_20"
]


(* ============================================ *)
(* E. Conjugation by the sign representation    *)
(* ============================================ *)

(* E1. V_(lambda') = V_lambda tensor sgn, so conjugate shapes have equal
   dimension. Conjugation swaps a shape with r rows for one with
   lambda_1 rows, so this ties shapes of different row counts together. *)
VerificationTest[
    Select[allPartitions[12], HookFactor[#] =!= HookFactor[conjugate[#]] &],
    {},
    TestID -> "E1.conjugate_invariance_n_le_12"
]


(* ============================================ *)
(* F. Closed-form families at large n           *)
(* ============================================ *)

(* F1. Trivial {n} and sign {1^n} representations are one-dimensional:
   HookFactor = 1/n!. The sign shape has n rows. *)
VerificationTest[
    {hookDimension[{#}], hookDimension[ConstantArray[1, #]]} & /@ Range[25],
    ConstantArray[{1, 1}, 25],
    TestID -> "F1.one_dimensional_irreps_n_le_25"
]

(* F2. Hook shapes {n-k, 1^k} carry the k-th exterior power of the
   standard representation: f = Binomial[n-1, k]. These have k + 1 rows. *)
VerificationTest[
    Flatten @ Table[hookDimension[Join[{n - k}, ConstantArray[1, k]]] - Binomial[n - 1, k], {n, 2, 25}, {k, 0, n - 1}],
    ConstantArray[0, Total[Range[2, 25]]],
    TestID -> "F2.hook_shapes_n_le_25"
]

(* F3. Two-row shapes {n-k, k}: f = Binomial[n, k] - Binomial[n, k-1],
   the ballot numbers. *)
VerificationTest[
    Flatten @ Table[hookDimension[{n - k, k}] - (Binomial[n, k] - Binomial[n, k - 1]), {n, 2, 30}, {k, 1, Floor[n / 2]}],
    ConstantArray[0, Total[Floor[Range[2, 30] / 2]]],
    TestID -> "F3.two_row_ballot_numbers_n_le_30"
]

(* F4. Rectangles {k, k, k} (three rows) against the three-dimensional
   ballot numbers 2 (3k)! / (k! (k+1)! (k+2)!). *)
VerificationTest[
    hookDimension[{#, #, #}] & /@ Range[12],
    2 (3 #)! / (#! (# + 1)! (# + 2)!) & /@ Range[12],
    TestID -> "F4.three_row_rectangles"
]


(* ============================================ *)
(* G. Spin-1/2 chains (Schur-Weyl at d = 2)     *)
(* ============================================ *)

(* G1. (C^2)^(tensor n) = Sum_S V_(n/2+S, n/2-S) tensor W_S, where W_S is the
   spin-S multiplet. The eigenvalue S(S+1) of total S^2 therefore has
   degeneracy (2S + 1) f^(n/2+S, n/2-S). The left side is measured on the
   explicit 2^n x 2^n spin operators for n = 2..7. *)
VerificationTest[
    Table[
        With[{s2 = totalSpinSquared[n]},
            Table[spinDegeneracy[s2, n / 2 - k], {k, 0, Floor[n / 2]}]
        ],
        {n, 2, 7}
    ],
    Table[
        Table[(n - 2 k + 1) hookDimension[DeleteCases[{n - k, k}, 0]], {k, 0, Floor[n / 2]}],
        {n, 2, 7}
    ],
    TestID -> "G1.total_spin_degeneracies"
]

(* G2. Summed over S the multiplets fill the whole Hilbert space:
   Sum_S (2S + 1) f^(n/2+S, n/2-S) = 2^n. *)
VerificationTest[
    Table[Sum[(n - 2 k + 1) hookDimension[DeleteCases[{n - k, k}, 0]], {k, 0, Floor[n / 2]}], {n, 1, 20}],
    2^Range[20],
    TestID -> "G2.spin_multiplets_fill_hilbert_space"
]


(* ============================================ *)
(* H. Tableau input and malformed partitions    *)
(* ============================================ *)

(* H1. A YoungTableau is dispatched through its shape: every filling of a
   shape gives the same factor. *)
VerificationTest[
    {HookFactor[YoungTableau[{{1, 2, 4}, {3, 5}}]], HookFactor[YoungTableau[{{1, 3, 5}, {2, 4}}]], HookFactor[YoungTableau[{3, 2}]]},
    {1 / 24, 1 / 24, 1 / 24},
    TestID -> "H1.tableau_input_uses_shape"
]

(* H2. A list that is not a partition (increasing, or with a zero part)
   fails with HookFactor::notpar. *)
VerificationTest[
    HookFactor[{1, 2}],
    $Failed,
    {HookFactor::notpar},
    TestID -> "H2.increasing_list_rejected"
]

VerificationTest[
    HookFactor[{2, 0}],
    $Failed,
    {HookFactor::notpar},
    TestID -> "H3.zero_part_rejected"
]
