Package["Wolfram`TensorNetworks`"]

PackageExport[ContractTensorNetwork]

PackageExport[TensorNetworkContractionPath]
PackageExport[TensorNetworkContractPath]

PackageExport[TensorNetworkContraction]
PackageExport[$TensorNetworkContractionMethods]



NeighborhoodEdges[g_, vs_List] := Catenate[EdgeList[g, _[#, __] | _[_, #, ___]] & /@ vs]
NeighborhoodEdges[g_, v_] := NeighborhoodEdges[g, {v}]

(* temporary due to EdgeContract bug *)
edgeContract[g_, edge_] := With[{edges = NeighborhoodEdges[g, edge[[1]]]},
	EdgeAdd[EdgeDelete[g, edges], Replace[DeleteCases[edges, edge], {
		head_[edge[[1]], edge[[1]], rest___] :> head[edge[[2]], edge[[2]], rest],
		head_[edge[[1]], rest___] :> head[edge[[2]], rest],
		head_[v_, edge[[1]], rest___] :> head[v, edge[[2]], rest]
	}, {1}]]
]

edgeContractWithIndex[g_, edge : _[from_, to_, {i_, j_}]] := Annotate[
	{edgeContract[g, edge], to},
	"Index" -> If[
		from === to,
		DeleteCases[AnnotationValue[{g, to}, "Index"], i | j],
		DeleteCases[Join[AnnotationValue[{g, from}, "Index"], AnnotationValue[{g, to}, "Index"]], i | j]
	]
]

ContractEdge[g_, edge : _[from_, to_, {i_, j_}]] := Enclose @ Block[{
	tensors = Confirm[AnnotationValue[{g, {from, to}}, "Tensor"]],
	indices = Confirm[AnnotationValue[{g, {from, to}}, "Index"]],
	rank
},
	rank = tensorRank[tensors[[1]]];
	Annotate[
		{edgeContractWithIndex[g, edge], to},
		"Tensor" -> TensorContract[
			TensorProduct[tensors[[1]], tensors[[2]]],
			{Confirm[FirstPosition[indices[[1]], i]][[1]], rank + Confirm[FirstPosition[indices[[2]], j]][[1]]}
		]
	]
]

ContractEdge[g_, edge : _[v_, v_, {i_, j_}]] := Enclose @ Block[{
	tensor = Confirm[AnnotationValue[{g, v}, "Tensor"]],
	index = Confirm[AnnotationValue[{g, v}, "Index"]]
},
	Annotate[{edgeContractWithIndex[g, edge], v}, "Tensor" -> TensorContract[tensor, {Catenate @ Position[index, i | j]}]]
]


NaiveContractTensorNetwork[net_Graph] := Enclose @ Block[{g, edges, ordering},
	{g, {edges}} = Reap @ NestWhile[Confirm @ ContractEdge[#, Sow @ First[EdgeList[#]]] &, net, EdgeCount[#] > 0 &];
    ordering = Ordering @ OrderingBy[AnnotationValue[{g, edges[[-1, 2]]}, "Index"], Replace[{Subscript[_, x_] :> {x}, Superscript[_, x_] :> x}]];
	If[ordering === {}, #, Transpose[#, ordering]] & @ AnnotationValue[{g, edges[[-1, 2]]}, "Tensor"]
]

FastContractTensorNetwork[net_Graph] := Enclose[
    Block[{indices, outIndices, tensors, scalarPositions, scalars},
        indices = TensorNetworkIndices[net] /. Rule @@@ EdgeTags[net];
        tensors =  TensorNetworkTensors[net];
        outIndices = TensorNetworkFreeIndices[net];
        If[MemberQ[tensors, {}], Return[ArrayReshape[{}, Append[Table[1, Length[outIndices] - 1], 0]]]];
        scalarPositions = Position[indices, {}, {1}, Heads -> False];
        scalars = Extract[tensors, scalarPositions];
        indices = Delete[indices, scalarPositions];
        tensors = Delete[tensors, scalarPositions];
        Times @@ scalars * ActivateTensor @ Confirm[EinsteinSummation[indices -> outIndices, tensors]]
    ],
    (ReleaseHold[#["HeldMessageCall"]]; #) &
]

Options[ContractTensorNetwork] = {Method -> Automatic}

ContractTensorNetwork[net_Graph ? (TensorNetworkGraphQ[True]), OptionsPattern[]] := Switch[
    OptionValue[Method],
    "Naive",
    NaiveContractTensorNetwork[net],
    _,
    FastContractTensorNetwork[net]
]


Options[TensorNetworkContractionPath] = {"ReturnParameters" -> False, Method -> Automatic}

TensorNetworkContractionPath[KeyValuePattern[{
    "Tensors" -> tensors_,
    "Indices" -> tensorIndices_,
    "Contractions" -> contractions_,
    "FreeIndices" -> freeIndices_
}], OptionsPattern[]] := Enclose @ Block[{
	dimensions, rules, indices, normalIndices, input, output
},
	dimensions = AssociationThread[Catenate[tensorIndices], Catenate[tensorDimensions /@ tensors]];
	rules = Rule @@@ Catenate[contractions];
	ConfirmAssert[AllTrue[Partition[Lookup[dimensions, rules[[All, 1]]], 2], Apply[Equal]]];
	dimensions = KeyMap[Replace[rules], dimensions];
	indices = Replace[tensorIndices, rules, {2}];
	normalIndices = Thread[# -> Range[Length[#]]] & [Union @@ indices];
	input = Replace[indices, normalIndices, {2}];
	output = Replace[freeIndices, normalIndices, {1}];
	dimensions = KeyMap[Replace[normalIndices], dimensions];
	If[TrueQ[OptionValue["ReturnParameters"]], Return[{input, output, dimensions}]];
	Replace[OptionValue[Method], {
        Automatic :> OptimalPath[input, output, dimensions, "size"],
        method_String :>  OptimalPath[input, output, dimensions, method],
        _ :> GreedyPath[input, output, dimensions]
    }]
]

TensorNetworkContractionPath[net_ ? TensorNetworkGraphQ, opts : OptionsPattern[]] :=
    TensorNetworkContractionPath[TensorNetworkGraphData[net], opts]


einsum[{i_, j_} -> k_, a_, b_] := Block[{c = Complement[Join[i, j], k], adim = Dimensions[a], bdim = Dimensions[b], al, br, ac, bc, ad, bd},
	ac = Catenate @ Lookup[PositionIndex[i], c];
	bc = Catenate @ Lookup[PositionIndex[j], c];
	al = Complement[Range[Length[i]], ac];
	br = Complement[Range[Length[j]], bc];
	ad = Times @@ adim[[ac]];
	bd = Times @@ bdim[[bc]];
	Transpose[
		ArrayReshape[
			ArrayReshape[Transpose[a, FindPermutation[Join[al, ac]]], {Times @@ adim / ad, ad}] . ArrayReshape[Transpose[b, FindPermutation[Join[bc, br]]], {bd, Times @@ bdim / bd}],
			Join[adim[[al]], bdim[[br]]]
		],
		FindPermutation[Join[i[[al]], j[[br]]], k]
	]
]


TensorNetworkContractPath[
	KeyValuePattern[{
		"Tensors" -> initTensors_,
		"ContractionIndices" -> initIndices_,
		"FreeIndices" -> freeIndices_
	}],
	path_
] := Enclose @ Block[{tensors = initTensors, indices = initIndices},
    Do[
		Replace[p, {
			{i_} :> (
				{tensors, indices} = Append[Delete[#, {i}], #[[i]]] & /@ {tensors, indices}
			),
			{i_, j_} :> Block[{out, tensor},
				out = SymmetricDifference @@ Extract[indices, {{i}, {j}}];
				tensor = ActivateTensor @ EinsteinSummation[indices[[{i, j}]] -> out, {tensors[[i]], tensors[[j]]}];
				(* tensor = einsum[indices[[{i, j}]] -> out, tensors[[i]], tensors[[j]]]; *)

				tensors = Append[Delete[tensors, {{i}, {j}}], tensor];
				indices = Append[Delete[indices, {{i}, {j}}], out]
			]
		}],
		{p, path}
	];
	ConfirmAssert[Length[tensors] == Length[indices] == 1];
	ConfirmAssert[ContainsAll[indices[[1]], freeIndices]];
	Transpose[tensors[[1]], FindPermutation[indices[[1]], freeIndices]]
]

TensorNetworkContractPath[net_ ? TensorNetworkGraphQ, path_] := TensorNetworkContractPath[TensorNetworkGraphData[net], path]


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

contractTensorPair[{\[FormalCapitalT][tensor1_, indices1_, flop1_], \[FormalCapitalT][tensor2_, indices2_, flop2_]}, opts : OptionsPattern[]] :=
	\[FormalCapitalT] @@ Append[0] @ Switch[
		OptionValue[Method],
			"ArrayDotTranspose", einsumArrayDotTranspose,
			"ArrayDot", einsumArrayDot,
			"Dot", einsumDot,
			"TensorContract", einsumTensorContract,
			"TableSum", einsumTableSum
		][{indices1, indices2} -> Automatic, tensor1, tensor2, TrueQ[OptionValue["Inactive"]]]


Options[TensorNetworkContraction] = Join[Options[contractTensorPair], {"TransposeFunction" -> Transpose}]

TensorNetworkContraction[net_Graph ? TensorNetworkGraphQ, path_, opts : OptionsPattern[]] :=
    TensorNetworkContraction[TensorNetworkGraphData[net], path, opts]

TensorNetworkContraction[netData : KeyValuePattern["Vertices" -> vertices_], path : {{_Integer, _Integer} ...}, opts : OptionsPattern[]] := 
    TensorNetworkContraction[netData, PathToTreePath[path, vertices], opts]

TensorNetworkContraction[
    KeyValuePattern[{
		"Vertices" -> vertices_,
		"Tensors" -> tensors_,
		"Contractions" -> contractions_,
        "FreeIndices" -> freeIndices_
	}],
    treePath_,
    opts : OptionsPattern[]
] := With[{
    contractOpts = FilterRules[{opts}, Options[contractTensorPair]]
}, {
    tensorPath = NestWhile[
        ReplaceAll[tensorPair : {_\[FormalCapitalT], _\[FormalCapitalT]} :> contractTensorPair[tensorPair, contractOpts]],
        Replace[treePath, MapThread[{#1} -> \[FormalCapitalT][#2, #3, 0] &, {vertices, tensors, contractions}], {-2}],
        Not @* MatchQ[_\[FormalCapitalT]]
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
