(* ::Package:: *)

Package["Wolfram`TensorNetworks`Symmetry`"]

(* Young Tableaux for tensor symmetry operations *)

PackageExport[YoungTableau]
PackageExport[YoungTableauQ]
PackageExport[PartitionQ]
PackageExport[TransposePartition]
PackageExport[TableauShape]
PackageExport[TableauSize]
PackageExport[HookLength]
PackageExport[HookLengths]
PackageExport[HookFactor]
PackageExport[TableauDimension]
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
    (* All entries are distinct positive integers *)
    With[{flat = Flatten[rows]},
        And[
            AllTrue[flat, IntegerQ[#] && # > 0 &],
            DuplicateFreeQ[flat]
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
TransposePartition[par_List] /; PartitionQ[par] :=
    Table[Count[par, x_ /; x >= j], {j, par[[1]]}]

TransposePartition::notpar = "TransposePartition expects a valid partition, got `1`.";
TransposePartition[expr_] := (Message[TransposePartition::notpar, expr]; $Failed)


(* ============================================ *)
(* Hook Length Formula                          *)
(* ============================================ *)

(* Hook length at position (row, col) is:
   - cells to the right in the same row (including current)
   - plus cells below in the same column *)

(* Single cell hook length - O(1) using precomputed transpose *)
HookLength[YoungTableau[rows_List] ? YoungTableauQ, {row_Integer, col_Integer}] :=
    Module[{partition, transposed, armLength, legLength},
        partition = Length /@ rows;
        transposed = TransposePartition[partition];
        (* Arm length: cells to the right (excluding current) *)
        armLength = partition[[row]] - col;
        (* Leg length: cells below (excluding current) *)
        legLength = transposed[[col]] - row;
        (* Hook = arm + leg + 1 (current cell) *)
        armLength + legLength + 1
    ]

HookLength::noyt = "HookLength accepts only YoungTableau as input, got `1`.";

HookLength[expr_, _] := (Message[HookLength::noyt, expr]; $Failed)


(* ============================================ *)
(* Hook Lengths (All at Once)                   *)
(* ============================================ *)

(* Compute all hook lengths for a partition efficiently - O(n) where n = total boxes *)
(* Returns a nested list matching the tableau shape *)

HookLengths[partition_List] /; PartitionQ[partition] :=
    Module[{transposed},
        transposed = TransposePartition[partition];
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

(* HookFactor computes 1/(product of hook lengths) using the Frobenius determinant.
   This is more efficient for partitions with few rows: O(r^3) where r = number of rows.

   Formula: HookFactor[par] = det(C(par[i]-i+r, j-1)) / prod(par[i]-i+r)!
   where r = Length[par] and C(n,k) = Binomial(n,k)

   The dimension of the irrep is: n! * HookFactor[par] where n = Total[par]
*)

(* Determinant helper for Frobenius formula *)
frobeniusDet[{x_Integer}] := 1
frobeniusDet[list_List] := Det[Outer[Binomial, list, Range[0, Length[list] - 1]]]

HookFactor[partition_List] /; PartitionQ[partition] :=
    Module[{r, shifted},
        r = Length[partition];
        (* Shift: par[i] - i + r *)
        shifted = partition - Range[r] + r;
        (* Frobenius formula *)
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
    Module[{n, cols, rowSymResult, result},
        n = TableauSize[yt];

        (* Check tensor rank matches tableau size *)
        If[ArrayDepth[tensor] != n,
            Message[YoungSymmetrize::rank, ArrayDepth[tensor], n];
            Return[$Failed]
        ];

        (* Get columns from rows - need to handle ragged arrays *)
        cols = getColumns[rows];

        (* Step 1: Symmetrize over rows FIRST (b_T) *)
        rowSymResult = tensor;
        Do[
            rowSymResult = symmetrizeOverIndices[rowSymResult, rows[[i]]],
            {i, Length[rows]}
        ];

        (* Step 2: Antisymmetrize over columns SECOND (a_T) *)
        result = rowSymResult;
        Do[
            result = antisymmetrizeOverIndices[result, cols[[j]]],
            {j, Length[cols]}
        ];

        result
    ]

YoungSymmetrize::rank = "Tensor rank `` does not match tableau size ``.";


(* Helper: Get columns from a Young tableau (handles ragged rows) *)
getColumns[rows_List] := Module[{maxCols, cols},
    maxCols = Length[rows[[1]]];  (* First row is longest *)
    cols = Table[
        Select[Table[If[Length[rows[[r]]] >= c, rows[[r, c]], Nothing], {r, Length[rows]}], IntegerQ],
        {c, maxCols}
    ];
    cols
]


(* Helper: Symmetrize tensor over a set of indices *)
(* Sum over all permutations of the given indices *)
symmetrizeOverIndices[tensor_, indices_List] := Module[{perms},
    If[Length[indices] <= 1, Return[tensor]];
    perms = Permutations[indices];
    Total[applyIndexPermutation[tensor, indices, #] & /@ perms]
]


(* Helper: Antisymmetrize tensor over a set of indices *)
(* Sum over all permutations with signature *)
antisymmetrizeOverIndices[tensor_, indices_List] := Module[{perms},
    If[Length[indices] <= 1, Return[tensor]];
    perms = Permutations[indices];
    Total[(Signature[#] * applyIndexPermutation[tensor, indices, #]) & /@ perms]
]


(* Helper: Apply a permutation to specific indices of a tensor *)
(* indices: the tensor index positions to permute (e.g., {1,2,3})
   perm: the permuted ordering (e.g., {2,3,1} gives T[[j,k,i]] from T[[i,j,k]]) *)
applyIndexPermutation[tensor_, indices_List, perm_List] := Module[{n, fullPerm, rules},
    n = ArrayDepth[tensor];
    (* Build the full permutation: identity on non-permuted indices *)
    fullPerm = Range[n];
    (* Replace only the indices we're permuting *)
    rules = Thread[indices -> perm];
    fullPerm = fullPerm /. rules;

    (* Transpose[T, {2,3,1}][[i,j,k]] = T[[j,k,i]] *)
    (* The perm directly specifies the transpose operation *)
    Transpose[tensor, fullPerm]
]


(* ============================================ *)
(* Young Projection (Normalized)                *)
(* ============================================ *)

(* The Young projector is normalized such that P^2 = P *)
(* Normalization factor is d/n! where d is the tableau dimension *)

YoungProject[tensor_ ? ArrayQ, yt : YoungTableau[rows_List] ? YoungTableauQ] :=
    Module[{n, d, symmetrized},
        n = TableauSize[yt];
        d = TableauDimension[yt];
        symmetrized = YoungSymmetrize[tensor, yt];
        If[symmetrized === $Failed, Return[$Failed]];
        (d / n!) * symmetrized
    ]


(* ============================================ *)
(* Convenience Constructors                     *)
(* ============================================ *)

(* Create standard tableau from partition *)
(* E.g., {3,2} -> YoungTableau[{{1,2,3},{4,5}}] *)

YoungTableau[partition_List] /; AllTrue[partition, IntegerQ[#] && # > 0 &] && OrderedQ[partition, GreaterEqual] :=
    Module[{rows, idx = 1},
        rows = Table[
            Table[idx++, {partition[[i]]}],
            {i, Length[partition]}
        ];
        YoungTableau[rows]
    ]


(* ============================================ *)
(* Formatting                                   *)
(* ============================================ *)

YoungTableau /: MakeBoxes[yt : YoungTableau[rows_List] /; YoungTableauQ[Unevaluated[yt]], fmt_] :=
    With[{
        shape = TableauShape[yt],
        dim = TableauDimension[yt],
        nBoxes = TableauSize[yt]
    },
        BoxForm`ArrangeSummaryBox[
            YoungTableau,
            yt,
            (* Icon: simple Young diagram visualization *)
            Graphics[{
                EdgeForm[Gray], White,
                Table[
                    Rectangle[{c - 1, -r}, {c, -r + 1}],
                    {r, Length[rows]}, {c, Length[rows[[r]]]}
                ]
            }, ImageSize -> 32, AspectRatio -> 1],
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
