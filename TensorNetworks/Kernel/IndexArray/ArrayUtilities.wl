Package["Wolfram`TensorNetworks`IndexArray`"]

PackageImport["Wolfram`Arrays`"]

PackageExport[ArraySymmetry]

PackageScope[squareMatrixQ]



(* Array operations (ArrayDimensions, ArrayContract, ...) come from Wolfram/Arrays.
   Not re-exported: a second symbol per name would shadow them. PackageImport is file-scoped.
   Only ArraySymmetry lives here: Arrays has no symmetry API. *)


(* Storage wrappers (NumericArray, ByteArray, ...) are materialized; structured arrays stay native.
   Rank test first: {} for scalars and ragged input, without TensorSymmetry::rect. *)

ArraySymmetry[t_] := If[
    ArrayRank[t] == 0,
    {},
    Replace[
        TensorSymmetry[If[ArrayExplicitQ[t] && ! ArrayQ[t], ArrayMaterialize[t], t]],
        Except[_Symmetric | _Antisymmetric | _ZeroSymmetric] -> {}
    ]
]


(* local: not worth reaching into Arrays' private context *)

squareMatrixQ[t_] := MatchQ[ArrayDimensions[t], {n_, n_} | {_, 0}]
