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
   evaluating the Frobenius determinant as Det[Binomial[l_i, j - 1]] instead
   of the Vandermonde product is off by (-1)^Binomial[r, 2] / Prod_{j<r} j!
   on a shape with r rows: exact on one-row shapes, a sign flip on two-row
   shapes, and a wrong magnitude from three rows on.

   A.  Hook-length formula, with hooks built from arm and leg lengths here,
       exhaustively to n = 10 and on partitions of 60 with 3 to 45 rows.
   B.  Counting standard Young tableaux through the branching rule
       (Young's lattice): f^lambda as a number of basis states.
   C.  Regular representation: Sum_lambda (f^lambda)^2 = n!.
   D.  Frobenius-Schur: Sum_lambda f^lambda = number of involutions of S_n,
       counted by brute force over the group.
   E.  Tensoring with the sign representation: f^lambda = f^(lambda').
   F.  Closed-form families at large n (one-dimensional irreps, hooks,
       two-row ballot numbers, three-row rectangles) and the Catalan
       asymptotics of the rectangles {m, m} up to m = 2000.
   G.  Schur-Weyl duality. For n spin-1/2 particles, total S^2 commutes
       with S^+ and with every exchange of neighboring sites; the number of
       spin-S highest-weight vectors equals f^(n/2 + S, n/2 - S); the
       degeneracy of S^2 = S(S+1) equals (2S + 1) f^(n/2 + S, n/2 - S). At
       symbolic local dimension d, Sum_lambda f^lambda dim W_lambda(d) = d^n
       as polynomials in d. On (C^d)^(tensor n) with d = 2, 3, the n! site
       permutation operators span an algebra of dimension Sum (f^lambda)^2
       over shapes with at most d rows.
   H.  Tableau input and malformed partitions.

   Regimes covered:
     General symbolic       G5: identity in symbolic d, every row count.
     Exactly solvable       F1-F4: closed forms up to n = 30.
     Asymptotic             F5: f^(m,m) against 4^m / (m^(3/2) Sqrt[Pi])
                            through order 1/m^2, up to m = 2000.
     Independent reference  B1, D1: enumeration; G1-G4: explicit spin
                            matrices on 2^n dimensional Hilbert spaces.
     Edge and failure       H2-H3: malformed partitions; F1, B2,
                            A3: shapes with n rows, staircases, n = 60.

   Known kernel defect kept out of this file: HookFactor[{}] should be 1
   (S_0 is trivial, and standardTableauCount[{}] = 1 below), but
   PartitionQ rejects the empty partition, so it fails; every sweep starts
   at n = 1.
   Not covered: HookFactor accepts only partitions with integer parts, so
   families such as f^(a, b) = Binomial[a+b, b] - Binomial[a+b, b-1] are
   checked on integer tables (F2-F4) rather than as identities in symbolic
   parts.
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
conjugate[p_List] := Total[UnitStep[Outer[Subtract, p, Range[First[p]]]]]

(* Cells {i, j} of the diagram: row i, column j. *)
cells[p_List] := Catenate[MapIndexed[Thread[{First[#2], Range[#1]}] &, p]]

(* Product of hook lengths: hook(i, j) = arm + leg + 1 with
   arm = lambda_i - j and leg = lambda'_j - i. *)
hookProduct[p_List] :=
    With[{c = conjugate[p]},
        Times @@ ((p[[#1]] - #2) + (c[[#2]] - #1) + 1 & @@@ cells[p])
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
involutionCount[n_Integer] := With[{id = Range[n]}, Count[Permutations[id], perm_ /; perm[[perm]] === id]]

(* Total spin component S_a = Sum_k sigma_a^(k) / 2 on n spin-1/2 sites. *)
siteOperator[op_, k_Integer, n_Integer] :=
    KroneckerProduct @@ ReplacePart[ConstantArray[IdentityMatrix[2, SparseArray], n], k -> SparseArray[op]]

totalSpinComponent[a_Integer, n_Integer] :=
    Sum[siteOperator[PauliMatrix[a] / 2, k, n], {k, n}]

totalSpinSquared[n_Integer] := Total[With[{s = totalSpinComponent[#, n]}, s . s] & /@ {1, 2, 3}]

(* Degeneracy of the eigenvalue S(S+1) of total S^2: the dimension of the
   null space of S^2 - S(S+1). *)
spinDegeneracy[s2_, spin_] := Length[s2] - MatrixRank[s2 - spin (spin + 1) IdentityMatrix[Length[s2], SparseArray]]

(* Spin-S highest-weight vectors: S^+ v = 0 and S_z v = S v. Each spin-S
   multiplet has exactly one, so their number is the multiplicity of W_S. *)
raisingOperator[n_Integer] := totalSpinComponent[1, n] + I totalSpinComponent[2, n]

highestWeightCount[n_Integer, spin_] :=
    With[{sz = totalSpinComponent[3, n]},
        Length[sz] - MatrixRank[Join[raisingOperator[n], sz - spin IdentityMatrix[Length[sz], SparseArray]]]
    ]

(* Exchange of sites i and i+1: P = (1 + sigma^(i) . sigma^(i+1)) / 2.
   The n - 1 neighbor exchanges generate S_n. *)
siteExchange[n_Integer, i_Integer] :=
    (IdentityMatrix[2^n, SparseArray] + Total[siteOperator[PauliMatrix[#], i, n] . siteOperator[PauliMatrix[#], i + 1, n] & /@ {1, 2, 3}]) / 2

(* Two-row shape of the spin-S sector of n spin-1/2 sites. *)
spinShape[n_Integer, spin_] := DeleteCases[{n / 2 + spin, n / 2 - spin}, 0]

commutatorNorm[a_, b_] := Norm[Commutator[a, b, Dot], "Frobenius"]

(* Content product Prod_cells (d + j - i): the numerator of the hook-content
   formula dim W_lambda(d) = contentProduct / hookProduct. *)
contentProduct[p_List, d_] := Times @@ (d + #2 - #1 & @@@ cells[p])

(* Operator on (C^d)^(tensor n) that carries tensor factor k to position
   perm[[k]], built by transposing the identity map. *)
permutationOperator[d_Integer, perm_List] :=
    With[{n = Length[perm]},
        ArrayReshape[Transpose[ArrayReshape[IdentityMatrix[d^n, SparseArray], Append[ConstantArray[d, n], d^n]], Append[perm, n + 1]], {d^n, d^n}]
    ]

(* Dimension of the algebra spanned by all n! permutation operators. *)
permutationAlgebraDimension[d_Integer, n_Integer] :=
    MatrixRank[Flatten[permutationOperator[d, #]] & /@ Permutations[Range[n]]]


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

(* A3. Beyond exhaustive reach: every partition of 60 into 3 or 4 parts,
   300 seeded random partitions of 60 (5 to 45 rows), and the staircases
   {k, ..., 1} for k = 6..10 (n up to 55). *)
VerificationTest[
    Select[
        Join[
            IntegerPartitions[60, {3, 4}],
            BlockRandom[SeedRandom[1]; RandomSample[IntegerPartitions[60], 300]],
            Range[#, 1, -1] & /@ Range[6, 10]
        ],
        HookFactor[#] =!= 1 / hookProduct[#] &
    ],
    {},
    TestID -> "A3.hook_length_formula_n_60"
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
    RecurrenceTable[{i[m] == i[m - 1] + (m - 1) i[m - 2], i[0] == 1, i[1] == 1}, i, {m, 1, 20}],
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
    Union @ Flatten @ Table[hookDimension[Join[{n - k}, ConstantArray[1, k]]] - Binomial[n - 1, k], {n, 2, 25}, {k, 0, n - 1}],
    {0},
    TestID -> "F2.hook_shapes_n_le_25"
]

(* F3. Two-row shapes {n-k, k}: f = Binomial[n, k] - Binomial[n, k-1],
   the ballot numbers. *)
VerificationTest[
    Union @ Flatten @ Table[hookDimension[{n - k, k}] - (Binomial[n, k] - Binomial[n, k - 1]), {n, 2, 30}, {k, 1, Floor[n / 2]}],
    {0},
    TestID -> "F3.two_row_ballot_numbers_n_le_30"
]

(* F4. Rectangles {k, k, k} (three rows) against the three-dimensional
   ballot numbers 2 (3k)! / (k! (k+1)! (k+2)!). *)
VerificationTest[
    hookDimension[{#, #, #}] & /@ Range[12],
    With[{k = Range[12]}, 2 (3 k)! / (k! (k + 1)! (k + 2)!)],
    TestID -> "F4.three_row_rectangles"
]

(* F5. f^(m,m) is the Catalan number, whose large-m expansion
   f^(m,m) m^(3/2) Sqrt[Pi] / 4^m = 1 + c1/m + c2/m^2 + O(1/m^3)
   has its coefficients taken from Series. Exact HookFactor values at m up
   to 2000 (n = 4000) must follow it through second order: the rescaled
   residual m (m (ratio - 1) - c1) approaches c2 within 2/m (the next
   coefficient is of order 1). *)
VerificationTest[
    With[{expansion = Series[CatalanNumber[x] x^(3/2) Sqrt[Pi] / 4^x, {x, Infinity, 2}]},
        With[{c1 = SeriesCoefficient[expansion, 1], c2 = SeriesCoefficient[expansion, 2]},
            Table[
                With[{ratio = N[hookDimension[{m, m}] m^(3/2) Sqrt[Pi] / 4^m, 30]},
                    Abs[m (m (ratio - 1) - c1) - c2] < 2 / m
                ],
                {m, {250, 500, 1000, 2000}}
            ]
        ]
    ],
    {True, True, True, True},
    TestID -> "F5.catalan_asymptotics"
]


(* ============================================ *)
(* G. Schur-Weyl duality                        *)
(* ============================================ *)

(* G1. (C^2)^(tensor n) = Sum_S V_(n/2+S, n/2-S) tensor W_S, where W_S is the
   spin-S multiplet. The eigenvalue S(S+1) of total S^2 therefore has
   degeneracy (2S + 1) f^(n/2+S, n/2-S). The left side is measured on the
   explicit 2^n x 2^n spin operators for n = 2..7. *)
VerificationTest[
    Table[
        With[{s2 = totalSpinSquared[n]},
            Table[spinDegeneracy[s2, spin], {spin, n / 2, 0, -1}]
        ],
        {n, 2, 7}
    ],
    Table[(2 spin + 1) hookDimension[spinShape[n, spin]], {n, 2, 7}, {spin, n / 2, 0, -1}],
    TestID -> "G1.total_spin_degeneracies"
]

(* G2. Summed over S the multiplets fill the whole Hilbert space:
   Sum_S (2S + 1) f^(n/2+S, n/2-S) = 2^n. *)
VerificationTest[
    Table[Sum[(2 spin + 1) hookDimension[spinShape[n, spin]], {spin, n / 2, 0, -1}], {n, 1, 20}],
    2^Range[20],
    TestID -> "G2.spin_multiplets_fill_hilbert_space"
]

(* G3. The premise of Schur-Weyl duality on the spin chain: total S^2 is
   Hermitian (so the null-space counts in G1 are eigenvalue multiplicities),
   it commutes with the SU(2) raising operator and with each of the n - 1
   neighbor exchanges, which generate S_n, and every exchange squares to
   the identity. n = 2..6. *)
VerificationTest[
    Table[
        With[{s2 = totalSpinSquared[n], swaps = siteExchange[n, #] & /@ Range[n - 1]},
            {
                HermitianMatrixQ[s2],
                commutatorNorm[raisingOperator[n], s2],
                Total[commutatorNorm[#, s2] & /@ swaps],
                Total[Norm[# . # - IdentityMatrix[2^n, SparseArray], "Frobenius"] & /@ swaps]
            }
        ],
        {n, 2, 6}
    ],
    ConstantArray[{True, 0, 0, 0}, 5],
    TestID -> "G3.spin_symmetries_commute"
]

(* G4. The multiplicity space of spin S is V_(n/2+S, n/2-S) itself: the
   number of spin-S highest-weight vectors equals f^(n/2+S, n/2-S), with no
   (2S + 1) factor. n = 2..7. *)
VerificationTest[
    Table[highestWeightCount[n, spin], {n, 2, 7}, {spin, n / 2, 0, -1}],
    Table[hookDimension[spinShape[n, spin]], {n, 2, 7}, {spin, n / 2, 0, -1}],
    TestID -> "G4.highest_weight_multiplicities"
]

(* G5. At symbolic local dimension d,
   (C^d)^(tensor n) = Sum_lambda V_lambda tensor W_lambda(d) gives
   Sum_lambda f^lambda contentProduct[lambda, d] / hookProduct[lambda] = d^n
   as polynomials in d. Shapes with more rows than d contribute a content
   factor that vanishes there. The sum is linear in HookFactor, so a sign
   error on any shape survives into the polynomial. n = 1..12. *)
VerificationTest[
    Table[Expand[Sum[hookDimension[p] contentProduct[p, d] / hookProduct[p], {p, IntegerPartitions[n]}] - d^n], {n, 12}],
    ConstantArray[0, 12],
    TestID -> "G5.schur_weyl_symbolic_d"
]

(* G6. The permutation operators on (C^d)^(tensor n) represent C[S_n] as
   the direct sum of End(V_lambda) over the shapes lambda with at most d
   rows (V_lambda occurs with multiplicity dim W_lambda(d), which is zero
   exactly when lambda has more than d rows). The span of the n! operators
   therefore has dimension Sum (f^lambda)^2 over those shapes, measured
   here as a matrix rank. d = 3 reaches three-row shapes on operators;
   d = 2 drops every shape with three or more rows. n = 2..5. *)
VerificationTest[
    Table[permutationAlgebraDimension[d, n], {d, 2, 3}, {n, 2, 5}],
    Table[Total[hookDimension[#]^2 & /@ Select[IntegerPartitions[n], Length[#] <= d &]], {d, 2, 3}, {n, 2, 5}],
    TestID -> "G6.permutation_algebra_dimension"
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
