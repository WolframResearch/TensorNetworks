(* Tests/test_schur_dimension.wl

   Tests for SchurDimension and TableauWeylDimension in
   Wolfram`TensorNetworks`Symmetry`. Math/physics-grade anchors:

   A.  Hook-content formula vs the four classical closed-form identities
       (symmetric power, exterior power, Riemann {2,2}, hook-shape {3,1}).

   B.  Schur-Weyl total identity:
         Sum_{lambda |- n} dim V_lambda * dim W_lambda(d) == d^n,
       checked across n = 2..6 and d = 1..5. This is the central
       representation-theoretic identity these dimensions satisfy.

   C.  Pauli exclusion: every partition with more than d rows must vanish.

   D.  Physics decompositions for n spin-1/2 particles at d = 2:
         two-spin singlet/triplet split, three-spin spin-3/2 + 2 x spin-1/2,
         total Hilbert-space dimension reproduction.

   E.  Symbolic d: Simplify the polynomial output against the closed forms
       n(n+1)/2, Binomial[d, n], d^2(d^2-1)/12 etc.

   F.  Projector-rank cross-check: SchurDimension[par, d] equals
       MatrixRank of YoungProject as a linear map on (C^d)^otimes n.
       This is the physical content of the closed-form formula.

   G.  TableauWeylDimension agrees with SchurDimension for the underlying
       partition.

   H.  Failure paths reject malformed input.
*)

PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks"];
Needs["Wolfram`TensorNetworks`"];
Needs["Wolfram`TensorNetworks`Symmetry`"];

Needs["MUnit`"];   (* For VerificationTest *)

results = {};

addTest[id_String, test_TestResultObject] := (
    AppendTo[results, <|"id" -> id, "outcome" -> test["Outcome"], "test" -> test|>];
    test
);

addTest[id_String, body_] :=
    addTest[id, VerificationTest[body[[1]], body[[2]], TestID -> id]];

(* ============================================================ *)
(* A. Hook-content formula vs closed forms                      *)
(* ============================================================ *)

(* A1. Symmetric power dim: SchurDimension[{n}, d] = Binomial[n + d - 1, n].
   The fully symmetric partition {n} at bond dimension d enumerates
   multisets of size n from d symbols. *)
addTest["A1-symmetric-power",
    VerificationTest[
        Table[SchurDimension[{n}, d], {n, 1, 6}, {d, 1, 6}],
        Table[Binomial[n + d - 1, n], {n, 1, 6}, {d, 1, 6}],
        TestID -> "A1-symmetric-power"
    ]
];

(* A2. Exterior power dim: SchurDimension[{1,1,...,1}, d] = Binomial[d, n].
   The fully antisymmetric partition (1^n) at bond dimension d enumerates
   subsets of size n from d single-particle states. *)
addTest["A2-exterior-power",
    VerificationTest[
        Table[SchurDimension[ConstantArray[1, n], d], {n, 1, 6}, {d, 1, 6}],
        Table[Binomial[d, n], {n, 1, 6}, {d, 1, 6}],
        TestID -> "A2-exterior-power"
    ]
];

(* A3. Riemann count: SchurDimension[{2,2}, d] = d^2 (d^2 - 1) / 12.
   The {2,2} irrep at dimension d has the textbook Riemann component count. *)
addTest["A3-riemann-count",
    VerificationTest[
        Table[SchurDimension[{2, 2}, d], {d, 2, 7}],
        Table[d^2 (d^2 - 1) / 12, {d, 2, 7}],
        TestID -> "A3-riemann-count"
    ]
];

(* A4. Hook shape {3,1}: SchurDimension[{3,1}, d] = d(d-1)(d+1)(d+2)/8.
   The mixed-symmetry hook shape has a known degree-4 polynomial dim. *)
addTest["A4-hook-shape",
    VerificationTest[
        Table[SchurDimension[{3, 1}, d], {d, 2, 7}],
        Table[d (d - 1) (d + 1) (d + 2) / 8, {d, 2, 7}],
        TestID -> "A4-hook-shape"
    ]
];

(* ============================================================ *)
(* B. Schur-Weyl total identity                                 *)
(* ============================================================ *)

(* B1. Sum_{lambda |- n} dim V_lambda * dim W_lambda(d) = d^n.
   This is the central Schur-Weyl decomposition fact:
   (C^d)^otimes n = direct sum over partitions of n of V_lambda tensor
   W_lambda(d), and the dimensions agree on both sides. *)
addTest["B1-schur-weyl-total",
    VerificationTest[
        Table[
            Total[
                TableauDimension[#] * SchurDimension[#, d] & /@
                    IntegerPartitions[n]
            ],
            {n, 2, 6}, {d, 1, 5}
        ],
        Table[d^n, {n, 2, 6}, {d, 1, 5}],
        TestID -> "B1-schur-weyl-total"
    ]
];

(* ============================================================ *)
(* C. Pauli exclusion (more rows than d => zero)                *)
(* ============================================================ *)

(* C1. dim W_lambda(d) = 0 whenever Length[lambda] > d.
   The Weyl module vanishes if the diagram has more rows than the bond
   dimension. Physical content: cannot antisymmetrise more particles than
   available single-particle states. *)
addTest["C1-pauli-exclusion-explicit",
    VerificationTest[
        Map[SchurDimension[#, 2] &,
            {{1, 1, 1}, {2, 1, 1}, {1, 1, 1, 1}, {3, 1, 1}, {2, 2, 1}}],
        ConstantArray[0, 5],
        TestID -> "C1-pauli-exclusion-explicit"
    ]
];

(* C2. Universal Pauli exclusion across (n, d) sweep: every partition with
   more than d rows gives 0 at bond dimension d. *)
Module[{vanishingValues},
    vanishingValues = Flatten @ Table[
        SchurDimension[#, d] & /@
            Select[IntegerPartitions[n], Length[#] > d &],
        {n, 2, 5}, {d, 1, 3}
    ];
    addTest["C2-pauli-exclusion-sweep",
        VerificationTest[
            vanishingValues,
            ConstantArray[0, Length[vanishingValues]],
            TestID -> "C2-pauli-exclusion-sweep"
        ]
    ]
];

(* ============================================================ *)
(* D. Physics decompositions at d = 2 (spin-1/2 chains)         *)
(* ============================================================ *)

(* D1. Two spin-1/2 particles: triplet (sym, S=1, dim 3) + singlet
   (anti, S=0, dim 1) = 4 = 2^2. *)
addTest["D1-two-spin-half",
    VerificationTest[
        {SchurDimension[{2}, 2],
         SchurDimension[{1, 1}, 2],
         SchurDimension[{2}, 2] + SchurDimension[{1, 1}, 2]},
        {3, 1, 4},
        TestID -> "D1-two-spin-half"
    ]
];

(* D2. Three spin-1/2 particles: spin-3/2 quartet (dim 4) +
   two spin-1/2 doublets (each dim 2). The {2,1} block has multiplicity
   TableauDimension[{2,1}] = 2 inside V^{otimes 3}. *)
addTest["D2-three-spin-half",
    VerificationTest[
        {SchurDimension[{3}, 2],
         SchurDimension[{2, 1}, 2],
         SchurDimension[{1, 1, 1}, 2],
         TableauDimension[{3}] SchurDimension[{3}, 2] +
             TableauDimension[{2, 1}] SchurDimension[{2, 1}, 2] +
             TableauDimension[{1, 1, 1}] SchurDimension[{1, 1, 1}, 2]},
        {4, 2, 0, 8},
        TestID -> "D2-three-spin-half"
    ]
];

(* D3. Four spin-1/2 particles: total Hilbert dim 16 = 2^4.
   Partitions of 4: {4}, {3,1}, {2,2}, {2,1,1}, {1,1,1,1}.
   At d=2 the last two vanish (more rows than d).
   {4}: dim V * dim W = 1 * 5 = 5 (spin-2 quintet)
   {3,1}: dim V * dim W = 3 * 3 = 9 (three spin-1 triplets)
   {2,2}: dim V * dim W = 2 * 1 = 2 (two spin-0 singlets)
   Total: 5 + 9 + 2 + 0 + 0 = 16 = 2^4 ✓ *)
addTest["D3-four-spin-half",
    VerificationTest[
        {SchurDimension[{4}, 2],
         SchurDimension[{3, 1}, 2],
         SchurDimension[{2, 2}, 2],
         SchurDimension[{2, 1, 1}, 2],
         SchurDimension[{1, 1, 1, 1}, 2],
         Total[
             TableauDimension[#] * SchurDimension[#, 2] & /@
                 IntegerPartitions[4]
         ]},
        {5, 3, 1, 0, 0, 16},
        TestID -> "D3-four-spin-half"
    ]
];

(* ============================================================ *)
(* E. Symbolic d (closed-form polynomial agreement)             *)
(* ============================================================ *)

(* E1. Symbolic symmetric power: SchurDimension[{n}, d] = Pochhammer[d, n] / n!.
   This is the rising factorial form of the multiset count, equivalent to
   Binomial[d + n - 1, n] expanded as a polynomial in d. *)
addTest["E1-symbolic-symmetric",
    VerificationTest[
        Table[
            FullSimplify[
                SchurDimension[{n}, x] - Pochhammer[x, n] / n!
            ],
            {n, 1, 5}
        ],
        ConstantArray[0, 5],
        TestID -> "E1-symbolic-symmetric"
    ]
];

(* E2. Symbolic exterior power: SchurDimension[{1^n}, d] = Binomial[d, n].
   Polynomial form in d agrees with the falling factorial / n!. *)
addTest["E2-symbolic-exterior",
    VerificationTest[
        Table[
            FullSimplify[
                SchurDimension[ConstantArray[1, n], x] -
                    Pochhammer[x - n + 1, n] / n!
            ],
            {n, 1, 5}
        ],
        ConstantArray[0, 5],
        TestID -> "E2-symbolic-exterior"
    ]
];

(* E3. Symbolic Riemann: SchurDimension[{2,2}, d] = d^2 (d^2 - 1) / 12. *)
addTest["E3-symbolic-riemann",
    VerificationTest[
        FullSimplify[
            SchurDimension[{2, 2}, x] - x^2 (x^2 - 1) / 12
        ],
        0,
        TestID -> "E3-symbolic-riemann"
    ]
];

(* E4. Polynomial degree: SchurDimension[par, d] has total degree Total[par]
   in d (one factor (d + j - i) per cell of the diagram). *)
addTest["E4-polynomial-degree",
    VerificationTest[
        Table[
            Exponent[SchurDimension[par, x] // Expand, x],
            {par, IntegerPartitions[5]}
        ],
        ConstantArray[5, Length[IntegerPartitions[5]]],
        TestID -> "E4-polynomial-degree"
    ]
];

(* E5. Schur-Weyl total identity holds polynomially in d.
   The closed-form identity sum_lambda dim V_lambda * dim W_lambda(d) = d^n
   should reduce to 0 = 0 after simplification. *)
addTest["E5-symbolic-schur-weyl",
    VerificationTest[
        Table[
            FullSimplify[
                Total[
                    TableauDimension[#] * SchurDimension[#, x] & /@
                        IntegerPartitions[n]
                ] - x^n
            ],
            {n, 2, 5}
        ],
        ConstantArray[0, 4],
        TestID -> "E5-symbolic-schur-weyl"
    ]
];

(* ============================================================ *)
(* F. Projector-rank cross-check                                *)
(* ============================================================ *)

(* For a single Young tableau, the rank of YoungProject as a linear map
   on (C^d)^otimes n equals dim W_lambda(d). The closed form
   SchurDimension[par, d] must match the numerical rank computation. *)
projectorRank[tab_YoungTableau, d_] := Module[{n = TableauSize[tab]},
    MatrixRank @ Transpose @ Map[
        Flatten[YoungProject[
            ArrayReshape[#, ConstantArray[d, n]],
            tab
        ]] &,
        IdentityMatrix[d^n]
    ]
];

(* F1. Rank-2: {2} and {1,1} at d in {2, 3, 4}. *)
addTest["F1-projector-rank-2",
    VerificationTest[
        Table[
            {projectorRank[YoungTableau[{2}], d],
             projectorRank[YoungTableau[{1, 1}], d]},
            {d, 2, 4}
        ],
        Table[
            {SchurDimension[{2}, d], SchurDimension[{1, 1}, d]},
            {d, 2, 4}
        ],
        TestID -> "F1-projector-rank-2"
    ]
];

(* F2. Rank-3: all three irreps at d=3. *)
addTest["F2-projector-rank-3-at-d3",
    VerificationTest[
        {projectorRank[YoungTableau[{{1, 2, 3}}], 3],
         projectorRank[YoungTableau[{{1, 2}, {3}}], 3],
         projectorRank[YoungTableau[{{1}, {2}, {3}}], 3]},
        {SchurDimension[{3}, 3],
         SchurDimension[{2, 1}, 3],
         SchurDimension[{1, 1, 1}, 3]},
        TestID -> "F2-projector-rank-3-at-d3"
    ]
];

(* F3. Rank-4 Riemann tableau at d=3 and d=4 (textbook count). *)
addTest["F3-projector-rank-riemann",
    VerificationTest[
        {projectorRank[YoungTableau[{{1, 3}, {2, 4}}], 3],
         projectorRank[YoungTableau[{{1, 3}, {2, 4}}], 4]},
        {SchurDimension[{2, 2}, 3],
         SchurDimension[{2, 2}, 4]},
        TestID -> "F3-projector-rank-riemann"
    ]
];

(* ============================================================ *)
(* G. TableauWeylDimension agreement                            *)
(* ============================================================ *)

(* G1. Tableau-keyed companion delegates to SchurDimension.
   Test over all partitions of n = 2..5 at d = 4. *)
addTest["G1-tableau-companion",
    VerificationTest[
        Flatten @ Table[
            With[{par = #, tab = YoungTableau[#]},
                TableauWeylDimension[tab, 4] - SchurDimension[par, 4]
            ] & /@ IntegerPartitions[n],
            {n, 2, 5}
        ],
        ConstantArray[0,
            Length[Flatten[IntegerPartitions /@ Range[2, 5], 1]]],
        TestID -> "G1-tableau-companion"
    ]
];

(* G2. TableauWeylDimension also agrees with SchurDimension when passed
   a YoungTableau directly (the partition / tableau overloads agree). *)
addTest["G2-overload-agreement",
    VerificationTest[
        Table[
            TableauWeylDimension[YoungTableau[par], d] -
                SchurDimension[YoungTableau[par], d],
            {par, {{1}, {2}, {2, 1}, {2, 2}, {3, 1}, {2, 1, 1}}},
            {d, 2, 5}
        ] // Flatten,
        ConstantArray[0, 24],
        TestID -> "G2-overload-agreement"
    ]
];

(* G3. Symbolic-d agreement also holds at the YoungTableau interface. *)
addTest["G3-tableau-symbolic",
    VerificationTest[
        FullSimplify[
            TableauWeylDimension[YoungTableau[{2, 2}], x] -
                x^2 (x^2 - 1) / 12
        ],
        0,
        TestID -> "G3-tableau-symbolic"
    ]
];

(* ============================================================ *)
(* H. Failure paths                                             *)
(* ============================================================ *)

(* H1. SchurDimension rejects non-partition input. *)
addTest["H1-fail-non-partition",
    VerificationTest[
        Quiet[SchurDimension["not a partition", 4]],
        $Failed,
        TestID -> "H1-fail-non-partition"
    ]
];

(* H2. SchurDimension rejects partitions with zero or negative entries. *)
addTest["H2-fail-bad-partition-zero",
    VerificationTest[
        Quiet[SchurDimension[{2, 0}, 3]],
        $Failed,
        TestID -> "H2-fail-bad-partition-zero"
    ]
];

addTest["H3-fail-bad-partition-negative",
    VerificationTest[
        Quiet[SchurDimension[{2, -1}, 3]],
        $Failed,
        TestID -> "H3-fail-bad-partition-negative"
    ]
];

(* H4. SchurDimension rejects non-decreasing partitions. *)
addTest["H4-fail-bad-partition-order",
    VerificationTest[
        Quiet[SchurDimension[{1, 2}, 3]],
        $Failed,
        TestID -> "H4-fail-bad-partition-order"
    ]
];

(* H5. TableauWeylDimension rejects non-YoungTableau input. *)
addTest["H5-fail-non-tableau",
    VerificationTest[
        Quiet[TableauWeylDimension[42, 3]],
        $Failed,
        TestID -> "H5-fail-non-tableau"
    ]
];

(* H6. TableauWeylDimension rejects partition input (must be a tableau). *)
addTest["H6-fail-partition-not-tableau",
    VerificationTest[
        Quiet[TableauWeylDimension[{2, 2}, 3]],
        $Failed,
        TestID -> "H6-fail-partition-not-tableau"
    ]
];

(* ============================================================ *)
(* Summary                                                      *)
(* ============================================================ *)

passes = Count[results, KeyValuePattern["outcome" -> "Success"]];
failures = Count[results, KeyValuePattern["outcome" -> Except["Success"]]];

Print[StringRepeat["=", 60]];
Print["SchurDimension / TableauWeylDimension tests"];
Print["  passes: ", passes, " / ", Length[results]];
Print["  failures: ", failures];
Print[StringRepeat["=", 60]];

If[failures > 0,
    Print["Failed tests:"];
    Do[
        If[r["outcome"] =!= "Success",
            Print["  ", r["id"], "  outcome=", r["outcome"]];
        ],
        {r, results}
    ];
    Exit[1];
];

Print["All ", Length[results], " tests passed."];
