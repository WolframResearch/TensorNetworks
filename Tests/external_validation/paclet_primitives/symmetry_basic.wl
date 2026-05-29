(* Tests/external_validation/paclet_primitives/symmetry_basic.wl

Layer-1 analytic baselines for `Wolfram`TensorNetworks`Symmetry`. Anchors the
12 exported symbols (YoungTableau, YoungTableauQ, PartitionQ,
TransposePartition, TableauShape, TableauSize, HookLength, HookLengths,
HookFactor, TableauDimension, YoungSymmetrize, YoungProject) to canonical
representation-theory facts about the symmetric group S_n.

Math anchors (all from textbook S_n theory; no Python/Julia/external package):

  - Hook-length formula vs known S_n irrep dimensions, n = 2..7
    (Sagan, "The Symmetric Group" 2e, Thm 3.10.2; Fulton & Harris, "Representation
    Theory" Lecture 4)
  - Plancherel sum rule: sum_{lambda |- n} d_lambda^2 = n!
  - Conjugate-partition involution and weight-preservation
  - HookLengths vs cell-by-cell HookLength cross-check
  - n! * HookFactor[p] === TableauDimension[p]
  - Young projector idempotency P^2 = P on rank-2 and rank-3 tensors
  - Young projector orthogonality between different shapes
  - Schur-Weyl rank-2 completeness: P_{2} + P_{1,1} = identity on V (x) V
  - Predicate and error-path exercises

These are paclet-primitive tests (every assertion exercises at least one
Wolfram`TensorNetworks`Symmetry symbol) so the file lives in paclet_primitives/.
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
        Print["[paclet-symmetry] ERROR: cannot locate ValidationHelpers.wl"]; Abort[];
    ];
    Get[found];
];
ClearValidationRecords[];

(* Fixed exact-arithmetic rank-2 and rank-3 tensors so SameQ comparisons work. *)
$T2 = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}};
$T3 = Array[(100 #1 + 10 #2 + #3) &, {3, 3, 3}];


(* ============================================================ *)
(* A. Hook-length formula vs canonical S_n irrep dimensions     *)
(* ============================================================ *)

WithCapability[{"TableauDimension"}, "paclet-symmetry-A1-dim-S2", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        Map[TableauDimension, IntegerPartitions[2]],
        {1, 1},                                                 (* {2}, {1,1} *)
        TestID -> "paclet-symmetry-A1-dim-S2"
    ]
];

WithCapability[{"TableauDimension"}, "paclet-symmetry-A2-dim-S3", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        Map[TableauDimension, IntegerPartitions[3]],
        {1, 2, 1},                                              (* {3},{2,1},{1,1,1} *)
        TestID -> "paclet-symmetry-A2-dim-S3"
    ]
];

WithCapability[{"TableauDimension"}, "paclet-symmetry-A3-dim-S4", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        Map[TableauDimension, IntegerPartitions[4]],
        {1, 3, 2, 3, 1},                                        (* {4},{3,1},{2,2},{2,1,1},{1^4} *)
        TestID -> "paclet-symmetry-A3-dim-S4"
    ]
];

WithCapability[{"TableauDimension"}, "paclet-symmetry-A4-dim-S5", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        Map[TableauDimension, IntegerPartitions[5]],
        {1, 4, 5, 6, 5, 4, 1},                                  (* {5},{4,1},{3,2},{3,1,1},{2,2,1},{2,1^3},{1^5} *)
        TestID -> "paclet-symmetry-A4-dim-S5"
    ]
];

WithCapability[{"TableauDimension"}, "paclet-symmetry-A5-dim-S6", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        Map[TableauDimension, IntegerPartitions[6]],
        {1, 5, 9, 10, 5, 16, 10, 5, 9, 5, 1},
        TestID -> "paclet-symmetry-A5-dim-S6"
    ]
];

WithCapability[{"TableauDimension"}, "paclet-symmetry-A6-dim-S7", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        Map[TableauDimension, IntegerPartitions[7]],
        {1, 6, 14, 15, 14, 35, 20, 21, 21, 35, 15, 14, 14, 6, 1},
        TestID -> "paclet-symmetry-A6-dim-S7"
    ]
];


(* ============================================================ *)
(* B. Plancherel sum rule  sum d^2 = n!  for n = 1..7           *)
(* ============================================================ *)

WithCapability[{"TableauDimension"}, "paclet-symmetry-B1-plancherel-sumrule", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        AllTrue[
            Range[1, 7],
            (Total[(TableauDimension /@ IntegerPartitions[#])^2] === #!) &
        ],
        True,
        TestID -> "paclet-symmetry-B1-plancherel-sumrule"
    ]
];


(* ============================================================ *)
(* C. Hook-length internals & cross-consistency                 *)
(* ============================================================ *)

WithCapability[{"HookLengths"}, "paclet-symmetry-C1-hooklengths-32", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        HookLengths[{3, 2}],
        {{4, 3, 1}, {2, 1}},                                    (* product 24, d = 120/24 = 5 *)
        TestID -> "paclet-symmetry-C1-hooklengths-32"
    ]
];

WithCapability[{"HookLengths"}, "paclet-symmetry-C2-hooklengths-42", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        HookLengths[{4, 2}],
        {{5, 4, 2, 1}, {2, 1}},                                 (* product 80, d = 720/80 = 9 *)
        TestID -> "paclet-symmetry-C2-hooklengths-42"
    ]
];

WithCapability[{"HookLengths"}, "paclet-symmetry-C3-hooklengths-221", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        HookLengths[{2, 2, 1}],
        {{4, 2}, {3, 1}, {1}},                                  (* product 24, d = 120/24 = 5 *)
        TestID -> "paclet-symmetry-C3-hooklengths-221"
    ]
];

WithCapability[{"HookLength", "HookLengths"}, "paclet-symmetry-C4-hooklength-vs-hooklengths", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        AllTrue[
            {{4, 3, 1}, {5, 2}, {3, 3, 2}, {4, 1, 1, 1}, {6, 4, 2, 1}},
            Function[p,
                Module[{yt = YoungTableau[p], all = HookLengths[p]},
                    AllTrue[
                        Flatten @ MapIndexed[(HookLength[yt, #2] - #1) &, all, {2}],
                        # === 0 &
                    ]
                ]
            ]
        ],
        True,
        TestID -> "paclet-symmetry-C4-hooklength-vs-hooklengths"
    ]
];

WithCapability[{"HookFactor", "TableauDimension"}, "paclet-symmetry-C5-hookfactor-vs-dim", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        AllTrue[
            Join @@ (IntegerPartitions /@ Range[1, 6]),
            (TableauDimension[#] === Total[#]! * HookFactor[#]) &
        ],
        True,
        TestID -> "paclet-symmetry-C5-hookfactor-vs-dim"
    ]
];


(* ============================================================ *)
(* D. TransposePartition: known cases, involution, weight       *)
(* ============================================================ *)

WithCapability[{"TransposePartition"}, "paclet-symmetry-D1-transpose-known", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        TransposePartition /@ {{4, 2, 1}, {3, 2, 2, 1}, {5}, {1, 1, 1}, {3, 3}},
        {{3, 2, 1, 1}, {4, 3, 1}, {1, 1, 1, 1, 1}, {3}, {2, 2, 2}},
        TestID -> "paclet-symmetry-D1-transpose-known"
    ]
];

WithCapability[{"TransposePartition"}, "paclet-symmetry-D2-transpose-involution", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        AllTrue[
            Join @@ (IntegerPartitions /@ Range[1, 8]),
            (TransposePartition[TransposePartition[#]] === #) &
        ],
        True,
        TestID -> "paclet-symmetry-D2-transpose-involution"
    ]
];

WithCapability[{"TransposePartition"}, "paclet-symmetry-D3-transpose-weight", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        AllTrue[
            Join @@ (IntegerPartitions /@ Range[1, 8]),
            (Total[TransposePartition[#]] === Total[#]) &
        ],
        True,
        TestID -> "paclet-symmetry-D3-transpose-weight"
    ]
];


(* ============================================================ *)
(* E. Predicates and constructor                                *)
(* ============================================================ *)

WithCapability[{"PartitionQ"}, "paclet-symmetry-E1-partitionq", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        {
            PartitionQ[{3, 2, 1}],                              (* valid                  *)
            PartitionQ[{3, 3, 1}],                              (* equal allowed          *)
            PartitionQ[{1}],                                    (* singleton              *)
            PartitionQ[{1, 2, 3}],                              (* increasing -> False    *)
            PartitionQ[{3, 0, 1}],                              (* zero        -> False   *)
            PartitionQ[{-1, 1}],                                (* negative    -> False   *)
            PartitionQ[{3, 5/2, 1}],                            (* non-integer -> False   *)
            PartitionQ[{}]                                      (* empty       -> False   *)
        },
        {True, True, True, False, False, False, False, False},
        TestID -> "paclet-symmetry-E1-partitionq"
    ]
];

WithCapability[{"YoungTableauQ"}, "paclet-symmetry-E2-youngtableauq", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        {
            YoungTableauQ[YoungTableau[{{1, 2, 3}, {4, 5}}]],   (* valid SYT          *)
            YoungTableauQ[YoungTableau[{{1, 3, 5}, {2, 4}}]],   (* valid non-canonical *)
            YoungTableauQ[YoungTableau[{{1}, {2, 3}}]],         (* shape increasing   *)
            YoungTableauQ[YoungTableau[{{1, 2}, {2, 3}}]],      (* duplicate entry    *)
            YoungTableauQ[{{1, 2, 3}, {4, 5}}]                  (* not wrapped        *)
        },
        {True, True, False, False, False},
        (* The two malformed inner constructions now reject at construction
           time with YoungTableau::notslot; YoungTableauQ on the resulting
           $Failed still returns False, so the assertion value is unchanged. *)
        {YoungTableau::notslot, YoungTableau::notslot},
        TestID -> "paclet-symmetry-E2-youngtableauq"
    ]
];

(* Each malformed-input check lives in its own VerificationTest so the
   per-calculation General::stop suppression of repeated YoungTableau::notslot
   doesn't pollute the expected-messages slot. *)
WithCapability[{"YoungTableau"}, "paclet-symmetry-E2b-rejects-entry-outside-range", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        YoungTableau[{{1, 10, 3}, {5, 4}}],
        $Failed,
        {YoungTableau::notslot},
        TestID -> "paclet-symmetry-E2b-rejects-entry-outside-range"
    ]
];

WithCapability[{"YoungTableau"}, "paclet-symmetry-E2d-rejects-duplicate-entry", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        YoungTableau[{{1, 2}, {2, 3}}],
        $Failed,
        {YoungTableau::notslot},
        TestID -> "paclet-symmetry-E2d-rejects-duplicate-entry"
    ]
];

WithCapability[{"YoungTableau"}, "paclet-symmetry-E2e-rejects-bad-shape", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        YoungTableau[{{1}, {2, 3}}],
        $Failed,
        {YoungTableau::notslot},
        TestID -> "paclet-symmetry-E2e-rejects-bad-shape"
    ]
];

WithCapability[{"YoungTableau"}, "paclet-symmetry-E2f-rejects-empty-rows", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        YoungTableau[{}],
        $Failed,
        {YoungTableau::notslot},
        TestID -> "paclet-symmetry-E2f-rejects-empty-rows"
    ]
];

WithCapability[{"YoungTableau"}, "paclet-symmetry-E2c-constructor-rejects-bad-partition", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        YoungTableau[{1, 2}],                  (* not non-increasing *)
        $Failed,
        {YoungTableau::notpar},
        TestID -> "paclet-symmetry-E2c-constructor-rejects-bad-partition"
    ]
];

WithCapability[{"YoungTableau"}, "paclet-symmetry-E3-constructor-partition-shorthand", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        (* Partition shorthand must lower to the canonical row-filled SYT. *)
        {
            YoungTableau[{3, 2}]    === YoungTableau[{{1, 2, 3}, {4, 5}}],
            YoungTableau[{2, 1}]    === YoungTableau[{{1, 2}, {3}}],
            YoungTableau[{1, 1, 1}] === YoungTableau[{{1}, {2}, {3}}]
        },
        {True, True, True},
        TestID -> "paclet-symmetry-E3-constructor-partition-shorthand"
    ]
];


(* ============================================================ *)
(* F. Young projector on rank-2 tensors (V (x) V)               *)
(* ============================================================ *)

WithCapability[{"YoungProject", "YoungTableau"}, "paclet-symmetry-F1-sym-projector-rank2", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        YoungProject[$T2, YoungTableau[{{1, 2}}]],
        (1/2) * ($T2 + Transpose[$T2]),                         (* P_sym = (T + T^T)/2 *)
        TestID -> "paclet-symmetry-F1-sym-projector-rank2"
    ]
];

WithCapability[{"YoungProject", "YoungTableau"}, "paclet-symmetry-F2-antisym-projector-rank2", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        YoungProject[$T2, YoungTableau[{{1}, {2}}]],
        (1/2) * ($T2 - Transpose[$T2]),                         (* P_anti = (T - T^T)/2 *)
        TestID -> "paclet-symmetry-F2-antisym-projector-rank2"
    ]
];

WithCapability[{"YoungProject", "YoungTableau"}, "paclet-symmetry-F3-completeness-rank2", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        (* Schur-Weyl on V (x) V: only two partitions of 2, so
           P_{2} + P_{1,1} = identity on the full tensor space. *)
        (YoungProject[$T2, YoungTableau[{{1, 2}}]] +
         YoungProject[$T2, YoungTableau[{{1}, {2}}]]) === $T2,
        True,
        TestID -> "paclet-symmetry-F3-completeness-rank2"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-F4-symmetrize-unnormalized", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        (* YoungSymmetrize is the *unnormalized* Young symmetrizer c_T.
           For {{1,2}}: c_T = e + (12), so c_T(T) = T + T^T. *)
        YoungSymmetrize[$T2, YoungTableau[{{1, 2}}]] === $T2 + Transpose[$T2],
        True,
        TestID -> "paclet-symmetry-F4-symmetrize-unnormalized"
    ]
];


(* ============================================================ *)
(* G. Projector idempotency  P^2 = P                            *)
(* ============================================================ *)

WithCapability[{"YoungProject", "YoungTableau"}, "paclet-symmetry-G1-idempotent-sym-rank2", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        Module[{tab = YoungTableau[{{1, 2}}], once, twice},
            once = YoungProject[$T2, tab];
            twice = YoungProject[once, tab];
            twice === once
        ],
        True,
        TestID -> "paclet-symmetry-G1-idempotent-sym-rank2"
    ]
];

WithCapability[{"YoungProject", "YoungTableau"}, "paclet-symmetry-G2-idempotent-antisym-rank2", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        Module[{tab = YoungTableau[{{1}, {2}}], once, twice},
            once = YoungProject[$T2, tab];
            twice = YoungProject[once, tab];
            twice === once
        ],
        True,
        TestID -> "paclet-symmetry-G2-idempotent-antisym-rank2"
    ]
];

WithCapability[{"YoungProject", "YoungTableau"}, "paclet-symmetry-G3-idempotent-mixed-rank3", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        (* Mixed-symmetry tableau {{1,2},{3}} of S_3; d = 2.
           P^2 = P holds for the (d/n!)-normalized symmetrizer. *)
        Module[{tab = YoungTableau[{{1, 2}, {3}}], once, twice},
            once = YoungProject[$T3, tab];
            twice = YoungProject[once, tab];
            twice === once
        ],
        True,
        TestID -> "paclet-symmetry-G3-idempotent-mixed-rank3"
    ]
];


(* ============================================================ *)
(* H. Orthogonality between projectors of different shape       *)
(* ============================================================ *)

WithCapability[{"YoungProject", "YoungTableau"}, "paclet-symmetry-H1-orthog-sym-antisym-rank2", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        Module[{symPart, andThenAnti},
            symPart     = YoungProject[$T2, YoungTableau[{{1, 2}}]];
            andThenAnti = YoungProject[symPart, YoungTableau[{{1}, {2}}]];
            Max[Abs[Flatten[andThenAnti]]] === 0
        ],
        True,
        TestID -> "paclet-symmetry-H1-orthog-sym-antisym-rank2"
    ]
];

WithCapability[{"YoungProject", "YoungTableau"}, "paclet-symmetry-H2-orthog-sym-mixed-rank3", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        (* Fully-symmetric piece S^3(V) is orthogonal to V_{2,1}(V). *)
        Module[{symPart, andThenMixed},
            symPart      = YoungProject[$T3, YoungTableau[{{1, 2, 3}}]];
            andThenMixed = YoungProject[symPart, YoungTableau[{{1, 2}, {3}}]];
            Max[Abs[Flatten[andThenMixed]]] === 0
        ],
        True,
        TestID -> "paclet-symmetry-H2-orthog-sym-mixed-rank3"
    ]
];


(* ============================================================ *)
(* I. TableauShape & TableauSize                                *)
(* ============================================================ *)

WithCapability[{"TableauShape", "TableauSize"}, "paclet-symmetry-I1-shape-size", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        Module[{yt = YoungTableau[{{1, 2, 3, 4}, {5, 6}, {7}}]},
            {TableauShape[yt], TableauSize[yt]}
        ],
        {{4, 2, 1}, 7},
        TestID -> "paclet-symmetry-I1-shape-size"
    ]
];


(* ============================================================ *)
(* J. Error paths (exercise declared messages)                  *)
(* ============================================================ *)

WithCapability[{"TableauShape"}, "paclet-symmetry-J1-error-tableaushape-noyt", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        TableauShape[{{1, 2}, {3}}],                            (* bare list, no YoungTableau wrapper *)
        $Failed,
        {TableauShape::noyt},
        TestID -> "paclet-symmetry-J1-error-tableaushape-noyt"
    ]
];

WithCapability[{"YoungSymmetrize", "YoungTableau"}, "paclet-symmetry-J2-error-rank-mismatch", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Fulton-Harris Lec 4; Symmetry/README.md",
    VerificationTest[
        (* Rank-3 tensor with rank-2 tableau triggers YoungSymmetrize::rank. *)
        YoungSymmetrize[Array[# &, {2, 2, 2}], YoungTableau[{{1, 2}}]],
        $Failed,
        {YoungSymmetrize::rank},
        TestID -> "paclet-symmetry-J2-error-rank-mismatch"
    ]
];


(* ============================================================ *)
(* K. TableauRows & TableauColumns accessors                    *)
(* ============================================================ *)

WithCapability[{"TableauRows", "YoungTableau"}, "paclet-symmetry-K1-rows-explicit", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Symmetry/README.md",
    VerificationTest[
        TableauRows[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]],
        {{1, 2, 3}, {4, 5}, {6}},
        TestID -> "paclet-symmetry-K1-rows-explicit"
    ]
];

WithCapability[{"TableauRows", "YoungTableau"}, "paclet-symmetry-K2-rows-roundtrip-partition-form", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Symmetry/README.md",
    VerificationTest[
        (* Partition-form constructor lowers to row-major standard tableau,
           and TableauRows must return that canonical layout. *)
        AllTrue[
            {{3, 2}, {4, 2, 1}, {1, 1, 1, 1}, {5}, {3, 3, 2}},
            (TableauRows[YoungTableau[#]] === TakeList[Range[Total[#]], #]) &
        ],
        True,
        TestID -> "paclet-symmetry-K2-rows-roundtrip-partition-form"
    ]
];

WithCapability[{"TableauColumns", "YoungTableau"}, "paclet-symmetry-K3-columns-standard", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Symmetry/README.md",
    VerificationTest[
        TableauColumns[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]],
        {{1, 4, 6}, {2, 5}, {3}},
        TestID -> "paclet-symmetry-K3-columns-standard"
    ]
];

WithCapability[{"TableauColumns", "YoungTableau"}, "paclet-symmetry-K4-columns-ragged-nonstandard", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Symmetry/README.md",
    VerificationTest[
        TableauColumns[YoungTableau[{{5, 6, 7}, {3, 4}, {1, 2}}]],
        {{5, 3, 1}, {6, 4, 2}, {7}},
        TestID -> "paclet-symmetry-K4-columns-ragged-nonstandard"
    ]
];

WithCapability[{"TableauRows"}, "paclet-symmetry-K5-error-rows-noyt", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Symmetry/README.md",
    VerificationTest[
        TableauRows[{{1, 2}, {3}}],                             (* bare list, not wrapped *)
        $Failed,
        {TableauRows::noyt},
        TestID -> "paclet-symmetry-K5-error-rows-noyt"
    ]
];

WithCapability[{"TableauColumns"}, "paclet-symmetry-K6-error-columns-noyt", "Sagan 'Symmetric Group' 2e Thm 3.10.2; Symmetry/README.md",
    VerificationTest[
        TableauColumns[{{1, 2}, {3}}],
        $Failed,
        {TableauColumns::noyt},
        TestID -> "paclet-symmetry-K6-error-columns-noyt"
    ]
];

WithCapability[{"TableauRows", "TableauColumns", "YoungSymmetrize"},
    "paclet-symmetry-K7-accessors-feed-symmetrize",
    "TableauRows and TableauColumns let users feed the kernel's Symmetrize directly",
    VerificationTest[
        (* The accessors close the loop between YoungTableau and WL's
           Symmetrize: scaling Symmetrize by the stabilizer orders
           reproduces YoungSymmetrize bit-for-bit. *)
        Module[{T = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}},
                yt = YoungTableau[{{1, 2}}],
                rows, cols},
            rows = TableauRows[yt]; cols = TableauColumns[yt];
            YoungSymmetrize[T, yt] ===
                (Times @@ (Factorial /@ Length /@ cols))
                  Normal @ Symmetrize[
                      (Times @@ (Factorial /@ Length /@ rows))
                          Normal @ Symmetrize[T, Symmetric /@ rows],
                      Antisymmetric /@ cols
                  ]
        ],
        True,
        TestID -> "paclet-symmetry-K7-accessors-feed-symmetrize"
    ]
];
