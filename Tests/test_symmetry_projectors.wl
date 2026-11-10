(* Tests/test_symmetry_projectors.wl

   Young symmetrizers and Young projectors on rank-n tensors at n = 5 and
   n = 6, against operators built here from the symmetric group itself.

   For a tableau T with rows R_1, R_2, ... and columns C_1, C_2, ... the row
   group R(T) permutes slots within each row and the column group C(T)
   permutes slots within each column. The documented operators are

       YoungSymmetrize[t, T] = Sum_{q in C(T)} sgn(q) q ( Sum_{p in R(T)} p t )
       YoungProject[t, T]    = (f^lambda / n!) YoungSymmetrize[t, T]

   (rows first, then columns), with f^lambda the number of standard
   tableaux of the shape lambda. A permutation acts on a tensor by moving
   its slots, Transpose[t, perm]; both group sums are closed under
   inverses, so the direction of that action does not matter here.

   The isotypic projector of the shape lambda on (C^d)^(tensor n) is the
   character sum

       P_lambda = (f^lambda / n!) Sum_{g in S_n} chi^lambda(g) g,

   with chi^lambda taken from the Frobenius formula (coefficient of
   x^(lambda + delta) in a_delta p_mu), never from the paclet. Summing the
   Young projectors over the standard tableaux of lambda is not P_lambda:
   it overcounts from n = 5 on (shape {3,2}), and at n = 6 on {4,2} and
   {3,3}. What does hold is that every Young projector of shape lambda maps
   into the range of P_lambda, and the images of the standard-tableau
   projectors span that whole range, so the orthogonal projector
   M . PseudoInverse[M] onto the column space of M = (e_T1 | e_T2 | ...)
   equals P_lambda.

   A.  YoungSymmetrize against the explicit row and column group sums, for
       every standard tableau at n = 5 (d = 3) and n = 6 (d = 2), for
       {4,2}, {3,3}, {3,2,1}, {2,2,1,1} at n = 6 with d = 3, and for
       fillings that are not standard.
   B.  YoungProject = (f^lambda / n!) times that sum, f^lambda counted by
       enumerating standard tableaux.
   C.  Idempotency, and orthogonality between Young projectors of
       different shapes.
   D.  The character projectors: they sum to the identity, every Young
       projector of shape lambda lands in the range of P_lambda and is
       killed by every other P_mu, and M . PseudoInverse[M] = P_lambda.
   E.  Ranks and traces against the hook-content formula
       dim W_lambda(d) = Prod (d + j - i) / hook(i, j), computed here.
   F.  Rank-2 closed forms and the rank-mismatch failure.

   Not covered: the documentation statement that the Young projectors over
   all standard tableaux of every shape sum to the identity on rank-n
   tensors. That holds for n <= 4 only; at n = 5 the sum differs from the
   identity already on (C^2)^(tensor 5), so no correct kernel satisfies it.
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];
Needs["Wolfram`TensorNetworks`Symmetry`"];


(* ============================================ *)
(* Independent references                       *)
(* ============================================ *)

(* Columns of a row layout: column j holds the j-th entry of every row
   that reaches position j. *)
spColumns[rows_List] := Table[Cases[rows, r_ /; Length[r] >= j :> r[[j]]], {j, Max[Length /@ rows]}]

(* Every permutation of Range[n] that maps each block to itself, as the
   image list perm with perm[[k]] the image of slot k. *)
spBlockGroup[blocks_List, n_Integer] :=
    Map[
        Function[images, ReplacePart[Range[n], Thread[Catenate[blocks] -> Catenate[images]]]],
        Tuples[Permutations /@ blocks]
    ]

(* Sum_{q in C(T)} sgn(q) q (Sum_{p in R(T)} p t), straight from the groups. *)
spYoungBrute[t_, rows_List] :=
    With[{n = ArrayDepth[t]},
        With[{rowSum = Total[Transpose[t, #] & /@ spBlockGroup[rows, n]]},
            Total[Signature[#] Transpose[rowSum, #] & /@ spBlockGroup[spColumns[rows], n]]
        ]
    ]

(* Standard tableaux of a shape, by filtering all fillings for rows and
   columns that increase. *)
spStandardRows[shape_List] :=
    Select[
        TakeList[#, shape] & /@ Permutations[Range[Total[shape]]],
        AllTrue[Join[#, spColumns[#]], OrderedQ[#, Less] &] &
    ]

spSYTCount[shape_List] := spSYTCount[shape] = Length[spStandardRows[shape]]

(* Hook-content formula for dim W_lambda(d). *)
spConjugate[p_List] := Table[Count[p, x_ /; x >= j], {j, First[p]}]

spWeylDimension[p_List, d_] :=
    With[{c = spConjugate[p]},
        Product[(d + j - i) / ((p[[i]] - j) + (c[[j]] - i) + 1), {i, Length[p]}, {j, p[[i]]}]
    ]

(* Frobenius formula: chi^lambda(mu) is the coefficient of
   x^(lambda + delta) in Prod_{i<j} (x_i - x_j) Prod_k p_(mu_k)(x). *)
spCharacter[lambda_List, mu_List] := spCharacter[lambda, mu] =
    With[{r = Length[lambda], x = Array[spX, Length[lambda]]},
        Coefficient[
            Expand[
                Times @@ Catenate[Table[x[[i]] - x[[j]], {i, r}, {j, i + 1, r}]] *
                    Times @@ (Total[x^#] & /@ mu)
            ],
            Times @@ (x^(lambda + r - Range[r]))
        ]
    ]

spCycleType[perm_List] :=
    With[{c = Length /@ First[PermutationCycles[perm]]},
        Sort[Join[c, ConstantArray[1, Length[perm] - Total[c]]], Greater]
    ]

(* Matrix of t -> Transpose[t, perm] on (C^d)^(tensor n), acting on
   Flatten[t]. *)
spPermutationMatrix[d_Integer, perm_List] :=
    With[{n = Length[perm]},
        ArrayReshape[
            Transpose[ArrayReshape[IdentityMatrix[d^n, SparseArray], Append[ConstantArray[d, n], d^n]], Append[perm, n + 1]],
            {d^n, d^n}
        ]
    ]

spIsotypic[lambda_List, d_Integer] := spIsotypic[lambda, d] =
    With[{n = Total[lambda]},
        spSYTCount[lambda] / n! Total[spCharacter[lambda, spCycleType[#]] spPermutationMatrix[d, #] & /@ Permutations[Range[n]]]
    ]

spRandomTensor[d_Integer, n_Integer, seed_Integer] :=
    BlockRandom[SeedRandom[seed]; RandomInteger[{-4, 4}, ConstantArray[d, n]]]

(* Matrix of t -> YoungProject[t, T] on (C^d)^(tensor n), column by column. *)
spProjectMatrix[rows_List, d_Integer] :=
    With[{n = Total[Length /@ rows]},
        Transpose[Flatten[YoungProject[ArrayReshape[UnitVector[d^n, #], ConstantArray[d, n]], YoungTableau[rows]]] & /@ Range[d^n]]
    ]

(* Rank of t -> YoungProject[t, T] measured on 2 dim W + 4 random tensors:
   their images span the range (the measured rank can only fall short of
   the true rank, never exceed it). *)
spImageRank[rows_List, d_Integer, seed_Integer] :=
    With[{n = Total[Length /@ rows], k = 2 spWeylDimension[Length /@ rows, d] + 4},
        MatrixRank[Flatten[YoungProject[spRandomTensor[d, n, seed + #], YoungTableau[rows]]] & /@ Range[k]]
    ]

(* Layouts for the sweeps: canonical and other standard fillings, plus
   fillings that are not standard (row order inside a row is meaningful). *)
spShapes6 = {{4, 2}, {3, 3}, {3, 2, 1}, {2, 2, 1, 1}};

spNonStandard = {
    {{1, 2, 3}, {5, 4}},
    {{5, 3, 1}, {2, 4}},
    {{2, 6, 4, 1}, {5, 3}},
    {{6, 5, 4}, {3, 2, 1}},
    {{3, 1, 6}, {4, 5}, {2}}
};


(* ============================================ *)
(* A. YoungSymmetrize against group sums         *)
(* ============================================ *)

(* A1. Every standard tableau of every shape of 5 (26 tableaux), on a
   random integer tensor of dimension 3. Lists the tableaux that disagree. *)
VerificationTest[
    With[{t = spRandomTensor[3, 5, 11]},
        Select[Catenate[spStandardRows /@ IntegerPartitions[5]], YoungSymmetrize[t, YoungTableau[#]] =!= spYoungBrute[t, #] &]
    ],
    {},
    TestID -> "SymProj_A1_symmetrize_all_SYT_n5_d3"
]

(* A2. Every standard tableau of every shape of 6 (76 tableaux), d = 2. *)
VerificationTest[
    With[{t = spRandomTensor[2, 6, 12]},
        Select[Catenate[spStandardRows /@ IntegerPartitions[6]], YoungSymmetrize[t, YoungTableau[#]] =!= spYoungBrute[t, #] &]
    ],
    {},
    TestID -> "SymProj_A2_symmetrize_all_SYT_n6_d2"
]

(* A3. n = 6 with d = 3 (729 entries): every standard tableau of {4,2},
   {3,3}, {3,2,1} and {2,2,1,1}. *)
VerificationTest[
    With[{t = spRandomTensor[3, 6, 13]},
        Select[Catenate[spStandardRows /@ spShapes6], YoungSymmetrize[t, YoungTableau[#]] =!= spYoungBrute[t, #] &]
    ],
    {},
    TestID -> "SymProj_A3_symmetrize_n6_d3_two_and_three_rows"
]

(* A4. Fillings that are not standard tableaux: the row and column groups
   are read off the layout as given. *)
VerificationTest[
    Select[spNonStandard,
        With[{t = spRandomTensor[3, Total[Length /@ #], 14]}, YoungSymmetrize[t, YoungTableau[#]] =!= spYoungBrute[t, #]] &
    ],
    {},
    TestID -> "SymProj_A4_symmetrize_nonstandard_fillings"
]


(* ============================================ *)
(* B. YoungProject normalization                *)
(* ============================================ *)

(* B1. YoungProject = (f^lambda / n!) times the group sum, with f^lambda
   the enumerated number of standard tableaux, for the canonical tableau
   of every shape of 5 and 6 (d = 3 at n = 5, d = 2 at n = 6). *)
VerificationTest[
    Select[
        Join[
            {#, 3} & /@ IntegerPartitions[5],
            {#, 2} & /@ IntegerPartitions[6]
        ],
        Function[{shape, d}, With[{rows = TakeList[Range[Total[shape]], shape], t = spRandomTensor[d, Total[shape], 21]},
            YoungProject[t, YoungTableau[rows]] =!= spSYTCount[shape] / Total[shape]! spYoungBrute[t, rows]
        ]] @@ # &
    ],
    {},
    TestID -> "SymProj_B1_project_normalization_n5_n6"
]

(* B2. The same at n = 6, d = 3 on every standard tableau of {4,2} and
   {3,3} and on the non-standard fillings. *)
VerificationTest[
    Select[
        Join[Catenate[spStandardRows /@ {{4, 2}, {3, 3}}], spNonStandard],
        With[{t = spRandomTensor[3, Total[Length /@ #], 22], shape = Length /@ #},
            YoungProject[t, YoungTableau[#]] =!= spSYTCount[shape] / Total[shape]! spYoungBrute[t, #]
        ] &
    ],
    {},
    TestID -> "SymProj_B2_project_normalization_n6_d3"
]


(* ============================================ *)
(* C. Idempotency and orthogonality             *)
(* ============================================ *)

(* C1. e_T e_T = e_T exactly on a random tensor: every standard tableau at
   n = 5 (d = 3), every standard tableau of {4,2} and {3,3} at n = 6
   (d = 3), and the non-standard fillings. *)
VerificationTest[
    Select[
        Join[
            {#, 3} & /@ Catenate[spStandardRows /@ IntegerPartitions[5]],
            {#, 3} & /@ Catenate[spStandardRows /@ {{4, 2}, {3, 3}}],
            {#, 3} & /@ spNonStandard
        ],
        Function[{rows, d}, With[{t = spRandomTensor[d, Total[Length /@ rows], 31], yt = YoungTableau[rows]},
            YoungProject[YoungProject[t, yt], yt] =!= YoungProject[t, yt]
        ]] @@ # &
    ],
    {},
    TestID -> "SymProj_C1_idempotent"
]

(* C2. On (C^3)^(tensor 6) the projector does not vanish on a random
   tensor for shapes with at most 3 rows, so C1 and D2 are not satisfied
   by a zero operator; for {2,2,1,1} (four rows, more than d) it vanishes,
   since a column of length 4 antisymmetrizes over only 3 values. Lists
   the tableaux that break this. *)
VerificationTest[
    With[{t = spRandomTensor[3, 6, 32]},
        Select[Catenate[spStandardRows /@ spShapes6],
            (YoungProject[t, YoungTableau[#]] === ConstantArray[0, ConstantArray[3, 6]]) =!= (Length[#] > 3) &
        ]
    ],
    {},
    TestID -> "SymProj_C2_nonzero_on_random_tensor"
]

(* C3. Young projectors of different shapes are orthogonal: e_S e_T = 0
   when shape(S) != shape(T). Canonical tableaux of every pair of distinct
   shapes, n = 5 with d = 3 and n = 6 with d = 2. *)
VerificationTest[
    Select[
        Join[
            {#, 3} & /@ Permutations[IntegerPartitions[5], {2}],
            {#, 2} & /@ Permutations[IntegerPartitions[6], {2}]
        ],
        Function[{pair, d}, With[{
            t = spRandomTensor[d, Total[First[pair]], 33],
            ytS = YoungTableau[First[pair]], ytT = YoungTableau[Last[pair]]
        },
            Union[Flatten[YoungProject[YoungProject[t, ytT], ytS]]] =!= {0}
        ]] @@ # &
    ],
    {},
    TestID -> "SymProj_C3_orthogonal_across_shapes"
]


(* ============================================ *)
(* D. Character projectors                      *)
(* ============================================ *)

(* D1. Reference check of the character sums: Sum_lambda P_lambda = 1,
   and each P_lambda is an orthogonal projector, at n = 5 (d = 3) and
   n = 6 (d = 2). *)
VerificationTest[
    {
        Total[spIsotypic[#, 3] & /@ IntegerPartitions[5]] == IdentityMatrix[243],
        Total[spIsotypic[#, 2] & /@ IntegerPartitions[6]] == IdentityMatrix[64],
        AllTrue[IntegerPartitions[5], With[{p = spIsotypic[#, 3]}, p . p == p && Transpose[p] == p] &],
        AllTrue[IntegerPartitions[6], With[{p = spIsotypic[#, 2]}, p . p == p && Transpose[p] == p] &]
    },
    {True, True, True, True},
    TestID -> "SymProj_D1_character_projectors_resolve_identity"
]

(* D2. For T of shape lambda, P_lambda e_T t = e_T t and P_mu e_T t = 0 for
   every other shape mu. Every standard tableau at n = 5 (d = 3) and every
   standard tableau of {4,2} and {3,3} at n = 6 (d = 3). Lists failures as
   {rows, mu}. *)
VerificationTest[
    Catenate @ Map[
        Function[rows, With[{
            n = Total[Length /@ rows],
            image = Flatten[YoungProject[spRandomTensor[3, Total[Length /@ rows], 41], YoungTableau[rows]]]
        },
            {rows, #} & /@ Select[IntegerPartitions[n],
                spIsotypic[#, 3] . image =!= If[# === Length /@ rows, image, ConstantArray[0, 3^n]] &
            ]
        ]],
        Join[Catenate[spStandardRows /@ IntegerPartitions[5]], Catenate[spStandardRows /@ {{4, 2}, {3, 3}}]]
    ],
    {},
    TestID -> "SymProj_D2_young_projector_inside_isotypic_block"
]

(* D3. The images of the standard-tableau projectors of lambda span the
   lambda-isotypic block: with M the columns of all e_T over standard T of
   shape lambda, M . PseudoInverse[M] = P_lambda. Every shape of 5 and 6,
   d = 2, exact rationals. The shapes {3,2}, {4,2}, {3,3} are those where
   the plain sum of the e_T is not P_lambda. *)
VerificationTest[
    Select[
        Join[IntegerPartitions[5], IntegerPartitions[6]],
        With[{m = Join[##, 2] & @@ (spProjectMatrix[#, 2] & /@ spStandardRows[#])},
            m . PseudoInverse[m] != spIsotypic[#, 2]
        ] &
    ],
    {},
    TestID -> "SymProj_D3_span_of_SYT_projectors_is_isotypic_block"
]


(* ============================================ *)
(* E. Ranks and traces                          *)
(* ============================================ *)

(* E1. On (C^2)^(tensor 6) the full matrix of every standard-tableau
   projector has rank and trace dim W_lambda(2) (trace = rank for an
   idempotent), and SchurDimension reports the same number. *)
VerificationTest[
    Select[
        Catenate[spStandardRows /@ IntegerPartitions[6]],
        With[{m = spProjectMatrix[#, 2], w = spWeylDimension[Length /@ #, 2]},
            {MatrixRank[m], Tr[m], SchurDimension[Length /@ #, 2]} =!= {w, w, w}
        ] &
    ],
    {},
    TestID -> "SymProj_E1_rank_and_trace_n6_d2"
]

(* E2. At d = 3 the rank is measured on random images: canonical tableaux
   of every shape of 5, and every standard tableau of {4,2}, {3,3},
   {3,2,1}, {2,2,1,1}. *)
VerificationTest[
    Select[
        Join[TakeList[Range[5], #] & /@ IntegerPartitions[5], Catenate[spStandardRows /@ spShapes6]],
        spImageRank[#, 3, 50] =!= spWeylDimension[Length /@ #, 3] &
    ],
    {},
    TestID -> "SymProj_E2_rank_n5_n6_d3"
]

(* E3. rank P_lambda = f^lambda dim W_lambda(d), and SchurDimension
   matches dim W_lambda(d), for every shape of 5 and 6 at d = 2 and 3. *)
VerificationTest[
    Select[
        Join[Tuples[{IntegerPartitions[5], {2, 3}}], Tuples[{IntegerPartitions[6], {2}}], Tuples[{spShapes6, {3}}]],
        Function[{shape, d},
            {MatrixRank[spIsotypic[shape, d]], SchurDimension[shape, d]} =!=
                {spSYTCount[shape] spWeylDimension[shape, d], spWeylDimension[shape, d]}
        ] @@ # &
    ],
    {},
    TestID -> "SymProj_E3_isotypic_rank_and_schur_dimension"
]


(* ============================================ *)
(* F. Closed forms and failures                 *)
(* ============================================ *)

(* F1. Rank 2: {2} gives t + t^T, {1,1} gives t - t^T; YoungProject halves
   both and the two parts add back to t. Symbolic entries. *)
VerificationTest[
    With[{t = Array[Subscript[spA, ##] &, {3, 3}]},
        {
            Expand[YoungSymmetrize[t, YoungTableau[{2}]] - (t + Transpose[t])],
            Expand[YoungSymmetrize[t, YoungTableau[{1, 1}]] - (t - Transpose[t])],
            Expand[YoungProject[t, YoungTableau[{2}]] + YoungProject[t, YoungTableau[{1, 1}]] - t]
        }
    ],
    ConstantArray[0, {3, 3, 3}],
    TestID -> "SymProj_F1_rank2_closed_forms"
]

(* F2. A tensor whose rank differs from the tableau size fails. *)
VerificationTest[
    YoungProject[spRandomTensor[2, 4, 60], YoungTableau[{3, 2}]],
    $Failed,
    {YoungSymmetrize::rank},
    TestID -> "SymProj_F2_rank_mismatch"
]
