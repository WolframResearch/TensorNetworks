
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

TreePathToPath[treePath_List ? TreePathQ, indices : _List | Automatic : Automatic] := Block[{len, index, path = {}},
	index = Replace[indices, Automatic :> Sort[Cases[treePath, {x_} :> x, All]]];
	len = Length[index];
	index = AssociationThread[List /@ index, Range[len]];
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

PathQ[{({_Integer} | {_Integer, _Integer}) ..}] := True
PathQ[___] := False

PathToTreePath[path_List ? PathQ, indices : _List | Automatic : Automatic] :=
	First @ Fold[
		{idx, pos} |-> Append[
			Delete[idx, List /@ pos],
			If[Length[pos] == 1, idx[[pos[[1]]]], idx[[pos]]]
		],
		List /@ Replace[indices, Automatic :> Range[Count[path, {_, _}] + 1]],
		path
	]


CanonicalPath[path_List ? PathQ, indices : _List | Automatic : Automatic] :=
	TreePathToPath[PathToTreePath[path, indices], indices]

CanonicalPathQ[{({_Integer, _Integer}) ..}] := True
CanonicalPathQ[___] := False

ContractIndices[i_, j_] := With[{c = Complement[Join[i, j], SymmetricDifference[i, j]]},
	c -> {DeleteElements[DeleteDuplicates[i], c], DeleteElements[DeleteDuplicates[j], c]}
]

PathIndexContractions[path : {{_Integer, _Integer} ...}, indices : {__List}] :=
	DeleteCases[{}] @ FoldPairList[
		With[{c = ContractIndices @@ #1[[#2]]}, {c[[1]], Append[Delete[#1, List /@ #2], Catenate[c[[2]]]]}] &,
		indices,
		path
	]

PathIndexContractions[path_List, indices : {__List}, contractions : {__List}] :=
	With[{index = First /@ PositionIndex[Catenate[indices]]},
		Map[Lookup[index, #] &, PathIndexContractions[path, contractions], {3}]
	]

PathIndexContractions[path_List, KeyValuePattern[{"Indices" -> indices_, "Contractions" -> contractions_}]] :=
	Catenate @ PathIndexContractions[path, indices, contractions]
