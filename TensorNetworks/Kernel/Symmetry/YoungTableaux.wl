(* ::Package:: *)

Package["Wolfram`TensorNetworks`Symmetry`"]

(* Young Tableaux for tensor symmetry operations *)

PackageExport[YoungTableau]
PackageExport[YoungTableauQ]
PackageExport[TableauShape]
PackageExport[HookLength]
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

TableauShape[rows_List] /; youngTableauQ[YoungTableau[rows]] := Length /@ rows


(* ============================================ *)
(* Hook Length Formula                          *)
(* ============================================ *)

(* Hook length at position (row, col) is:
   - cells to the right in the same row (including current)
   - plus cells below in the same column *)

HookLength[YoungTableau[rows_List] ? YoungTableauQ, {row_Integer, col_Integer}] :=
    Module[{rowLen, colLen},
        (* Cells to the right including current cell *)
        rowLen = Length[rows[[row]]] - col + 1;
        (* Cells below in the same column *)
        colLen = Count[rows[[row + 1 ;;]], _?(Length[#] >= col &)];
        rowLen + colLen
    ]

HookLength[rows_List, pos_] /; youngTableauQ[YoungTableau[rows]] :=
    HookLength[YoungTableau[rows], pos]


(* ============================================ *)
(* Tableau Dimension (Hook Length Formula)      *)
(* ============================================ *)

(* The dimension of the irrep corresponding to a Young diagram with n boxes is:
   d = n! / (product of all hook lengths) *)

TableauDimension[yt : YoungTableau[rows_List] ? YoungTableauQ] :=
    Module[{n, hooks},
        n = Total[Length /@ rows];
        hooks = Flatten @ Table[
            HookLength[yt, {r, c}],
            {r, Length[rows]},
            {c, Length[rows[[r]]]}
        ];
        n! / Times @@ hooks
    ]

TableauDimension[rows_List] /; youngTableauQ[YoungTableau[rows]] :=
    TableauDimension[YoungTableau[rows]]


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
        n = Total[Length /@ rows];

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
        n = Total[Length /@ rows];
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
        nBoxes = Total[Length /@ rows]
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
