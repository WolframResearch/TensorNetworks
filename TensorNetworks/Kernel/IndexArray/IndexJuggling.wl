Package["Wolfram`TensorNetworks`IndexArray`"]

PackageImport["Wolfram`TensorNetworks`"]

PackageExport[IndexPart]
PackageExport[IndexContract]
PackageExport[IndexJuggling]



IndexPart[it : _IndexArray | _IndexTensor, {is__}] := Block[{
    indices = it["Indices"], js, newArray
},
    js = MapThread[If[MatchQ[#2, _Integer | All], #2, Lookup[#1, Key[#2]]] &, {Map[First] @* PositionIndex /@ Through[Take[indices, UpTo[Length[{is}]]]["Indices"]], {is}}];
    (
        newArray = IndexArray[
            ArrayPart[it["Array"], Replace[js, _Missing -> All, 1]],
            MapThread[
                If[ IntegerQ[#2],
                    Dimension[#1, Mod[#2, #1["Dimension"], 1]],
                    Replace[#2, {
                        Missing[_, - name_] :> Dimension[#1, name]["Lower"],
                        Missing[_, name_] :> Dimension[#1, name]["Upper"]
                    }]
                ] &, 
                {indices, ReplacePart[indices, Thread[Take[Select[indices, (#["FreeQ"] &) -> "Index"], UpTo[Length[js]]] -> js]]}
            ],
            it["Parameters"], it["Assumptions"], it["Name"]
        ];
        If[IndexArrayQ[it], newArray, IndexTensor[newArray, it["Metrics"]]]
     ) /; AnyTrue[js, IntegerQ]
]

IndexPart[it_IndexTensor, {}] := it

IndexPart[it_IndexTensor, rules : {(_Integer -> _) ..}] := With[{r = it["Rank"]}, it[[##]] & @@ ReplacePart[ConstantArray[All, r], Cases[rules, (k_ -> _) /; 0 < k <= r]]]


IndexContract[arrays : {__ ? IndexArrayQ}, output : _List | Automatic : Automatic, prop_String : "Tensor"] := Enclose @ Block[{
	arrayIndices, indexPositions, contractions, newShape, metrics, contractedIndexPositions, einsum, newArray
},
	arrayIndices = MapThread[
		If[#1["FreeQ"], {#1, #2, #2[[3]]}, Nothing] &,
		{Catenate @ Through[arrays["FreeIndices"]], Catenate @ MapIndexed[Append[#2, #1] &, Through[arrays["FreeIndexPositions"]], {2}]}
	];
    contractions = Values[Select[GroupBy[arrayIndices, #[[1]]["Name"] &], Length[#] > 1 &]];
    contractions = #[[If[#[[1, 1]]["Dimension"] == 0, 2 ;;, All], ;; 2]] -> #[[1, 3]] & /@ contractions;
    indexPositions = Catenate @ MapIndexed[#2 &, Through[arrays["Indices"]], {2}];
    contractedIndexPositions = Lookup[PositionIndex[indexPositions], Catenate[contractions[[All, 1, All, 2, {1, 3}]]]];
    newShape = Delete[Catenate[Through[arrays["Indices"]]], contractedIndexPositions];
    metrics = Delete[arrayIndices[[All, 3]], contractedIndexPositions];
    If[ output =!= Automatic,
        newShape = Catenate[Through[arrays["Indices"]]];
        metrics = arrayIndices[[All, 3]];
        With[{outPositions = Take[DeleteDuplicates @ Catenate @ Lookup[PositionIndex[Through[newShape["Name"]]], output, Nothing], UpTo[Length[output]]]},
            newShape = newShape[[outPositions]];
            metrics = metrics[[outPositions]];
            contractions = Select[contractions, NoneTrue[DeleteDuplicates[#[[1, All, 2, 1]]], MemberQ[outPositions, #] &] &]
        ]
    ];

    If[prop === "Shape", Return[newShape]];
    einsum = Map[#["Name"] &, Through[arrays["FreeIndices"]], {2}] -> output;
    newArray = IndexArray[
        EinsteinSummation[einsum, Through[arrays["Array"]]],
        newShape,
        DeleteDuplicates[Catenate[Through[arrays["Parameters"]]]],
        DeleteDuplicates[Catenate[Through[arrays["Assumptions"]]]],
        If[Length[arrays] == 1, arrays[[1]]["Name"], None]
    ];
    newArray
]

IndexContract[tensors : {__ ? IndexTensorQ}, output : _List | Automatic : Automatic, prop_String : "Tensor"] := Enclose @ Block[{
	arrays, metrics, metricIndices, tensorIndices, indexPositions, contractions,
    newShape, contractedIndexPositions, reindexMetrics, reindex, reindexedArrays, einsum,
    newArray
},
	arrays = Through[tensors["IndexArray"]];
	metrics = Through[tensors["MetricRules"]];
	metricIndices = Through[metrics["FreeIndices"]];
	tensorIndices = MapThread[
		If[#1["FreeQ"], {#1, #2, Replace[#2[[3]], Append[Catenate[Thread /@ metrics[[#2[[1]]]]], _ -> None]]}, Nothing] &,
		{Catenate @ Through[tensors["FreeIndices"]], Catenate @ MapIndexed[Append[#2, #1] &, Through[tensors["FreeIndexPositions"]], {2}]}
	];
    contractions = Values[Take[#, 2] & /@ Select[GroupBy[Cases[tensorIndices, {_, _, Except[None]}], ({#[[1]]["Name"], Simplify @ Normal[#[[3]]]} &)], Length[#] > 1 &]];
    contractions = #[[If[#[[1, 1]]["Dimension"] == 0, 2 ;;, All], ;; 2]] -> If[Equal @@ Through[#[[All, 1]]["Sign"]], #[[1, 3]], None] & /@ contractions;
    indexPositions = Catenate @ MapIndexed[#2 &, Through[tensors["Indices"]], {2}];
    contractedIndexPositions = Lookup[PositionIndex[indexPositions], Catenate[contractions[[All, 1, All, 2, {1, 3}]]]];
    newShape = Delete[Catenate[Through[tensors["Indices"]]], contractedIndexPositions];
    metrics = Delete[tensorIndices[[All, 3]], contractedIndexPositions];
    If[ output =!= Automatic,
        newShape = Catenate[Through[tensors["Indices"]]];
        metrics = tensorIndices[[All, 3]];
        With[{outPositions = Take[DeleteDuplicates @ Catenate @ Lookup[PositionIndex[Through[newShape["Name"]]], output, Nothing], UpTo[Length[output]]]},
            newShape = newShape[[outPositions]];
            metrics = metrics[[outPositions]];
            contractions = Select[contractions, NoneTrue[DeleteDuplicates[#[[1, All, 2, 1]]], MemberQ[outPositions, #] &] &]
        ]
    ];

    If[prop === "Shape", Return[newShape]];
	reindexMetrics = Map[
		With[{signs = Through[#[[1, All, 1]]["Sign"]]},
            If[ Equal @@ signs,
                With[{covQ = signs[[1]] === -1, name = FreshVariable["i"], pos = #[[1, 1, 2]], metric = #[[2]]}, {names = {#[[1, 1, 1]]["Name"], name}},
                    (pos[[1]] -> pos[[2]] -> If[covQ, 1, -1] * name) -> If[covQ, Inverse[metric] @@ names, metric @@ (- names)]
                ],
                Nothing
            ]
        ] &, 
		Cases[contractions, HoldPattern[_ -> _IndexArray]]
	];
	reindex = reindexMetrics[[All, 1]];
	reindexedArrays = Join[
	    MapIndexed[
            #1 @@ Lookup[reindex, #2, Nothing] &,
			arrays
		],
		reindexMetrics[[All, 2]]
	];
    If[prop === "Arrays", Return[reindexedArrays]];
    einsum = Map[#["Name"] &, Through[reindexedArrays["FreeIndices"]], {2}] -> output;
    newArray = IndexArray[
        EinsteinSummation[einsum, Through[reindexedArrays["Array"]]],
        newShape,
        DeleteDuplicates[Catenate[Through[tensors["Parameters"]]]],
        DeleteDuplicates[Catenate[Through[tensors["Assumptions"]]]],
        If[Length[tensors] == 1, tensors[[1]]["Name"], None]
        (* Replace[CircleTimes @@ Through[tensors["Symbol"]], CircleTimes[x_] :> x] *)
    ];
    If[prop === "Array", Return[newArray]];
    
    IndexTensor[
        newArray,
        #[[All, 1]] -> #[[1, 2]] & /@ Values @ GroupBy[Thread[newArray["FreeIndexPositions"] -> metrics], (Normal[#[[2]]] &)]
    ]
]

IndexContract[array_ ? IndexArrayQ, args___] := IndexContract[{array}, args]

IndexContract[arrays_List, metric_ ? IndexTensorQ, args___] := IndexContract[arrays, metric["IndexArray"], args]

IndexContract[arrays_List, metric_ ? IndexArrayQ, args___] := IndexContract[IndexTensor[#, metric] & /@ arrays, args]

IndexContract[tensor_ ? IndexTensorQ, args___] := IndexContract[{tensor}, args]



renameShape[shape_, renames_] := SubsetMap[
    MapThread[
        {i, name} |-> If[MatchQ[name, - _], Dimension[i, - name]["Lower"], Dimension[i, name]["Upper"]],
        {#, renames[[All, 2]]}
    ] &,
    shape,
    renames[[All, 1]]
]


IndexJuggling[it_, {}] := it

IndexJuggling[it_, shape_Shape ? ShapeQ] := IndexJuggling[it, Through[shape["Indices"]["SignedName"]]]

IndexJuggling[it : _ ? IndexTensorQ | _ ? IndexArrayQ, newIndices_List] := Enclose @ Block[{
    indices = it["Indices"], indexPositions = it["FreeIndexPositions"],
    l, n, m,
    names, newNames, rules, perm, renames, newShape, renamedShape, newArray, newTensor, vars
},
    l = Length[indices];
    newNames = SignedSymbolName /@ Replace[newIndices, {d_Dimension :> d["SignedName"], i_Integer /; 0 < Abs[i] <= l :> Sign[i] * indices[[i]]["Name"], _Rule -> Nothing}, 1];
    n = Length[newNames];
    m = Min[l, n];
    names = First /@ PositionIndex[Through[indices["Name"]]];
    rules = MapThread[
        With[{i = Lookup[names, Key[CanonicalSymbolName[#1]]]},
            i -> {#2, #3, MissingQ[i] || MatchQ[#1, - _] != indices[[i]]["LowerQ"]}
        ] &,
        {Take[newNames, UpTo[m]], Take[indexPositions, UpTo[m]], Range[m]}
    ];
    rules = Catenate @ Values @ GroupBy[rules, First, Prepend[First[#]] @ Map[Missing[] -> #[[2]] &, Rest[#]] &];
    perm = FindPermutation[Join[#, DeleteElements[indexPositions, #]]] & @
        Map[If[MissingQ[#[[1]]], Replace[Replace[#[[2, 1]], rules], {x_, __} :> Replace[Replace[x, rules], {y_, __} :> y]], #[[1]]] &, rules];
    renames = Join[Cases[rules, (_ -> {k_, l_, True}) :> k -> newNames[[l]]], Cases[newIndices, HoldPattern[i_Integer -> _] /; MemberQ[indexPositions, i]]];
    newShape = Permute[indices, perm];
    rules = Thread[indexPositions -> Permute[indexPositions, InversePermutation[perm]]];
    newArray = IndexArray[
        ArrayTranspose[it["Array"], perm],
        newShape,
        it["Parameters"], it["Assumptions"], it["Name"]
    ];
    renamedShape = renameShape[newShape, renames];
    If[IndexArrayQ[it], Return[IndexArray[newArray, renamedShape]]];

    newTensor = ConfirmBy[IndexTensor[newArray, MapAt[Replace[#, rules, 1] &, it["MetricRules"], {All, 1}]], IndexTensorQ];
    rules = Append[_ -> None] @ Catenate[Thread /@ newTensor["Metrics"]];
    vars = MapThread[With[{metric = Replace[#3, rules]},
            If[ ! #1["FreeQ"] || #1["Sign"] == #2["Sign"] || metric === None,
                #2,
                {#3, {FreshVariable["i"], #2["Name"]}, #1["Sign"]}
            ]
        ] &,
        {newShape, renamedShape, Range[l]}
    ];
    newTensor = ConfirmBy[
        IndexContract[
            {
                IndexTensor[newArray @@ MapIndexed[Replace[#1, {{_, {v_, _}, s_} :> s * v, d_Dimension :> d["Sign"] * d["Name"][#2[[1]]]}] &, vars], newTensor["Metrics"]],
                Splice[
                    MapIndexed[
                        Replace[#1, {
                            {m_, {v_, w_}, sign_} :> With[{metric = Replace[m, rules], i = #2[[1]]},
                                If[ metric === None,
                                    Nothing,
                                    With[{curSign = Sign[metric["SignedDimensions"][[1]]]},
                                        IndexTensor[If[sign == curSign, Inverse[metric] @@ (- sign * {w[i], v}), metric @@ (curSign * {w[i], v})], metric]
                                    ]
                                ]
                            ],
                            _ -> Nothing
                        }
                        ] &,
                        vars
                    ]
                ]
            },
            Join[MapIndexed[Replace[#1, {{_, {_, v_}, _} :> v[#2[[1]]], d_Dimension :> d["Name"][#2[[1]]]}] &, vars], Drop[newNames, UpTo[m]]]
        ],
        IndexTensorQ
    ];
    newShape = Replace[Through[newTensor["Indices"]["SignedName"]], {- x_[_] :> - x, x_[_] :> x}, 1];
    newTensor = IndexTensor[newTensor["IndexArray"] @@ newShape, newTensor["Metrics"]];
    If[ n < l && Take[newShape, UpTo[n]] =!= Take[newNames, UpTo[n]],
        newTensor = newTensor @@ Join[newNames, Drop[newShape, UpTo[n]]]
    ];

    If[ n > l && Drop[newShape, UpTo[m]] =!= Drop[newNames, UpTo[m]],
        newTensor = newTensor @@ newNames
    ];

    If[ it["MetricQ"] && metricQ[newTensor["IndexArray"]],
        newTensor = IndexTensor[newTensor["IndexArray"]]
    ];

    IndexTensor[newTensor, it["Name"]]
]

