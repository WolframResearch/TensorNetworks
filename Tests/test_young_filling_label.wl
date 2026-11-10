(* Tests/test_young_filling_label.wl

   StandardTableauQ against brute-force enumeration of every filling of every
   shape up to n = 6, the validation that YoungTableau applies to a row
   layout, the canonical filling of the partition form, the derived columns,
   and the dimensions read off a shape.
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];
Needs["Wolfram`TensorNetworks`Symmetry`"];


(* Every way to write 1..n into the boxes of the shape, row by row *)
allFillings[shape_] := TakeList[#, shape] & /@ Permutations[Range[Total[shape]]]

(* Column j: the j-th entry of every row long enough to have one *)
columnsOf[rows_] := Table[rows[[r, j]], {j, Length[First[rows]]}, {r, Count[Length /@ rows, l_ /; l >= j]}]

strictlyIncreasingQ[list_] := And @@ Thread[Most[list] < Rest[list]]

standardByHandQ[rows_] := AllTrue[Join[rows, columnsOf[rows]], strictlyIncreasingQ]

shapesUpTo6 = Catenate[IntegerPartitions /@ Range[6]];


(* ============================================ *)
(* StandardTableauQ                             *)
(* ============================================ *)

(* Every filling of every shape with at most 6 boxes; the list is the fillings where
   StandardTableauQ and the hand check disagree *)
VerificationTest[
    Select[
        Catenate[allFillings /@ shapesUpTo6],
        StandardTableauQ[YoungTableau[#]] =!= standardByHandQ[#] &
    ],
    {},
    TestID -> "StandardTableauQ_AgreesWithEnumeration"
]

(* The number of standard fillings of each shape, counted by hand, against the known
   counts f^lambda; a disagreement here means the hand check itself is wrong *)
VerificationTest[
    Count[allFillings[#], _?standardByHandQ] & /@ {{3, 2, 1}, {4, 2}, {3, 3}, {2, 2, 1, 1}, {6}},
    {16, 9, 5, 9, 1},
    TestID -> "StandardTableauQ_HandCountsAreTheKnownOnes"
]

(* A column that decreases while every row increases: the one case a row-only check passes *)
VerificationTest[
    {StandardTableauQ[YoungTableau[{{1, 4}, {2, 3}}]], StandardTableauQ[YoungTableau[{{2, 3}, {1, 4}}]]},
    {False, False},
    TestID -> "StandardTableauQ_ColumnViolation"
]

VerificationTest[
    StandardTableauQ /@ {"not a tableau", 42, {{1, 2}, {3}}},
    {False, False, False},
    TestID -> "StandardTableauQ_NonTableauIsFalse"
]


(* ============================================ *)
(* Validation of the row layout                 *)
(* ============================================ *)

(* Rows must be non-increasing in length and hold 1..n once each; order inside a row is free.
   Unevaluated: the predicate itself judges the layout, before the constructor sees it *)
VerificationTest[
    Function[rows, YoungTableauQ[Unevaluated[YoungTableau[rows]]]] /@ {
        {{1, 2, 3}, {5, 4}},
        {{2, 1}, {3}},
        {{1}, {2, 3}},
        {{1, 2}, {2}},
        {{1, 2}, {4}},
        {{0, 1}},
        {}
    },
    {True, True, False, False, False, False, False},
    TestID -> "YoungTableauQ_RowLayoutRules"
]

VerificationTest[
    YoungTableauQ[YoungTableau[{{1, 2}, {2}}]],
    False,
    {YoungTableau::notslot},
    TestID -> "YoungTableau_InvalidLayoutIsReported"
]


(* ============================================ *)
(* Partition form and derived columns           *)
(* ============================================ *)

(* The partition form fills 1..n row by row *)
VerificationTest[
    {TableauRows[YoungTableau[{3, 2, 1}]], TableauRows[YoungTableau[{2, 2}]], YoungTableau[{3, 2, 1}] === YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]},
    {{{1, 2, 3}, {4, 5}, {6}}, {{1, 2}, {3, 4}}, True},
    TestID -> "YoungTableau_PartitionFormIsRowReadingFilling"
]

(* Ragged shape: column j stops at the first row shorter than j *)
VerificationTest[
    TableauColumns[YoungTableau[{{5, 1, 4}, {3, 6}, {2}}]],
    {{5, 3, 2}, {1, 6}, {4}},
    TestID -> "TableauColumns_RaggedShape"
]


(* ============================================ *)
(* Dimensions read off the shape                *)
(* ============================================ *)

(* f^lambda by the hook length formula: 6!/(5 3 1 3 1 1) and 6!/(5 4 2 1 2 1) *)
VerificationTest[
    {TableauDimension[YoungTableau[{3, 2, 1}]], TableauDimension[YoungTableau[{4, 2}]]},
    {16, 9},
    TestID -> "TableauDimension_HookLengthValues"
]

(* GL(3) irrep {4, 2}: product over boxes of (3 + content) / hook = 27 *)
VerificationTest[
    SchurDimension[{4, 2}, 3],
    27,
    TestID -> "SchurDimension_42_d3"
]
