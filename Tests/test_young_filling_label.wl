(* Tests/test_young_filling_label.wl

   Tests for the MakeBoxes filling-label and the StandardTableauQ predicate
   in Wolfram`TensorNetworks`Symmetry`YoungTableau.

   The filling label is one of three values:
     "Canonical" — row-reading default filling 1..n (implies Standard)
     "Standard"  — rows and columns strictly increasing, but not canonical
     "Explicit"  — neither canonical nor standard (rows or columns not
                   strictly increasing)

   Coverage:
     A. Partition-form constructor renders "Filling: Canonical".
     B. Standard non-canonical fillings render "Filling: Standard".
     C. Genuinely non-SYT fillings render "Filling: Explicit".
     D. Content-based labeling: hand-typed canonical filling renders
        "Filling: Canonical" too (label is content-based, not provenance).
     E. Single-SYT shapes (f^lambda = 1) render "Filling: Canonical".
     F. Data model unchanged across partition vs explicit forms.
     G. Regression on public properties.
     H. StandardTableauQ predicate directly.
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];
Needs["Wolfram`TensorNetworks`Symmetry`"];


(* boxString renders ToBoxes output as an InputForm string. Searching that
   string for one of "Canonical" | "Standard" | "Explicit" verifies that
   MakeBoxes emitted the right label, without depending on the precise
   internal structure of BoxForm`ArrangeSummaryBox output. *)
boxString[expr_] := ToString[ToBoxes[expr, StandardForm], InputForm]

(* labelChecks[expr, expected] returns True iff the rendered box for expr
   contains the expected label AND does NOT contain either of the other
   two labels, ensuring we picked up the intended branch. *)
labelChecks[expr_, expected_String] :=
    With[
        {
            s = boxString[expr],
            others = DeleteCases[{"Canonical", "Standard", "Explicit"}, expected]
        },
        StringContainsQ[s, expected] && AllTrue[others, ! StringContainsQ[s, #] &]
    ]


(* ============================================ *)
(* A. Partition-form constructor                *)
(* ============================================ *)

(* YoungTableau[partition] auto-fills the row-reading canonical SYT. *)

VerificationTest[
    labelChecks[YoungTableau[{3, 2, 1}], "Canonical"],
    True,
    TestID -> "A1.partition_321_canonical"
]

VerificationTest[
    labelChecks[YoungTableau[{4, 2}], "Canonical"],
    True,
    TestID -> "A2.partition_42_canonical"
]

VerificationTest[
    labelChecks[YoungTableau[{2, 2, 1}], "Canonical"],
    True,
    TestID -> "A3.partition_221_canonical"
]


(* ============================================ *)
(* B. Standard non-canonical fillings           *)
(* ============================================ *)

(* These tableaux are valid SYTs (rows and columns strictly increasing)
   but not the row-reading canonical filling. *)

VerificationTest[
    labelChecks[YoungTableau[{{1, 2, 4}, {3, 5}}], "Standard"],
    True,
    TestID -> "B1.standard_124_35"
]

VerificationTest[
    labelChecks[YoungTableau[{{1, 3}, {2, 4}}], "Standard"],
    True,
    TestID -> "B2.standard_13_24"
]

VerificationTest[
    labelChecks[YoungTableau[{{1, 3}, {2}}], "Standard"],
    True,
    TestID -> "B3.standard_13_2"
]


(* ============================================ *)
(* C. Genuinely non-SYT fillings                *)
(* ============================================ *)

(* Valid YoungTableau objects (entries 1..n, partition shape) whose rows
   or columns are not strictly increasing. These exist legitimately
   because YoungTableau models labeled diagrams, not just SYTs. *)

VerificationTest[
    labelChecks[YoungTableau[{{5, 1, 3}, {2, 4}}], "Explicit"],
    True,
    TestID -> "C1.explicit_row_violation_513_24"
]

VerificationTest[
    labelChecks[YoungTableau[{{1, 4}, {2, 3}}], "Explicit"],
    True,
    TestID -> "C2.explicit_col_violation_14_23"
]

VerificationTest[
    labelChecks[YoungTableau[{{2, 1}, {3}}], "Explicit"],
    True,
    TestID -> "C3.explicit_row_violation_21_3"
]


(* ============================================ *)
(* D. Content-based labeling                    *)
(* ============================================ *)

(* Spelling out the canonical filling by hand should still produce
   "Canonical", because the two objects are identical. *)

VerificationTest[
    YoungTableau[{{1, 2, 3}, {4, 5}, {6}}] === YoungTableau[{3, 2, 1}],
    True,
    TestID -> "D1.explicit_canonical_equal_to_partition"
]

VerificationTest[
    labelChecks[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}], "Canonical"],
    True,
    TestID -> "D2.explicit_canonical_label"
]


(* ============================================ *)
(* E. Single-SYT shapes                         *)
(* ============================================ *)

(* For shapes with f^lambda = 1 (one-row or one-column), there is exactly
   one SYT, which is by definition the canonical row-reading filling. *)

VerificationTest[
    labelChecks[YoungTableau[{5}], "Canonical"],
    True,
    TestID -> "E1.single_row_5"
]

VerificationTest[
    labelChecks[YoungTableau[{1, 1, 1, 1}], "Canonical"],
    True,
    TestID -> "E2.single_column_4"
]

VerificationTest[
    labelChecks[YoungTableau[{{1, 2}}], "Canonical"],
    True,
    TestID -> "E3.explicit_single_row"
]

VerificationTest[
    labelChecks[YoungTableau[{{1}, {2}, {3}}], "Canonical"],
    True,
    TestID -> "E4.explicit_single_column"
]


(* ============================================ *)
(* F. Data model unchanged                      *)
(* ============================================ *)

(* The labeling lives only in MakeBoxes. The underlying YoungTableau
   object, its accessors, and downstream operations must be identical
   between the partition form and the equivalent explicit form. *)

VerificationTest[
    TableauRows[YoungTableau[{3, 2, 1}]] ===
        TableauRows[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]],
    True,
    TestID -> "F1.equal_rows"
]

VerificationTest[
    TableauColumns[YoungTableau[{3, 2, 1}]] ===
        TableauColumns[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]],
    True,
    TestID -> "F2.equal_columns"
]

VerificationTest[
    TableauShape[YoungTableau[{3, 2, 1}]] ===
        TableauShape[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]],
    True,
    TestID -> "F3.equal_shape"
]

VerificationTest[
    TableauDimension[YoungTableau[{3, 2, 1}]] ===
        TableauDimension[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]],
    True,
    TestID -> "F4.equal_dimension"
]

VerificationTest[
    HookLengths[YoungTableau[{3, 2, 1}]] ===
        HookLengths[YoungTableau[{{1, 2, 3}, {4, 5}, {6}}]],
    True,
    TestID -> "F5.equal_hooks"
]

VerificationTest[
    YoungSymmetrize[Array[a, {2, 2, 2}], YoungTableau[{2, 1}]] ===
        YoungSymmetrize[Array[a, {2, 2, 2}], YoungTableau[{{1, 2}, {3}}]],
    True,
    TestID -> "F6.equal_symmetrize"
]


(* ============================================ *)
(* G. Regression on public properties           *)
(* ============================================ *)

VerificationTest[
    TableauDimension[YoungTableau[{3, 2, 1}]],
    16,
    TestID -> "G1.dim_321_eq_16"
]

VerificationTest[
    TableauDimension[YoungTableau[{4, 2}]],
    9,
    TestID -> "G2.dim_42_eq_9"
]

VerificationTest[
    SchurDimension[{4, 2}, 3],
    27,
    TestID -> "G3.schur_42_d3_eq_27"
]

VerificationTest[
    YoungTableauQ[YoungTableau[{{1, 2, 4}, {3, 5}}]],
    True,
    TestID -> "G4.young_tableau_q_explicit"
]

VerificationTest[
    YoungTableauQ[YoungTableau[{3, 2, 1}]],
    True,
    TestID -> "G5.young_tableau_q_partition"
]

VerificationTest[
    TableauShape[YoungTableau[{4, 2, 1}]],
    {4, 2, 1},
    TestID -> "G6.shape_421"
]

VerificationTest[
    TableauSize[YoungTableau[{3, 2, 1}]],
    6,
    TestID -> "G7.size_321"
]


(* ============================================ *)
(* H. StandardTableauQ predicate                *)
(* ============================================ *)

(* Canonical fillings are standard by construction. *)

VerificationTest[
    StandardTableauQ[YoungTableau[{3, 2, 1}]],
    True,
    TestID -> "H1.standard_canonical_321"
]

VerificationTest[
    StandardTableauQ[YoungTableau[{4, 2}]],
    True,
    TestID -> "H2.standard_canonical_42"
]

(* Non-canonical SYTs. *)

VerificationTest[
    StandardTableauQ[YoungTableau[{{1, 2, 4}, {3, 5}}]],
    True,
    TestID -> "H3.standard_noncanonical_124_35"
]

VerificationTest[
    StandardTableauQ[YoungTableau[{{1, 3}, {2, 4}}]],
    True,
    TestID -> "H4.standard_noncanonical_13_24"
]

(* Row violations. *)

VerificationTest[
    StandardTableauQ[YoungTableau[{{5, 1, 3}, {2, 4}}]],
    False,
    TestID -> "H5.nonstandard_row_513_24"
]

VerificationTest[
    StandardTableauQ[YoungTableau[{{2, 1}, {3}}]],
    False,
    TestID -> "H6.nonstandard_row_21_3"
]

(* Column violation with rows strictly increasing. *)

VerificationTest[
    StandardTableauQ[YoungTableau[{{1, 4}, {2, 3}}]],
    False,
    TestID -> "H7.nonstandard_col_14_23"
]

(* Non-YoungTableau inputs return False (Boolean contract). *)

VerificationTest[
    StandardTableauQ["not a tableau"],
    False,
    TestID -> "H8.nonyt_string"
]

VerificationTest[
    StandardTableauQ[42],
    False,
    TestID -> "H9.nonyt_integer"
]

VerificationTest[
    StandardTableauQ[{{1, 2}, {3}}],
    False,
    TestID -> "H10.nonyt_raw_list"
]
