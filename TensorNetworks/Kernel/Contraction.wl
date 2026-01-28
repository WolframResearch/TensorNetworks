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


(* ============================================ *)
(* Symmetry-Filtered Contraction               *)
(* ============================================ *)

(* Symmetry-aware ArrayDot that skips zero blocks based on quantum number conservation *)
(* aCharges/bCharges: Association mapping index labels to charge lists *)
(* Example: <|"j" -> {-1, 0, 1}|> means index "j" has charges -1, 0, 1 for its 3 values *)

einsumArrayDotWithCharges[
    {i_, j_} -> out_,
    a_, b_,
    aCharges_Association,
    bCharges_Association,
    inactiveQ : _ ? BooleanQ : False
] := Block[{
    c, al, br, k,
    aIndex = First /@ PositionIndex[i],
    bIndex = First /@ PositionIndex[j],
    contractedChargesA, contractedChargesB,
    allowedPairs, nAllowed, nTotal,
    inactive = If[inactiveQ, Function[f, Inactive[f][##] &], Identity]
},
    (* Find contracted indices *)
    c = DeleteElements[
        DeleteDuplicates @ Join[i, j],
        Replace[out, Automatic :> SymmetricDifference[i, j]]
    ];
    al = DeleteElements[i, c];
    br = DeleteElements[j, c];
    k = Length[c];

    (* If no contraction, use standard tensor product *)
    If[k == 0,
        Return[einsumArrayDot[{i, j} -> out, a, b, inactiveQ]]
    ];

    (* Check if we have charge info for all contracted indices *)
    If[!AllTrue[c, KeyExistsQ[aCharges, #] && KeyExistsQ[bCharges, #] &],
        (* Missing charge info - fall back to standard contraction *)
        Return[einsumArrayDot[{i, j} -> out, a, b, inactiveQ]]
    ];

    (* Get charges for contracted indices *)
    contractedChargesA = Lookup[aCharges, c];
    contractedChargesB = Lookup[bCharges, c];

    (* Find allowed contractions (where charges sum to zero) *)
    allowedPairs = findAllowedChargedPairs[contractedChargesA, contractedChargesB];

    nTotal = Times @@ (Length /@ contractedChargesA);
    nAllowed = Length[allowedPairs];

    (* If most contractions are allowed (>50%), use standard method - overhead not worth it *)
    If[nAllowed > 0.5 * nTotal,
        Return[einsumArrayDot[{i, j} -> out, a, b, inactiveQ]]
    ];

    (* If no allowed contractions, return zero tensor *)
    If[nAllowed == 0,
        Return[zeroResultTensor[a, b, al, br, out, aIndex, bIndex]]
    ];

    (* Sparse contraction over allowed pairs only *)
    sparseChargedArrayDot[a, b, allowedPairs, {i, j} -> out, c, aIndex, bIndex, inactive]
]

(* Helper: Find index value pairs where charges sum to zero *)
findAllowedChargedPairs[chargesA_List, chargesB_List] := Module[{
    nIndices = Length[chargesA]
},
    If[nIndices == 0, Return[{{}}]];

    (* For single contracted index *)
    If[nIndices == 1,
        Return[
            Select[
                Tuples[{Range[Length[chargesA[[1]]]], Range[Length[chargesB[[1]]]]}],
                chargesA[[1, #[[1]]]] + chargesB[[1, #[[2]]]] == 0 &
            ]
        ]
    ];

    (* For multiple contracted indices - find pairs for each and take Cartesian product *)
    Module[{ranges},
        ranges = Table[
            Select[
                Tuples[{Range[Length[chargesA[[idx]]]], Range[Length[chargesB[[idx]]]]}],
                chargesA[[idx, #[[1]]]] + chargesB[[idx, #[[2]]]] == 0 &
            ],
            {idx, nIndices}
        ];
        (* If any index has no allowed pairs, result is empty *)
        If[AnyTrue[ranges, Length[#] == 0 &],
            {},
            Tuples[ranges]
        ]
    ]
]

(* Helper: Create zero tensor with correct output shape *)
zeroResultTensor[a_, b_, al_, br_, out_, aIndex_, bIndex_] :=
Module[{aDims, bDims, outDims},
    aDims = Dimensions[a];
    bDims = Dimensions[b];
    outDims = Join[
        aDims[[Lookup[aIndex, al]]],
        bDims[[Lookup[bIndex, br]]]
    ];
    If[out =!= Automatic,
        outDims = outDims[[PermutationList[FindPermutation[Join[al, br], out], Length[outDims]]]]
    ];
    If[Length[outDims] == 0,
        0.,
        ConstantArray[0., outDims]
    ]
]

(* Helper: Sparse contraction over allowed index pairs *)
sparseChargedArrayDot[a_, b_, allowedPairs_, {i_, j_} -> out_, contracted_, aIndex_, bIndex_, inactive_] :=
Module[{result, aDims, bDims, al, br, outShape},
    al = DeleteElements[i, contracted];
    br = DeleteElements[j, contracted];
    aDims = Dimensions[a];
    bDims = Dimensions[b];

    (* Compute output shape *)
    outShape = Join[
        aDims[[Lookup[aIndex, al]]],
        bDims[[Lookup[bIndex, br]]]
    ];

    (* Handle scalar output *)
    If[Length[outShape] == 0,
        Return[Total[
            extractAndMultiplyScalar[a, b, #, contracted, aIndex, bIndex] & /@ allowedPairs
        ]]
    ];

    (* Initialize result tensor *)
    result = ConstantArray[0., outShape];

    (* Sum over allowed pairs only *)
    Do[
        result += extractAndMultiply[a, b, pair, contracted, al, br, aIndex, bIndex],
        {pair, allowedPairs}
    ];

    (* Apply output permutation if needed *)
    If[out === Automatic,
        {result, Join[al, br]},
        Module[{perm = FindPermutation[Join[al, br], out]},
            If[perm === Cycles[{}], result, inactive[Transpose][result, perm]]
        ]
    ]
]

(* Helper: Extract tensor slices at given index values and compute outer product *)
extractAndMultiply[a_, b_, indexPairs_, contracted_, al_, br_, aIndex_, bIndex_] :=
Module[{aSlice, bSlice, aSpec, bSpec, aDims, bDims},
    aDims = Dimensions[a];
    bDims = Dimensions[b];

    (* Build Part specification for tensor a *)
    aSpec = ConstantArray[All, Length[aDims]];
    Do[
        aSpec[[Lookup[aIndex, contracted[[k]]]]] = indexPairs[[k, 1]],
        {k, Length[contracted]}
    ];
    aSlice = Extract[a, {aSpec}][[1]];

    (* Build Part specification for tensor b *)
    bSpec = ConstantArray[All, Length[bDims]];
    Do[
        bSpec[[Lookup[bIndex, contracted[[k]]]]] = indexPairs[[k, 2]],
        {k, Length[contracted]}
    ];
    bSlice = Extract[b, {bSpec}][[1]];

    (* Outer product of remaining indices *)
    If[Length[al] == 0 && Length[br] == 0,
        aSlice * bSlice,
        Outer[Times, aSlice, bSlice]
    ]
]

(* Helper: For scalar output case *)
extractAndMultiplyScalar[a_, b_, indexPairs_, contracted_, aIndex_, bIndex_] :=
Module[{aSpec, bSpec, aDims, bDims},
    aDims = Dimensions[a];
    bDims = Dimensions[b];

    aSpec = ConstantArray[All, Length[aDims]];
    Do[
        aSpec[[Lookup[aIndex, contracted[[k]]]]] = indexPairs[[k, 1]],
        {k, Length[contracted]}
    ];

    bSpec = ConstantArray[All, Length[bDims]];
    Do[
        bSpec[[Lookup[bIndex, contracted[[k]]]]] = indexPairs[[k, 2]],
        {k, Length[contracted]}
    ];

    Extract[a, {aSpec}][[1]] * Extract[b, {bSpec}][[1]]
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


$TensorNetworkContractionMethods = {"ArrayDotTranspose", "ArrayDot", "SymmetryFiltered", "Dot", "TensorContract", "TableSum"}

contractTensorPair::nocharges = "Method \"SymmetryFiltered\" requires \"Charges\" option with charge associations for each tensor. Falling back to ArrayDot.";

Options[contractTensorPair] = {Method -> "ArrayDot", "Inactive" -> True, "Charges" -> None}

contractTensorPair[{tensor1_ -> indices1_, tensor2_ -> indices2_}, OptionsPattern[]] :=
    With[{
        charges = OptionValue["Charges"],
        method = OptionValue[Method],
        inactiveQ = TrueQ[OptionValue["Inactive"]]
    },
        Switch[method,
            "SymmetryFiltered",
                If[charges =!= None && AssociationQ[charges[[1]]] && AssociationQ[charges[[2]]],
                    (* Use symmetry-filtered contraction with charge information *)
                    einsumArrayDotWithCharges[
                        {indices1, indices2} -> Automatic,
                        tensor1, tensor2,
                        charges[[1]], charges[[2]],
                        inactiveQ
                    ],
                    (* Missing or invalid charges - fall back to ArrayDot with warning *)
                    Message[contractTensorPair::nocharges];
                    einsumArrayDot[{indices1, indices2} -> Automatic, tensor1, tensor2, inactiveQ]
                ],
            "ArrayDotTranspose",
                einsumArrayDotTranspose[{indices1, indices2} -> Automatic, tensor1, tensor2, inactiveQ],
            "ArrayDot",
                einsumArrayDot[{indices1, indices2} -> Automatic, tensor1, tensor2, inactiveQ],
            "Dot",
                einsumDot[{indices1, indices2} -> Automatic, tensor1, tensor2, inactiveQ],
            "TensorContract",
                einsumTensorContract[{indices1, indices2} -> Automatic, tensor1, tensor2, inactiveQ],
            "TableSum",
                einsumTableSum[{indices1, indices2} -> Automatic, tensor1, tensor2, inactiveQ],
            _,
                (* Default to ArrayDot for unknown methods *)
                einsumArrayDot[{indices1, indices2} -> Automatic, tensor1, tensor2, inactiveQ]
        ]
    ]


Options[TensorNetworkContraction] = Join[Options[contractTensorPair], {"TransposeFunction" -> Transpose, "IndexCharges" -> <||>}]

(* Helper: Extract charges for a tensor's indices from global IndexCharges map *)
extractTensorCharges[indices_List, indexCharges_Association] :=
    Association @ Map[
        If[KeyExistsQ[indexCharges, #], # -> indexCharges[#], Nothing] &,
        indices
    ]

(* Helper: Build Charges option for contractTensorPair from IndexCharges *)
buildChargesOption[indices1_List, indices2_List, indexCharges_Association] :=
    If[indexCharges === <||>,
        None,
        {extractTensorCharges[indices1, indexCharges], extractTensorCharges[indices2, indexCharges]}
    ]

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
    baseOpts = FilterRules[{opts}, Except["IndexCharges", Options[contractTensorPair]]],
    indexCharges = OptionValue["IndexCharges"]
}, {
    tensorPath = FixedPoint[
        ReplaceAll[{"Pair"[t1_, i1_], "Pair"[t2_, i2_]} :>
            "Pair" @@ contractTensorPair[
                {t1 -> i1, t2 -> i2},
                Sequence @@ baseOpts,
                "Charges" -> buildChargesOption[i1, i2, indexCharges]
            ]
        ],
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

(* Auto-detect IndexCharges from TensorNetwork metadata when using SymmetryFiltered *)
TensorNetworkContract[net_TensorNetwork ? TensorNetworkQ, path : Automatic | _String | _ ? CanonicalPathQ : Automatic, opts : OptionsPattern[]] :=
    Block[{method, hasExplicitCharges, indexCharges},
        method = OptionValue[{opts, Options[TensorNetworkContract]}, Method];
        hasExplicitCharges = MemberQ[{opts}, "IndexCharges" -> _];

        (* If using SymmetryFiltered without explicit IndexCharges, try to get from TensorNetwork *)
        If[method === "SymmetryFiltered" && !hasExplicitCharges,
            indexCharges = net["IndexCharges"];
            If[indexCharges =!= None,
                Return[TensorNetworkContract[
                    TensorNetworkData[BinaryTensorNetwork[net]],
                    path,
                    Method -> "SymmetryFiltered",
                    "IndexCharges" -> indexCharges,
                    opts
                ]]
            ]
        ];

        (* Default: convert to data and call main implementation *)
        TensorNetworkContract[TensorNetworkData[BinaryTensorNetwork[net]], path, opts]
    ]

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
