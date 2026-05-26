(* ::Package:: *)

Package["Wolfram`TensorNetworks`Symmetry`"]

(* Young Tableaux for tensor symmetry operations *)

PackageExport[YoungTableau]
PackageExport[YoungTableauQ]
PackageExport[PartitionQ]
PackageExport[TransposePartition]
PackageExport[TableauShape]
PackageExport[TableauSize]
PackageExport[TableauRows]
PackageExport[TableauColumns]
PackageExport[HookLength]
PackageExport[HookLengths]
PackageExport[HookFactor]
PackageExport[TableauDimension]
PackageExport[SchurDimension]
PackageExport[TableauWeylDimension]
PackageExport[YoungSymmetrize]
PackageExport[YoungProject]


(* ============================================ *)
(* Young Tableau Data Structure                 *)
(* ============================================ *)

(* YoungTableau represents a Young tableau as a list of rows *)
(* Each row contains slot indices that specify how to permute tensor indices *)
(* Example: YoungTableau[{{1,2,3},{4,5}}] represents a tableau with shape {3,2} *)


(* ============================================ *)
(* Validation                                   *)
(* ============================================ *)

(* A valid Young tableau has:
   - Rows as lists of distinct positive integers
   - Row lengths are non-increasing (partition condition)
   - All indices from 1 to n appear exactly once (standard tableau) *)

youngTableauQ[YoungTableau[rows_List]] := And[
    AllTrue[rows, ListQ],
    Length[rows] > 0,
    AllTrue[rows, Length[#] > 0 &],
    (* Row lengths are non-increasing *)
    OrderedQ[Length /@ rows, GreaterEqual],
    (* All entries are exactly 1..n (standard tableau convention) *)
    With[{flat = Flatten[rows]},
        And[
            AllTrue[flat, IntegerQ[#] && # > 0 &],
            Sort[flat] === Range[Length[flat]]
        ]
    ]
]

youngTableauQ[_] := False

YoungTableauQ[yt_YoungTableau] := System`Private`HoldValidQ[yt] || youngTableauQ[Unevaluated[yt]]
YoungTableauQ[_] := False

(* Auto-validate on construction *)
yt_YoungTableau /; System`Private`HoldNotValidQ[yt] && youngTableauQ[Unevaluated[yt]] :=
    System`Private`SetNoEntry[System`Private`HoldSetValid[yt]]


(* ============================================ *)
(* Properties                                   *)
(* ============================================ *)

(* TableauShape returns the partition as a list of row lengths *)
TableauShape[YoungTableau[rows_List] ? YoungTableauQ] := Length /@ rows

TableauShape::noyt = "TableauShape accepts only YoungTableau as input, got `1`.";

TableauShape[expr_] := (Message[TableauShape::noyt, expr]; $Failed)

(* TableauSize returns the total number of boxes (size/weight of the partition) *)
TableauSize[YoungTableau[rows_List] ? YoungTableauQ] := Total[Length /@ rows]

TableauSize::noyt = "TableauSize accepts only YoungTableau as input, got `1`.";

TableauSize[expr_] := (Message[TableauSize::noyt, expr]; $Failed)

(* TableauRows exposes the inner row list — YoungTableau is atomic, so
   First and Part do not unpack it. *)
TableauRows[YoungTableau[rows_List] ? YoungTableauQ] := rows

TableauRows::noyt = "TableauRows accepts only YoungTableau as input, got `1`.";

TableauRows[expr_] := (Message[TableauRows::noyt, expr]; $Failed)

(* TableauColumns derives the column slot lists from the row layout.
   Column j collects the slot at position j of every row reaching position j;
   handles ragged shapes. *)
TableauColumns[YoungTableau[rows_List] ? YoungTableauQ] := getColumns[rows]

TableauColumns::noyt = "TableauColumns accepts only YoungTableau as input, got `1`.";

TableauColumns[expr_] := (Message[TableauColumns::noyt, expr]; $Failed)


(* ============================================ *)
(* Partition Utilities                          *)
(* ============================================ *)

(* Check if a list is a valid partition (non-increasing positive integers) *)
PartitionQ[par_List] := And[
    Length[par] > 0,
    AllTrue[par, IntegerQ[#] && # > 0 &],
    OrderedQ[par, GreaterEqual]
]
PartitionQ[_] := False

(* Transpose (conjugate) of a partition - O(n) where n = max element
   Example: {4,2,1} -> {3,2,1,1} (swap rows and columns of Young diagram) *)
TransposePartition[{}] := {}
TransposePartition[par_ ? PartitionQ] :=
    Table[LengthWhile[par, # >= j &], {j, First[par]}]

TransposePartition::notpar = "TransposePartition expects a valid partition, got `1`.";
TransposePartition[expr_] := (Message[TransposePartition::notpar, expr]; $Failed)


(* ============================================ *)
(* Hook Length Formula                          *)
(* ============================================ *)

(* Hook length at position (row, col) is:
   - cells to the right in the same row (including current)
   - plus cells below in the same column *)

(* Single cell hook length - O(1) using precomputed transpose *)
HookLength::range = "Position {`1`, `2`} is out of range for tableau of shape `3`.";

HookLength[yt : YoungTableau[rows_List] ? YoungTableauQ, {row_Integer, col_Integer}] :=
    With[{partition = Length /@ rows},
        If[1 <= row <= Length[partition] && 1 <= col <= partition[[row]],
            partition[[row]] - col + TransposePartition[partition][[col]] - row + 1,
            Message[HookLength::range, row, col, partition]; $Failed
        ]
    ]

HookLength::noyt = "HookLength accepts only YoungTableau as input, got `1`.";

HookLength[expr_, _] := (Message[HookLength::noyt, expr]; $Failed)


(* ============================================ *)
(* Hook Lengths (All at Once)                   *)
(* ============================================ *)

(* Compute all hook lengths for a partition efficiently - O(n) where n = total boxes *)
(* Returns a nested list matching the tableau shape *)

HookLengths[partition_ ? PartitionQ] :=
    With[{transposed = TransposePartition[partition]},
        Table[
            (* hook(i,j) = partition[i] - j + transposed[j] - i + 1 *)
            partition[[i]] - j + transposed[[j]] - i + 1,
            {i, Length[partition]},
            {j, partition[[i]]}
        ]
    ]

HookLengths[yt_YoungTableau ? YoungTableauQ] := HookLengths[TableauShape[yt]]

HookLengths::notpar = "HookLengths expects a valid partition or YoungTableau, got `1`.";

HookLengths[expr_] := (Message[HookLengths::notpar, expr]; $Failed)


(* ============================================ *)
(* Hook Factor (Frobenius Determinant Formula)  *)
(* ============================================ *)

(* HookFactor computes 1/(product of hook lengths) using the Vandermonde form
   of the Frobenius determinant. O(r^2) where r = number of rows.

   Formula: HookFactor[par] = Prod_{i<j}(l_i - l_j) / Prod l_i!
   where l_i = par[i] + r - i (strictly decreasing) and r = Length[par].

   The dimension of the irrep is: n! * HookFactor[par] where n = Total[par].
*)

(* Vandermonde product Prod_{i<j}(list[[i]] - list[[j]]). *)
frobeniusDet[{_Integer}] := 1
frobeniusDet[list_List] := Times @@ (Subtract @@@ Subsets[list, {2}])

HookFactor[partition_ ? PartitionQ] :=
    With[{shifted = partition + Range[Length[partition] - 1, 0, -1]},
        (* shifted[i] = partition[i] + (r - i); strictly decreasing. *)
        frobeniusDet[shifted] / Times @@ (Factorial /@ shifted)
    ]

HookFactor[yt_YoungTableau ? YoungTableauQ] := HookFactor[TableauShape[yt]]

HookFactor::notpar = "HookFactor expects a valid partition or YoungTableau, got `1`.";

HookFactor[expr_] := (Message[HookFactor::notpar, expr]; $Failed)


(* ============================================ *)
(* Tableau Dimension (Hook Length Formula)      *)
(* ============================================ *)

(* The dimension of the irrep corresponding to a Young diagram with n boxes is:
   d = n! / (product of all hook lengths) = n! * HookFactor[partition]

   We use the Frobenius determinant formula which is O(r^3) where r = number of rows,
   much faster than the naive O(n^2) approach for typical partitions.
*)

(* Fast path: directly from partition using HookFactor *)
TableauDimension[partition_List] /; PartitionQ[partition] :=
    Total[partition]! * HookFactor[partition]

(* From YoungTableau: extract shape and use fast path *)
TableauDimension[yt_YoungTableau ? YoungTableauQ] :=
    TableauDimension[TableauShape[yt]]

TableauDimension::noyt = "TableauDimension accepts only YoungTableau or partition as input, got `1`.";

TableauDimension[expr_] := (Message[TableauDimension::noyt, expr]; $Failed)


(* ============================================ *)
(* Schur / Weyl Module Dimension                *)
(* (hook-content formula for dim W_lambda(d))   *)
(* ============================================ *)

(* dim W_lambda(d) = Prod over cells (i, j) of (d + j - i) / hook(i, j).
   This is the value of the Schur polynomial s_lambda at the all-ones point
   of length d, and equals the rank of the single-tableau Young projector
   on (C^d)^{otimes n}. Accepts both numeric and symbolic d; for symbolic d
   the result is a polynomial in d (apply Simplify or Factor for closed form). *)

SchurDimension[partition_List ? PartitionQ, d_] :=
    With[{hooks = HookLengths[partition]},
        Product[
            (d + j - i) / hooks[[i, j]],
            {i, Length[partition]}, {j, partition[[i]]}
        ]
    ]

SchurDimension[yt_YoungTableau ? YoungTableauQ, d_] :=
    SchurDimension[TableauShape[yt], d]

SchurDimension::notpar = "SchurDimension expects a valid partition or YoungTableau, got `1`.";

SchurDimension[expr_, _] := (Message[SchurDimension::notpar, expr]; $Failed)


(* TableauWeylDimension is the tableau-keyed companion to TableauDimension.
   TableauDimension[tab] returns the S_n irrep dimension dim V_lambda
   (independent of d); TableauWeylDimension[tab, d] returns the GL(d) Weyl
   module dimension dim W_lambda(d). Their product is the size of the
   lambda-isotypic block of (C^d)^{otimes n}. *)

TableauWeylDimension[yt_YoungTableau ? YoungTableauQ, d_] :=
    SchurDimension[TableauShape[yt], d]

TableauWeylDimension::noyt = "TableauWeylDimension accepts only YoungTableau as input, got `1`.";

TableauWeylDimension[expr_, _] := (Message[TableauWeylDimension::noyt, expr]; $Failed)


(* ============================================ *)
(* Young Symmetrizer                            *)
(* ============================================ *)

(* The Young symmetrizer for a tableau:
   c_T = a_T · b_T where b_T symmetrizes rows and a_T antisymmetrizes columns.

   Standard order (following mathematical convention):
   1. First symmetrize over each row (b_T)
   2. Then antisymmetrize over each column (a_T)

   This order ensures column antisymmetry is preserved in the final result.
*)

YoungSymmetrize[tensor_ ? ArrayQ, yt : YoungTableau[rows_List] ? YoungTableauQ] :=
    Block[{n = TableauSize[yt], cols, rowScale, colScale, withRows},
        (* Check tensor rank matches tableau size *)
        If[ArrayDepth[tensor] != n,
            Message[YoungSymmetrize::rank, ArrayDepth[tensor], n];
            Return[$Failed]
        ];

        cols = getColumns[rows];

        (* Symmetrize averages over the group, but b_T and a_T are unnormalized
           sums. Multiply by the row/column stabilizer orders to recover them.
           Rows and columns of a Young tableau use pairwise-disjoint slot sets,
           so Symmetric /@ rows and Antisymmetric /@ cols are direct-product
           symmetry specifications. *)
        rowScale = Times @@ (Factorial /@ Length /@ rows);
        colScale = Times @@ (Factorial /@ Length /@ cols);

        withRows = rowScale Normal @ Symmetrize[tensor, Symmetric /@ rows];
        colScale Normal @ Symmetrize[withRows, Antisymmetric /@ cols]
    ]

YoungSymmetrize::rank = "Tensor rank `` does not match tableau size ``.";


(* Helper: Get columns from a Young tableau (handles ragged rows).
   Missing[] is the padding sentinel; the validator forbids it as a slot. *)
getColumns[rows_List] :=
    DeleteCases[#, _Missing] & /@ Transpose[PadRight[rows, Automatic, Missing[]]]


(* ============================================ *)
(* Young Projection (Normalized)                *)
(* ============================================ *)

(* The Young projector is normalized such that P^2 = P *)
(* Normalization factor is d/n! where d is the tableau dimension *)

YoungProject[tensor_ ? ArrayQ, yt : YoungTableau[rows_List] ? YoungTableauQ] :=
    Block[{symmetrized = YoungSymmetrize[tensor, yt]},
        If[symmetrized === $Failed,
            $Failed,
            TableauDimension[yt] / TableauSize[yt]! symmetrized
        ]
    ]


(* ============================================ *)
(* Convenience Constructors                     *)
(* ============================================ *)

(* Create standard tableau from partition *)
(* E.g., {3,2} -> YoungTableau[{{1,2,3},{4,5}}] *)

YoungTableau[partition_ ? PartitionQ] :=
    YoungTableau[TakeList[Range[Total[partition]], partition]]


(* ============================================ *)
(* Formatting                                   *)
(* ============================================ *)

YoungTableau /: MakeBoxes[yt : YoungTableau[rows_List] /; YoungTableauQ[Unevaluated[yt]], fmt_] :=
    With[{
        shape = TableauShape[yt],
        dim = TableauDimension[yt],
        nBoxes = TableauSize[yt],
        nRows = Length[rows],
        nCols = Max[Length /@ rows],
        cellPx = 16
    },
        BoxForm`ArrangeSummaryBox[
            YoungTableau,
            yt,
            (* Icon: Young diagram with cell entries. ImageSize is pinned in
               both dimensions so each cell is exactly cellPx square, regardless
               of shape (single-row shapes render wide-and-short, etc.). *)
            Graphics[{
                EdgeForm[Gray], White,
                Table[
                    Rectangle[{c - 1, -r}, {c, -r + 1}],
                    {r, nRows}, {c, Length[rows[[r]]]}
                ],
                Black,
                Table[
                    Text[Style[rows[[r, c]], 10], {c - 0.5, -r + 0.5}],
                    {r, nRows}, {c, Length[rows[[r]]]}
                ]
            }, ImageSize -> cellPx * {nCols, nRows}],
            (* Always shown *)
            {
                {BoxForm`SummaryItem[{"Shape: ", shape}]},
                {BoxForm`SummaryItem[{"Dimension: ", dim}]}
            },
            (* Expanded *)
            {
                BoxForm`SummaryItem[{"Boxes: ", nBoxes}],
                BoxForm`SummaryItem[{"Rows: ", rows}]
            },
            fmt
        ]
    ]
