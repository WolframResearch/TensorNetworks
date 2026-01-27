(* ::Package:: *)

Package["Wolfram`TensorNetworks`"]

PackageExport[TensorNetworkFindContractionPath]

PackageExport[$TensorNetworkContractionMethods]
PackageExport[TensorNetworkContraction]
PackageExport[TensorNetworkContract]

PackageExport[ContractionTree]



Options[TensorNetworkFindContractionPath] = {"ReturnParameters" -> False, Method -> "Optimal"}

TensorNetworkFindContractionPath[KeyValuePattern[{
    "Dimensions" -> tensorDimensions_,
    "Indices" -> tensorIndices_,
    "Contractions" -> contractions_
}], OptionsPattern[]] := Enclose @ Block[{
	dimensions, pairs, rules, indices, normalIndices, input, output
},
	dimensions = AssociationThread[Catenate[tensorIndices], Catenate[tensorDimensions]];
	pairs = Cases[Catenate[contractions], {_, _}];
	rules = Rule @@@ pairs;
	ConfirmAssert[AllTrue[Partition[Lookup[dimensions, Catenate[pairs]], 2], Apply[Equal]]];
	dimensions = KeyMap[Replace[rules], dimensions];
	indices = Replace[tensorIndices, rules, {2}];
	normalIndices = Thread[# -> Range[Length[#]]] & [Union @@ indices];
	input = Replace[indices, normalIndices, {2}];
	output = Replace[Cases[Catenate[contractions], Except[{_, _}]], normalIndices, 1];
	dimensions = KeyMap[Replace[normalIndices], dimensions];
	If[TrueQ[OptionValue["ReturnParameters"]], Return[{input, output, dimensions}]];
	CanonicalPath @ Replace[Replace[OptionValue[Method], "Optimal" -> "size"], {
        method : "flops" | "max" | "size" | "write" | "combo" | "limit" :> OptimalPath[input, output, dimensions, method],
        _ :> GreedyPath[input, output, dimensions]
    }]
]

TensorNetworkFindContractionPath[net_Graph ? TensorNetworkGraphQ, opts : OptionsPattern[]] :=
    TensorNetworkFindContractionPath[TensorNetworkGraphData[net], opts]

TensorNetworkFindContractionPath[net_TensorNetwork ? TensorNetworkQ, opts : OptionsPattern[]] :=
    TensorNetworkFindContractionPath[TensorNetworkData[BinaryTensorNetwork[net]], opts]

einsumArrayDot[{i_, j_} -> out_, a_, b_, inactiveQ : _ ? BooleanQ : False] := Block[{
	c = DeleteElements[DeleteDuplicates @ Join[i, j], Replace[out, Automatic :> SymmetricDifference[i, j]]],
	k, perm,
	al, br, x, y,
	aIndex = First /@ PositionIndex[i], bIndex = First /@ PositionIndex[j],
	inactive = If[inactiveQ, Function[f, Inactive[f][##] &], Identity]
},
	al = DeleteElements[i, c];
	br = DeleteElements[j, c];
	k = Length[c];
	If[ k == 0
		,
		x = inactive[TensorProduct][a, b]
		,
		x = inactive[ArrayDot][a, b, Thread[{Lookup[aIndex, c], Lookup[bIndex, c]}]];
	];
	If[ out === Automatic,
		{x, Join[al, br]}
		,
		perm = FindPermutation[Join[al, br], out];
		If[perm === Cycles[{}], x, inactive[Transpose][x, perm]]
	]
]

einsumArrayDotTranspose[{i_, j_} -> out_, a_, b_, inactiveQ : _ ? BooleanQ : False] := Block[{
	c = DeleteElements[DeleteDuplicates @ Join[i, j], Replace[out, Automatic :> SymmetricDifference[i, j]]],
	k, perm,
	al, br, x, y,
	inactive = If[inactiveQ, Function[f, Inactive[f][##] &], Identity]
},
	al = DeleteElements[i, c];
	br = DeleteElements[j, c];
	k = Length[c];
	If[ k == 0
		,
		x = inactive[TensorProduct][a, b]
		,
		perm = FindPermutation[i, Join[al, c]];
		x = If[perm === Cycles[{}], a, inactive[Transpose][a, perm]];
		perm = FindPermutation[j, Join[c, br]];
		y = If[perm === Cycles[{}], b, inactive[Transpose][b, perm]];
		x = inactive[ArrayDot][x, y, k];
	];
	If[ out === Automatic,
		{x, Join[al, br]}
		,
		perm = FindPermutation[Join[al, br], out];
		If[perm === Cycles[{}], x, inactive[Transpose][x, perm]]
	]
]

einsumTensorContract[{i_, j_} -> out_, a_, b_, inactiveQ : _ ? BooleanQ : False] := Block[{
	c = DeleteElements[DeleteDuplicates @ Join[i, j], Replace[out, Automatic :> SymmetricDifference[i, j]]],
	k, perm,
	al, br, x,
	aIndex = First /@ PositionIndex[i], bIndex = First /@ PositionIndex[j],
	inactive = If[inactiveQ, Function[f, Inactive[f][##] &], Identity]
},
	al = DeleteElements[i, c];
	br = DeleteElements[j, c];
	k = Length[c];
	If[ k == 0
		,
		x = inactive[TensorProduct][a, b]
		,
		x = inactive[TensorContract][
			inactive[TensorProduct][a, b],
			MapThread[{#1, #2 + Length[i]} &,
				{Lookup[aIndex, c], Lookup[bIndex, c]}
			]
		]
	];
	If[ out === Automatic,
		{x, Join[al, br]}
		,
		perm = FindPermutation[Join[al, br], out];
		If[perm === Cycles[{}], x, inactive[Transpose][x, perm]]
	]
]

einsumDot[{i_, j_} -> out_, a_, b_, inactiveQ : _ ? BooleanQ : False] := Block[{
	c = DeleteElements[DeleteDuplicates @ Join[i, j], Replace[out, Automatic :> SymmetricDifference[i, j]]],
	k, perm,
	al, br, x, y,
	inactive = If[inactiveQ, Function[f, Inactive[f][##] &], Identity],
	aIndex = PositionIndex[i], bIndex = PositionIndex[j],
	aDim = symbolicTensorDimensions[a], bDim = symbolicTensorDimensions[b],
	reshape
},
	reshape[t_, newShape_] := If[symbolicTensorDimensions[t] === newShape, t, inactive[ArrayReshape][t, newShape]];
	al = DeleteElements[i, c];
	br = DeleteElements[j, c];
	k = Length[c];
	If[ k == 0,
		x = inactive[TensorProduct][a, b]
		,
		perm = FindPermutation[i, Join[al, c]];
		x = If[perm === Cycles[{}], a, inactive[Transpose][a, perm]];
		perm = FindPermutation[j, Join[c, br]];
		y = If[perm === Cycles[{}], b, inactive[Transpose][b, perm]];
		If[ k == 1,
			x = inactive[Dot][x, y]
			,
			x = inactive[Dot][
				reshape[x, Catenate[MapAt[{Times @@ #} &, {2}] @ (Extract[aDim, Lookup[aIndex, #]] & /@ {al, c})]],
				reshape[y, Catenate[MapAt[{Times @@ #} &, {1}] @ (Extract[bDim, Lookup[bIndex, #]] & /@ {c, br})]]
			];
			x = reshape[x, Join[Extract[aDim, Lookup[aIndex, al]], Extract[bDim, Lookup[bIndex, br]]]]
		];
	];
	If[ out === Automatic,
		{x, Join[al, br]}
		,
		perm = FindPermutation[Join[al, br], out];
		If[perm === Cycles[{}], x, inactive[Transpose][x, perm]]
	]
]

einsumTableSum[{i_, j_} -> out_, a_, b_, inactiveQ : _ ? BooleanQ : False] := Block[{
	c = DeleteElements[DeleteDuplicates @ Join[i, j], Replace[out, Automatic :> SymmetricDifference[i, j]]],
	k, perm,
	al, br, x, y,
	inactive = If[inactiveQ, Function[f, Inactive[f][##] &], Identity],
	aIndex = PositionIndex[i], bIndex = PositionIndex[j],
	aDim = symbolicTensorDimensions[a], bDim = symbolicTensorDimensions[b]
},
	
	al = DeleteElements[i, c];
	br = DeleteElements[j, c];
	k = Length[c];
	
	If[ k == 0
		,
		x = With[{
			p1 = Symbol["\[FormalI]" <> ToString[#]] & /@ Range[Length[al]],
			p2 = Symbol["\[FormalJ]" <> ToString[#]] & /@ Range[Length[br]]
		},
			inactive[With][{inactive[Set][\[FormalCapitalA], a], inactive[Set][\[FormalCapitalB], b]},
				inactive[Table][(inactive[Part][\[FormalCapitalA], ##] & @@ p1) * (inactive[Part][\[FormalCapitalB], ##] & @@ p2), ##] & @@ Join[
					MapIndexed[{Symbol["\[FormalI]" <> ToString[#2[[1]]]], #1} &, aDim],
					MapIndexed[{Symbol["\[FormalJ]" <> ToString[#2[[1]]]], #1} &, bDim]
				]
			]
		]
		,
		x = With[{
			p1 = ReplacePart[i, Join[
				Thread[Lookup[aIndex, al] -> (Symbol["\[FormalI]" <> ToString[#]] & /@ Range[Length[al]])],
				Thread[Lookup[aIndex, c] -> (Symbol["\[FormalC]" <> ToString[#]] & /@ Range[Length[c]])]
			]],
			p2 = ReplacePart[j, Join[
				Thread[Lookup[bIndex, br] -> (Symbol["\[FormalJ]" <> ToString[#]] & /@ Range[Length[br]])],
				Thread[Lookup[bIndex, c] -> (Symbol["\[FormalC]" <> ToString[#]] & /@ Range[Length[c]])]
			]],
			cs = MapIndexed[{Symbol["\[FormalC]" <> ToString[#2[[1]]]], #1} &, Extract[aDim, Lookup[aIndex, c]]]
		},
			inactive[With][{inactive[Set][\[FormalCapitalA], a], inactive[Set][\[FormalCapitalB], b]},
				inactive[Table][
					inactive[Sum][(inactive[Part][\[FormalCapitalA], ##] & @@ p1) * (inactive[Part][\[FormalCapitalB], ##] & @@ p2), ##] & @@ cs,
					## 
				] & @@ Join[
					MapIndexed[{Symbol["\[FormalI]" <> ToString[#2[[1]]]], #1} &, Extract[aDim, Lookup[aIndex, al]]],
					MapIndexed[{Symbol["\[FormalJ]" <> ToString[#2[[1]]]], #1} &, Extract[bDim, Lookup[bIndex, br]]]
				]
			]	
		]
	];
	If[ out === Automatic,
		{x, Join[al, br]}
		,
		perm = FindPermutation[Join[al, br], out];
		If[perm === Cycles[{}], x, inactive[Transpose][x, perm]]
	]
]


$TensorNetworkContractionMethods = {"ArrayDotTranspose", "ArrayDot", "Dot", "TensorContract", "TableSum"}

Options[contractTensorPair] = {Method -> "ArrayDot", "Inactive" -> True}

contractTensorPair[{tensor1_ -> indices1_, tensor2_ -> indices2_}, OptionsPattern[]] :=
	Switch[
		OptionValue[Method],
		"ArrayDotTranspose", einsumArrayDotTranspose,
		"ArrayDot", einsumArrayDot,
		"Dot", einsumDot,
		"TensorContract", einsumTensorContract,
		"TableSum", einsumTableSum
	][{indices1, indices2} -> Automatic, tensor1, tensor2, TrueQ[OptionValue["Inactive"]]]


Options[TensorNetworkContraction] = Join[Options[contractTensorPair], {"TransposeFunction" -> Transpose}]

TensorNetworkContraction[net_Graph ? TensorNetworkGraphQ, args___] :=
    TensorNetworkContraction[TensorNetworkGraphData[net], args]

TensorNetworkContraction[net_TensorNetwork ? TensorNetworkQ, args__] :=
    TensorNetworkContraction[TensorNetworkData[BinaryTensorNetwork[net]], args]
    
TensorNetworkContraction[net_TensorNetwork ? TensorNetworkQ] :=
    TensorNetworkContraction[TensorNetworkData[net]]

TensorNetworkContraction[data : KeyValuePattern["Vertices" -> vertices_], path_ ? CanonicalPathQ, opts : OptionsPattern[]] := 
    TensorNetworkContraction[data, PathToTreePath[path, vertices], opts]
    
TensorNetworkContraction[net_, method_String, opts : OptionsPattern[]] := 
    TensorNetworkContraction[net, TensorNetworkFindContractionPath[net, Method -> method], opts]

TensorNetworkContraction[
    KeyValuePattern[{
		"Vertices" -> vertices_,
		"Tensors" -> tensors_,
		"ContractionIndices" -> contractions_,
        "FreeIndices" -> freeIndices_
	}],
    treePath_ ? TreePathQ,
    opts : OptionsPattern[]
] := With[{
    contractOpts = FilterRules[{opts}, Options[contractTensorPair]]
}, {
    tensorPath = FixedPoint[
        ReplaceAll[{"Pair"[t1_, i1_], "Pair"[t2_, i2_]} :> "Pair" @@ contractTensorPair[{t1 -> i1, t2 -> i2}, contractOpts]],
        Replace[treePath, MapThread[{#1} -> "Pair"[#2, #3] &, {vertices, tensors, contractions}], {-2}]
    ],
    transposeFunction = OptionValue["TransposeFunction"]
},
    With[{perm = FindPermutation[tensorPath[[2]], freeIndices]},
		If[ perm === Cycles[{}],
			tensorPath[[1]],
			If[TrueQ[OptionValue["Inactive"]], Inactive, Identity][transposeFunction][
				tensorPath[[1]],
				FindPermutation[tensorPath[[2]], freeIndices]
			]
		]
    ]
]

TensorNetworkContraction[
    KeyValuePattern[{
		"Tensors" -> tensors_,
		"ContractionIndices" -> indices_,
        "FreeIndices" -> freeIndices_
	}],
	OptionsPattern[]
] := If[TrueQ[OptionValue["Inactive"]], Identity, ActivateTensors] @ EinsteinSummation[indices -> freeIndices, tensors]


Options[TensorNetworkContract] = Options[TensorNetworkContraction]

TensorNetworkContract[data_ ? AssociationQ, path : Automatic | _String | _ ? CanonicalPathQ, opts : OptionsPattern[]] :=
	TensorNetworkContraction[data, path, opts, "Inactive" -> False]

TensorNetworkContract[net_Graph ? TensorNetworkGraphQ, args___] := TensorNetworkContract[TensorNetworkGraphData[net], args]

TensorNetworkContract[net_TensorNetwork ? TensorNetworkQ, args___] := TensorNetworkContract[TensorNetworkData[BinaryTensorNetwork[net]], args]

TensorNetworkContract[net_, opts : OptionsPattern[]] := TensorNetworkContraction[net, opts, "Inactive" -> False]



contractionTree[IgnoringInactive[t : HoldPattern @ ArrayDot[x_, y_, k_]]] := Tree[Subscript[symbolicTensorDimensions[t], Underscript["\[CenterDot]", k]], {contractionTree[x], contractionTree[y]}]
contractionTree[IgnoringInactive[t : HoldPattern @ Dot[x_, y_]]] := Tree[Subscript[symbolicTensorDimensions[t], "\[CenterDot]"], {contractionTree[x], contractionTree[y]}]
contractionTree[IgnoringInactive[t : HoldPattern @ Transpose[x_, perm_]]] := Tree[DirectedEdge[symbolicTensorDimensions[x], symbolicTensorDimensions[t], perm], {contractionTree[x]}]
contractionTree[IgnoringInactive[t : HoldPattern @ ArrayReshape[x_, shape_]]] := Tree[symbolicTensorDimensions[x] -> shape, {contractionTree[x]}]
contractionTree[IgnoringInactive[t : HoldPattern @ TensorProduct[xs__]]] := Tree[Subscript[symbolicTensorDimensions[t], "\[CircleTimes]"], contractionTree /@ {xs}]
contractionTree[IgnoringInactive[t : HoldPattern @ TensorContract[x_, c_]]] := Tree[Subscript[symbolicTensorDimensions[t], c], {contractionTree[x]}]
contractionTree[x_] := symbolicTensorDimensions[x]

toSymbolicTensorAll[x_] := ArraySymbol["T", symbolicTensorDimensions[x]]

contractionTreeNamed[IgnoringInactive[t : HoldPattern @ ArrayDot[x_, y_, k_]]] := Tree[Inactive[ArrayDot][toSymbolicTensorAll[x], toSymbolicTensorAll[y], k], {contractionTreeNamed[x], contractionTreeNamed[y]}]
contractionTreeNamed[IgnoringInactive[t : HoldPattern @ Dot[x_, y_]]] := Tree[Inactive[Dot][toSymbolicTensorAll[x], toSymbolicTensorAll[y]], {contractionTreeNamed[x], contractionTreeNamed[y]}]
contractionTreeNamed[IgnoringInactive[t : HoldPattern @ Transpose[x_, perm_]]] := Tree[Transpose[toSymbolicTensorAll[x], perm], {contractionTreeNamed[x]}]
contractionTreeNamed[IgnoringInactive[t : HoldPattern @ ArrayReshape[x_, shape_]]] := Tree[Inactive[ArrayReshape][toSymbolicTensorAll[x], shape], {contractionTreeNamed[x]}]
contractionTreeNamed[IgnoringInactive[t : HoldPattern @ TensorProduct[xs__]]] := Tree[TensorProduct @@ toSymbolicTensorAll /@ {xs}, contractionTreeNamed /@ {xs}]
contractionTreeNamed[IgnoringInactive[t : HoldPattern @ TensorContract[x_, c_]]] := Tree[Inactive[TensorContract][toSymbolicTensorAll[x], c], {contractionTreeNamed[x]}]
contractionTreeNamed[x_] := toSymbolicTensorAll[x]

Options[ContractionTree] = Join[Options[Tree], {"Labels" -> Automatic}]

ContractionTree[expr_, opts : OptionsPattern[]] :=
	Tree[
		If[OptionValue["Labels"] === "Dimensions", contractionTree[expr], Tree[toSymbolicTensorAll[expr], {contractionTreeNamed[expr]}]],
		FilterRules[
			{opts, AspectRatio -> 1 / 2, TreeLayout -> Right, TreeElementLabelStyle -> {All -> FontSize -> 6}},
			Options[Tree]
		]
	]
