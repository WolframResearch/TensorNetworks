(* Tests/external_validation/paclet_primitives/symmetry_textbook_reference.wl

Textbook-reference and physics-motif coverage for
Wolfram`TensorNetworks`Symmetry. Each block targets a class of test the
prior suite (symmetry_basic.wl + fuzz_young_projector.wl) was structurally
blind to:

  A. Direct comparison against a brute-force enumeration of
     c_T = sum_{q in Q_T} sgn(q) q . sum_{p in P_T} p
     (Sagan, "The Symmetric Group" 2e, thm 2.6.5; Fulton & Harris,
     "Representation Theory", Lec 4).

  B. Same comparison on tableaux whose columns end up in non-sorted slot
     order. The partition-form constructor YoungTableau[{n,m,...}] never
     produces these, so they are not reachable through the prior tests.

  C. Presentation invariance: tableaux that have the same row sets and
     same column sets define the same Young projector (independent of
     presentation order). The cleanest test is a swap of two rows of
     equal length, which preserves both partitions.

  D. Physics motif. The {{1,3},{2,4}} tableau picks out the Riemann
     irrep of S_4 in V^4. The projected tensor must satisfy:
       R_{abcd} = -R_{bacd}                 (anti, first pair)
       R_{abcd} = -R_{abdc}                 (anti, second pair)
       R_{abcd} =  R_{cdab}                 (pair exchange)
       R_{abcd} +  R_{acdb} + R_{adbc} = 0  (first Bianchi)
     (e.g., Misner-Thorne-Wheeler "Gravitation" Box 13.2; Wald
      "General Relativity" eq. 3.2.13.)

These tests are paclet-primitive (every assertion calls a
Wolfram`TensorNetworks`Symmetry symbol) and live in paclet_primitives/.
*)

Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "..", "Helpers", "ValidationHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}],
        FileNameJoin[{Directory[], "external_validation", "Helpers", "ValidationHelpers.wl"}],
        FileNameJoin[{Directory[], "Helpers", "ValidationHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed,
        Print["[paclet-symmetry-tb] ERROR: cannot locate ValidationHelpers.wl"]; Abort[];
    ];
    Get[found];
];
ClearValidationRecords[];


(* ============================================================ *)
(* Brute-force textbook reference                               *)
(* ============================================================ *)

(* Columns of a tableau (handles ragged rows). *)
$columnsOf[rows_List] :=
    DeleteCases[#, _Missing] & /@ Transpose[PadRight[rows, Automatic, Missing[]]]

(* Textbook formula c_T(T) applied to a tensor of compatible rank.

   Sign convention: each column permutation contributes
       Signature[choice] * Signature[slots]
   so that the identity choice (choice === slots) always contributes +1,
   independent of whether `slots` is sorted. This matches the standard
   Sagan/Fulton-Harris definition where the sign is the parity of the
   permutation taking the column's original ordering to `choice`. *)

$referenceYoungSymmetrize[tensor_, YoungTableau[rows_List]] := Module[
    {cols, n, rowPerms, colPerms, withRows},
    n = Total[Length /@ rows];
    cols = $columnsOf[rows];
    rowPerms = Tuples[Permutations /@ rows];
    withRows = Total[
        Function[rowChoice,
            Module[{perm = Range[n]},
                MapThread[Function[{slots, choice}, perm[[slots]] = choice], {rows, rowChoice}];
                Transpose[tensor, perm]
            ]
        ] /@ rowPerms
    ];
    colPerms = Tuples[Permutations /@ cols];
    Total[
        Function[colChoice,
            Module[{perm = Range[n], sgn},
                sgn = Times @@ MapThread[
                    Function[{slots, choice}, Signature[choice] Signature[slots]],
                    {cols, colChoice}
                ];
                MapThread[Function[{slots, choice}, perm[[slots]] = choice], {cols, colChoice}];
                sgn Transpose[withRows, perm]
            ]
        ] /@ colPerms
    ]
]


(* Exact-integer tensors with distinguishable entries — SameQ comparisons
   stay tight (no floating-point slack). *)

$T2 = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}};
$T3 = Array[(100 #1 + 10 #2 + #3) &, {3, 3, 3}];
$T4 = Array[(1000 #1 + 100 #2 + 10 #3 + #4) &, {3, 3, 3, 3}];
$T5 = Array[(10000 #1 + 1000 #2 + 100 #3 + 10 #4 + #5) &, {2, 2, 2, 2, 2}];
$T6 = Array[(100000 #1 + 10000 #2 + 1000 #3 + 100 #4 + 10 #5 + #6) &, {2, 2, 2, 2, 2, 2}];
$T7 = Array[
    (10^6 #1 + 10^5 #2 + 10^4 #3 + 10^3 #4 + 100 #5 + 10 #6 + #7) &,
    {2, 2, 2, 2, 2, 2, 2}
];


(* ============================================================ *)
(* A. Reference parity on standard tableaux                     *)
(* ============================================================ *)

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-A1-standard-sym-rank2",
    "Sagan 'Symmetric Group' 2e thm 2.6.5; Fulton-Harris Lec 4",
    VerificationTest[
        YoungSymmetrize[$T2, YoungTableau[{{1, 2}}]] ===
            $referenceYoungSymmetrize[$T2, YoungTableau[{{1, 2}}]],
        True,
        TestID -> "paclet-symmetry-tb-A1-standard-sym-rank2"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-A2-standard-anti-rank2",
    "Sagan 'Symmetric Group' 2e thm 2.6.5; Fulton-Harris Lec 4",
    VerificationTest[
        YoungSymmetrize[$T2, YoungTableau[{{1}, {2}}]] ===
            $referenceYoungSymmetrize[$T2, YoungTableau[{{1}, {2}}]],
        True,
        TestID -> "paclet-symmetry-tb-A2-standard-anti-rank2"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-A3-standard-mixed-rank3",
    "Sagan 'Symmetric Group' 2e thm 2.6.5; Fulton-Harris Lec 4",
    VerificationTest[
        YoungSymmetrize[$T3, YoungTableau[{{1, 2}, {3}}]] ===
            $referenceYoungSymmetrize[$T3, YoungTableau[{{1, 2}, {3}}]],
        True,
        TestID -> "paclet-symmetry-tb-A3-standard-mixed-rank3"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-A4-standard-square-rank4",
    "Sagan 'Symmetric Group' 2e thm 2.6.5; Fulton-Harris Lec 4",
    VerificationTest[
        YoungSymmetrize[$T4, YoungTableau[{{1, 2}, {3, 4}}]] ===
            $referenceYoungSymmetrize[$T4, YoungTableau[{{1, 2}, {3, 4}}]],
        True,
        TestID -> "paclet-symmetry-tb-A4-standard-square-rank4"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-A5-standard-hook-rank4",
    "Sagan 'Symmetric Group' 2e thm 2.6.5; Fulton-Harris Lec 4",
    VerificationTest[
        YoungSymmetrize[$T4, YoungTableau[{{1, 2, 3}, {4}}]] ===
            $referenceYoungSymmetrize[$T4, YoungTableau[{{1, 2, 3}, {4}}]],
        True,
        TestID -> "paclet-symmetry-tb-A5-standard-hook-rank4"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-A6-standard-321",
    "Sagan 'Symmetric Group' 2e thm 2.6.5; Fulton-Harris Lec 4",
    VerificationTest[
        YoungSymmetrize[$T6, YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]] ===
            $referenceYoungSymmetrize[$T6, YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]],
        True,
        TestID -> "paclet-symmetry-tb-A6-standard-321"
    ]
];


(* ============================================================ *)
(* B. Reference parity on non-standard slot orderings           *)
(*    (the equivalence class the partition-form constructor    *)
(*    never reaches; the regime of the formerly hidden sign     *)
(*    bug.)                                                     *)
(* ============================================================ *)

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-B1-nonsorted-cols-rank3",
    "Non-sorted-column tableau {{2,3},{1}}; Sagan thm 2.6.5",
    VerificationTest[
        YoungSymmetrize[$T3, YoungTableau[{{2, 3}, {1}}]] ===
            $referenceYoungSymmetrize[$T3, YoungTableau[{{2, 3}, {1}}]],
        True,
        TestID -> "paclet-symmetry-tb-B1-nonsorted-cols-rank3"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-B2-riemann-tableau-rank4",
    "Riemann-shape tableau {{1,3},{2,4}}; Sagan thm 2.6.5",
    VerificationTest[
        YoungSymmetrize[$T4, YoungTableau[{{1, 3}, {2, 4}}]] ===
            $referenceYoungSymmetrize[$T4, YoungTableau[{{1, 3}, {2, 4}}]],
        True,
        TestID -> "paclet-symmetry-tb-B2-riemann-tableau-rank4"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-B3-nonsorted-rank4",
    "Non-sorted-column tableau {{1,4},{2,3}}; Sagan thm 2.6.5",
    VerificationTest[
        YoungSymmetrize[$T4, YoungTableau[{{1, 4}, {2, 3}}]] ===
            $referenceYoungSymmetrize[$T4, YoungTableau[{{1, 4}, {2, 3}}]],
        True,
        TestID -> "paclet-symmetry-tb-B3-nonsorted-rank4"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-B4-nonsorted-ragged",
    "Non-sorted ragged tableau {{4,2,1},{3}}; Sagan thm 2.6.5",
    VerificationTest[
        YoungSymmetrize[$T4, YoungTableau[{{4, 2, 1}, {3}}]] ===
            $referenceYoungSymmetrize[$T4, YoungTableau[{{4, 2, 1}, {3}}]],
        True,
        TestID -> "paclet-symmetry-tb-B4-nonsorted-ragged"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-B5-nonsorted-rank7",
    "Non-sorted column tableau {{5,6,7},{3,4},{1,2}}; Sagan thm 2.6.5",
    VerificationTest[
        YoungSymmetrize[$T7, YoungTableau[{{5, 6, 7}, {3, 4}, {1, 2}}]] ===
            $referenceYoungSymmetrize[$T7, YoungTableau[{{5, 6, 7}, {3, 4}, {1, 2}}]],
        True,
        TestID -> "paclet-symmetry-tb-B5-nonsorted-rank7"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-B6-nonsorted-rank5",
    "Non-sorted slot ordering {{2,4,5},{1,3}}; Sagan thm 2.6.5",
    VerificationTest[
        YoungSymmetrize[$T5, YoungTableau[{{2, 4, 5}, {1, 3}}]] ===
            $referenceYoungSymmetrize[$T5, YoungTableau[{{2, 4, 5}, {1, 3}}]],
        True,
        TestID -> "paclet-symmetry-tb-B6-nonsorted-rank5"
    ]
];


(* ============================================================ *)
(* C. Presentation invariance                                   *)
(*    Tableaux with identical row sets and identical column     *)
(*    sets define the same Young projector. The cleanest        *)
(*    presentation that preserves both partitions is swapping   *)
(*    two whole rows of equal length.                           *)
(* ============================================================ *)

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-C1-row-swap-22",
    "Row swap on {2,2}: same row sets, same column sets, must give same projector",
    VerificationTest[
        YoungSymmetrize[$T4, YoungTableau[{{1, 2}, {3, 4}}]] ===
            YoungSymmetrize[$T4, YoungTableau[{{3, 4}, {1, 2}}]],
        True,
        TestID -> "paclet-symmetry-tb-C1-row-swap-22"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-C2-row-cycle-222",
    "Cyclic permutation of three equal-length rows in {2,2,2}",
    VerificationTest[
        Module[{a, b, c},
            a = YoungSymmetrize[$T6, YoungTableau[{{1, 2}, {3, 4}, {5, 6}}]];
            b = YoungSymmetrize[$T6, YoungTableau[{{5, 6}, {1, 2}, {3, 4}}]];
            c = YoungSymmetrize[$T6, YoungTableau[{{3, 4}, {5, 6}, {1, 2}}]];
            a === b === c
        ],
        True,
        TestID -> "paclet-symmetry-tb-C2-row-cycle-222"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-C3-row-swap-322",
    "Swap the two equal-length rows in a {3,2,2} tableau",
    VerificationTest[
        YoungSymmetrize[$T7, YoungTableau[{{1, 2, 3}, {4, 5}, {6, 7}}]] ===
            YoungSymmetrize[$T7, YoungTableau[{{1, 2, 3}, {6, 7}, {4, 5}}]],
        True,
        TestID -> "paclet-symmetry-tb-C3-row-swap-322"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-tb-C4-row-swap-11",
    "Row swap on {1,1}: two single-box rows of equal length",
    VerificationTest[
        YoungSymmetrize[$T2, YoungTableau[{{1}, {2}}]] ===
            YoungSymmetrize[$T2, YoungTableau[{{2}, {1}}]],
        True,
        TestID -> "paclet-symmetry-tb-C4-row-swap-11"
    ]
];


(* ============================================================ *)
(* D. Riemann physics motif                                     *)
(*    YoungProject onto {{1,3},{2,4}} maps V^4 onto the         *)
(*    Riemann irrep of S_4. The four classical Riemann          *)
(*    symmetries must hold on the result.                       *)
(* ============================================================ *)

WithCapability[{"YoungProject", "YoungTableau"}, "paclet-symmetry-tb-D1-riemann-anti-first-pair",
    "MTW 'Gravitation' Box 13.2; Wald 'GR' eq 3.2.13: R_{abcd} = -R_{bacd}",
    VerificationTest[
        Module[{R = YoungProject[$T4, YoungTableau[{{1, 3}, {2, 4}}]]},
            R + Transpose[R, {2, 1, 3, 4}] === ConstantArray[0, Dimensions[R]]
        ],
        True,
        TestID -> "paclet-symmetry-tb-D1-riemann-anti-first-pair"
    ]
];

WithCapability[{"YoungProject", "YoungTableau"}, "paclet-symmetry-tb-D2-riemann-anti-second-pair",
    "MTW 'Gravitation' Box 13.2; Wald 'GR' eq 3.2.13: R_{abcd} = -R_{abdc}",
    VerificationTest[
        Module[{R = YoungProject[$T4, YoungTableau[{{1, 3}, {2, 4}}]]},
            R + Transpose[R, {1, 2, 4, 3}] === ConstantArray[0, Dimensions[R]]
        ],
        True,
        TestID -> "paclet-symmetry-tb-D2-riemann-anti-second-pair"
    ]
];

WithCapability[{"YoungProject", "YoungTableau"}, "paclet-symmetry-tb-D3-riemann-pair-exchange",
    "MTW 'Gravitation' Box 13.2; Wald 'GR' eq 3.2.13: R_{abcd} = R_{cdab}",
    VerificationTest[
        Module[{R = YoungProject[$T4, YoungTableau[{{1, 3}, {2, 4}}]]},
            R - Transpose[R, {3, 4, 1, 2}] === ConstantArray[0, Dimensions[R]]
        ],
        True,
        TestID -> "paclet-symmetry-tb-D3-riemann-pair-exchange"
    ]
];

WithCapability[{"YoungProject", "YoungTableau"}, "paclet-symmetry-tb-D4-riemann-first-bianchi",
    "MTW 'Gravitation' Box 13.2; Wald 'GR' eq 3.2.13: R_{a[bcd]} = 0",
    VerificationTest[
        Module[{R = YoungProject[$T4, YoungTableau[{{1, 3}, {2, 4}}]]},
            R + Transpose[R, {1, 3, 4, 2}] + Transpose[R, {1, 4, 2, 3}] ===
                ConstantArray[0, Dimensions[R]]
        ],
        True,
        TestID -> "paclet-symmetry-tb-D4-riemann-first-bianchi"
    ]
];


(* ============================================================ *)
(* E. Fuzz sweep — random tableau presentations beyond the      *)
(*    partition-form constructor's image                        *)
(* ============================================================ *)

(* Build a random VALID tableau of given shape by shuffling Range[n] then
   reshaping with TakeList; the validator accepts any rearrangement, so
   most rolls produce non-standard orderings the prior fuzz layer never
   sampled. *)

$randomTableau[shape_, seed_] := BlockRandom[
    SeedRandom[seed];
    YoungTableau[TakeList[RandomSample[Range[Total[shape]]], shape]]
]

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-fuzz-yp-tb-random-presentations",
    "10 random tableau presentations per shape in {{2,1},{2,2},{3,2},{3,2,1}} match textbook",
    VerificationTest[
        AllTrue[
            Flatten @ Table[
                Module[{yt = $randomTableau[shape, 17 + 113 seed + Hash[shape]],
                        T},
                    T = Array[Total[10^Range[0, Total[shape] - 1] * {##}] &,
                              ConstantArray[3, Total[shape]]];
                    YoungSymmetrize[T, yt] === $referenceYoungSymmetrize[T, yt]
                ],
                {shape, {{2, 1}, {2, 2}, {3, 2}, {3, 2, 1}}},
                {seed, 1, 10}
            ],
            TrueQ
        ],
        True,
        TestID -> "paclet-fuzz-yp-tb-random-presentations"
    ]
];
