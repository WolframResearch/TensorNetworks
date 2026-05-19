
Package["Wolfram`TensorNetworks`"]

PackageExport[TreePathQ]
PackageExport[PathQ]
PackageExport[CanonicalPathQ]
PackageExport[TreePathToPath]
PackageExport[PathToTreePath]
PackageExport[CanonicalPath]
PackageExport[PathIndexContractions]



TreePathQ[{}] := False
TreePathQ[{_}] := True
TreePathQ[nodes_List] := AllTrue[nodes, TreePathQ]
TreePathQ[___] := False

TreePathToPath::indlen =
	"Length of indices `1` does not match the tree path's leaf count `2`. " <>
	"Pass a list whose length matches the number of singleton leaves in the tree path, " <>
	"or omit the indices argument to auto-derive them.";

TreePathToPath[treePath_List ? TreePathQ, indices_List] :=
	With[{leafCount = Length[Cases[treePath, {_}, {0, Infinity}]]},
		If[Length[indices] =!= leafCount,
			Message[TreePathToPath::indlen, Length[indices], leafCount];
			$Failed,
			doTreePathToPath[treePath, indices]
		]
	]

TreePathToPath[treePath_List ? TreePathQ, Automatic : Automatic] :=
	doTreePathToPath[treePath, Sort[Cases[treePath, {x_} :> x, All]]]

TreePathToPath[treePath_List ? TreePathQ] :=
	doTreePathToPath[treePath, Sort[Cases[treePath, {x_} :> x, All]]]

doTreePathToPath[treePath_, indices_] := Block[{len, index, path = {}},
	len = Length[indices];
	index = AssociationThread[List /@ indices, Range[len]];
	Scan[
		Block[{pos = Lookup[index, #], min, max, k},
			{min, max} = MinMax[pos];
			k = Length[pos];
			AppendTo[path, pos];
			index = Map[Which[# < min, #, # > max, # - k, True, # - 1] &, index];
			KeyDropFrom[index, #];
			AppendTo[index, # -> --len]
		] &,
		treePath,
		{0, -3}
	];
	path
]

PathQ[{}] := True
PathQ[{({_Integer} | {_Integer, _Integer}) ..}] := True
PathQ[___] := False

PathToTreePath::indlen =
	"Length of indices `1` does not match the path's required arity `2` " <>
	"(= Count[path, {_, _}] + 1). For a TN with hyper-edges, the path is over " <>
	"the binarized network — pass BinaryTensorNetwork[tn][\"Vertices\"] or omit " <>
	"the indices argument to auto-derive them.";

PathToTreePath[path_List ? PathQ, indices : _List | Automatic : Automatic] :=
	With[{required = Count[path, {_, _}] + 1},
		Which[
			indices === Automatic,
				doPathToTreePath[path, Range[required]],
			Length[indices] =!= required,
				Message[PathToTreePath::indlen, Length[indices], required];
				$Failed,
			True,
				doPathToTreePath[path, indices]
		]
	]

doPathToTreePath[path_, indices_] :=
	First @ Fold[
		{idx, pos} |-> Append[
			Delete[idx, List /@ pos],
			If[Length[pos] == 1, idx[[pos[[1]]]], idx[[pos]]]
		],
		List /@ indices,
		path
	]


CanonicalPath[{}, ___] := {}
CanonicalPath[path_List ? PathQ, indices : _List | Automatic : Automatic] :=
	TreePathToPath[PathToTreePath[path, indices], indices]

CanonicalPathQ[{}] := True
CanonicalPathQ[{({_Integer, _Integer}) ..}] := True
CanonicalPathQ[___] := False

ContractIndices[i_, j_] := With[{c = Complement[Join[i, j], SymmetricDifference[i, j]]},
	c -> {DeleteElements[DeleteDuplicates[i], c], DeleteElements[DeleteDuplicates[j], c]}
]

PathIndexContractions::indlen =
	"Length of indices `1` does not match the path's required arity `2` " <>
	"(= Length[path] + 1). For a TN with hyper-edges, the path is over the " <>
	"binarized network — pass BinaryTensorNetwork[tn][\"Indices\"] / [\"Hyperedges\"] " <>
	"or use Automatic.";

PathIndexContractions[path : {{_Integer, _Integer} ...}, indices : {__List}] :=
	With[{required = Length[path] + 1},
		If[Length[indices] =!= required,
			Message[PathIndexContractions::indlen, Length[indices], required];
			$Failed,
			DeleteCases[{}] @ FoldPairList[
				With[{c = ContractIndices @@ #1[[#2]]}, {c[[1]], Append[Delete[#1, List /@ #2], Catenate[c[[2]]]]}] &,
				indices,
				path
			]
		]
	]

PathIndexContractions[path_List, indices : {__List}, contractions : {__List}] :=
	With[{index = First /@ PositionIndex[Catenate[indices]]},
		Map[Lookup[index, #] &, PathIndexContractions[path, contractions], {3}]
	]

PathIndexContractions[path_List, KeyValuePattern[{"Indices" -> indices_, "Contractions" -> contractions_}]] :=
	Catenate @ PathIndexContractions[path, indices, contractions]
