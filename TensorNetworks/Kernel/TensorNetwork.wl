Package["Wolfram`TensorNetworks`"]

PackageExport[TensorNetwork]
PackageExport[TensorNetworkQ]
PackageExport[TensorNetworkData]
PackageExport[TensorNetworkSize]
PackageExport[TensorNetworkContractions]

PackageExport[BinaryTensorNetworkQ]
PackageExport[BinaryTensorNetwork]

PackageExport[SparseTensorNetwork]

PackageExport[RandomTensorNetwork]



(* Internal validation function *)
tensorNetworkQ[TensorNetwork[tensors_List, hyperedges : {___List}]] := 
    Length[tensors] == Length[hyperedges] && 
    With[{dimensions = tensorDimensions /@ tensors},
        AllTrue[Thread[{dimensions, hyperedges}], Apply[Length[#1] == Length[#2] &]] &&
        With[{allDimensions = Catenate[dimensions]},
            AllTrue[PositionIndex[Catenate[hyperedges]], Equal @@ allDimensions[[#]] &]
        ]
    ]

tensorNetworkQ[___] := False

(* Public predicate - uses System`Private`HoldValidQ for caching *)
TensorNetworkQ[tn_TensorNetwork] := 
    System`Private`HoldValidQ[tn] || tensorNetworkQ[Unevaluated @ tn]

TensorNetworkQ[___] := False

(* Auto-validation on first evaluation - sets Valid and NoEntry flags *)
tn_TensorNetwork /; System`Private`HoldNotValidQ[tn] && tensorNetworkQ[Unevaluated @ tn] := (
    System`Private`HoldSetValid[tn];
    System`Private`HoldSetNoEntry[tn];
    tn
)

TensorNetwork[
    IgnoringInactive @ HoldPattern @ TensorContract[
        TensorProduct[tensors__],
        edges : {{_Integer, _Integer} ...}
    ]
] := With[{
    ranks = tensorRank /@ {tensors}
}, {
    indices = Range[Total[ranks]]
},
    TensorNetwork[
        {tensors},
        TakeList[
            ReplacePart[indices, Thread[edges[[All, 1]] -> indices[[edges[[All, 2]]]]]],
            ranks
        ]
    ]
]

TensorNetwork[net_ ? TensorNetworkGraphQ] :=
    TensorNetwork @@ Lookup[TensorNetworkGraphData[net], {"Tensors", "ContractionIndices"}]

TensorNetwork[hypergraph : {___List}] := TensorNetwork[
    ArraySymbol[\[FormalCapitalT], ConstantArray[\[FormalD], Length[#]]] & /@ hypergraph,
    hypergraph
]

(* Property dispatch - only called when TensorNetworkQ is True *)
(tn_TensorNetwork ? TensorNetworkQ)[prop_, args___] := TensorNetworkProp[tn, prop, args]

(* Property handlers *)
TensorNetworkProp[TensorNetwork[tensors_, _], "Tensors"] := tensors
TensorNetworkProp[TensorNetwork[_, hyperedges_], "Hyperedges"] := hyperedges

TensorNetworkProp[tn_, "Dimensions"] := tensorDimensions /@ tn["Tensors"]

TensorNetworkSize[tn_ ? TensorNetworkQ] := Length[tn["Hyperedges"]]

TensorNetworkProp[tn_, "Size"] := TensorNetworkSize[tn]

TensorNetworkProp[tn_, "Indices"] := MapIndexed[Thread[Superscript[First[#2], #1]] &, tn["Hyperedges"]]

TensorNetworkProp[tn_, "IndexDimensions"] := TensorNetworkIndexDimensions[tn]

TensorNetworkProp[tn_, "Ranks"] := tensorRank /@ tn["Tensors"]

ToTensorNetworkGraph[tn_ ? TensorNetworkQ, opts___] := ToTensorNetworkGraph[tn["Tensors"], tn["Hyperedges"], opts]

TensorNetworkProp[tn_, "Graph", opts___] := ToTensorNetworkGraph[tn, opts]

TensorNetworkProp[tn_, "GraphData"] := TensorNetworkProp[tn, "GraphData"] = TensorNetworkGraphData[tn["Graph"]]

TensorNetworkProp[tn_, "Data"] := TensorNetworkProp[tn, "Data"] = TensorNetworkData[tn]

TensorNetworkContractions[tn_ ? TensorNetworkQ]  := With[{
    hyperedges = tn["Hyperedges"]
},
    Replace[
        hyperedges,
        Replace[GroupBy[Catenate[MapIndexed[Thread[Superscript[First[#2], #1]] &, hyperedges]], Last], {x_} :> x, 1],
        {2}
    ]
]

TensorNetworkProp[tn_, "Contractions"] := TensorNetworkContractions[tn]

TensorNetworkData[tn_TensorNetwork ? TensorNetworkQ] := With[{
    tensors = tn["Tensors"],
    hyperedges = tn["Hyperedges"]
}, {
    indices = MapIndexed[Thread[Superscript[First[#2], #1]] &, hyperedges],
    dimensions = tensorDimensions /@ tensors
}, {
    indexDimensions = Association @ Catenate @ MapThread[Thread[#1 -> #2] &, {indices, dimensions}],
    indexGroups = GroupBy[Catenate[indices], Last]
},
    <|
        "Tensors" -> tensors,
        "Dimensions" -> dimensions,
        "Indices" -> indices,
        "Vertices" -> Range[Length[tensors]],
        "FreeIndices" -> Catenate @ Values @ Select[indexGroups, Length[#] == 1 &],
        "Bonds" -> With[{bondGroups = Select[indexGroups, Length[#] > 1 &]},
            Thread[Values[bondGroups] -> Lookup[indexDimensions, Values[bondGroups][[All, 1]]]]
        ],
        "Contractions" -> Replace[hyperedges, Replace[indexGroups, {x_} :> x, 1], {2}],
        "ContractionIndices" -> Replace[hyperedges, First /@ indexGroups, {2}]
    |>
]

TensorNetworkProp[tn_, prop_String] /;
    MemberQ[{"Indices", "Vertices", "FreeIndices", "Bonds", "Contractions", "ContractionIndices"}, prop] :=
        Lookup[tn["Data"], prop]

TensorNetworkProp[tn_, "OutputDimension"] := Times @@ Lookup[TensorNetworkIndexDimensions[tn], tn["FreeIndices"]]

TensorNetworkProp[tn_, "Hypergraph", opts___] :=
    PacletSymbol["WolframInstitute/Hypergraph", "Hypergraph"][
        tn["Hyperedges"],
        opts,
        VertexLabels -> Automatic, EdgeLabels -> Thread[tn["Hyperedges"] -> Range[Length[tn["Hyperedges"]]]]
    ]

TensorNetworkProp[tn_, "BinaryQ"] := BinaryTensorNetworkQ[tn]
TensorNetworkProp[tn_, "SparseQ"] := AllTrue[tn["Tensors"], SparseArrayQ]

BinaryTensorNetworkQ[tn_TensorNetwork ? TensorNetworkQ] := AllTrue[Counts[Catenate @ tn["Hyperedges"]], # <= 2 &]

BinaryTensorNetwork[tn_TensorNetwork ? TensorNetworkQ] := Block[{hyperedges = tn["Hyperedges"], indexHyperedges, dimensions, spidersIndices},
    indexHyperedges = Select[
        GroupBy[
            Catenate @ MapIndexed[List, hyperedges, {2}],
            First -> Last
        ],
        Length[#] > 2 &
    ];

    If[Length[indexHyperedges] == 0, Return[tn]];

    dimensions = TensorNetworkIndexDimensions[<|"Indices" -> hyperedges, "Dimensions" -> tn["Dimensions"]|>];

    spidersIndices = KeyValueMap[
        Thread[#2 -> Thread[Range[Length[#2]] -> #1, List, 1]] &,
        indexHyperedges
    ];

    TensorNetwork[
        Join[
            tn["Tensors"],
            KeyValueMap[
                With[{rank = Length[#2]},
                    SymbolicDeltaProductArray[ConstantArray[Lookup[dimensions, Key[#1]], rank], {Range[rank]}]
                ] &,
                indexHyperedges
            ]
        ],
        Join[
            ReplacePart[
                hyperedges,
                Catenate @ spidersIndices
            ],
            Values /@ spidersIndices
        ]
    ]
    
]
    

TensorNetworkProp[_, "Properties"] := {
    "Tensors", "Hyperedges",
    "Hypergraph",
    "Dimensions", "Ranks",
    "Indices", "IndexDimensions",
    "Vertices", "FreeIndices", "Bonds", "Contractions", "ContractionIndices",
    "BinaryQ",
    "SparseQ",
    "Graph", "GraphData", "Data"
}

(* Fallback for unknown properties *)
TensorNetworkProp[_, prop_] := Missing["UnknownProperty", prop]



TensorNetworkGraphData[tn_TensorNetwork ? TensorNetworkQ] := TensorNetworkGraphData[tn["Graph"]]
TensorNetworkTensors[tn_TensorNetwork ? TensorNetworkQ] := tn["Tensors"]
TensorNetworkIndices[tn_TensorNetwork ? TensorNetworkQ] := tn["ContractionIndices"]
TensorNetworkFreeIndices[tn_TensorNetwork ? TensorNetworkQ] := tn["FreeIndices"]
TensorNetworkIndexDimensions[tn_TensorNetwork ? TensorNetworkQ] :=
    TensorNetworkIndexDimensions[<|"Indices" -> tn["Indices"], "Dimensions" -> tn["Dimensions"]|>]

SparseTensorNetwork[tn_TensorNetwork ? TensorNetworkQ] :=
    TensorNetwork[SparseArray /@ tn["Tensors"], tn["Hyperedges"]]

Options[RandomTensorNetwork] = {Method -> "Complex"}

RandomTensorNetwork[{n_Integer, m_Integer}, maxDimension_Integer : 2, maxRank_Integer : 5, OptionsPattern[]] := Enclose @ Block[{
    g, ranks, tensors, indices, curIndices, rules, dimensions
},
	g = ConfirmBy[RandomGraph[{n, m}], GraphQ];
    ranks = Table[
        RandomInteger[{minRank, Max[minRank, maxRank]}],
        {minRank, VertexDegree[g]}
    ];
	
	indices = curIndices = TakeList[Range[Total[ranks]], ranks];
	rules = Map[
        With[
            {i = RandomInteger[{1, Length[curIndices[[#]]]}]},
            {ret = curIndices[[#, i]]},
            curIndices[[#, i]] = Nothing;
            ret
        ] &,
        Rule @@@ EdgeList[g],
        {2}
    ];
    indices = Replace[indices, rules, {2}];
    dimensions = ReplacePart[indices,
        Append[{_, _} :> RandomInteger[{2, maxDimension}]] @ Catenate @ Values @ GroupBy[
            Catenate @ MapIndexed[Rule, indices, {2}],
            First -> Last,
            Thread[# -> RandomInteger[{2, maxDimension}], List, 1] &
        ]
    ];
    tensors = Switch[OptionValue[Method], "Complex", RandomComplex[{-1 - I, 1 + I}, #], _, RandomReal[{-1, 1}, #]] & /@ dimensions;
    
	TensorNetwork[tensors, indices]
]


(* Summary Box - NoEntry is handled by System`Private`HoldSetNoEntry *)
TensorNetwork /: MakeBoxes[tn_TensorNetwork /; TensorNetworkQ[tn], fmt_] := With[{
    nTensors = Length[tn["Tensors"]],
    freeIndices = tn["FreeIndices"],
    dims = tn["Dimensions"]
},
    BoxForm`ArrangeSummaryBox[
        TensorNetwork,
        tn,
        (* Icon *)
        If[ nTensors > 10,
            RandomGraph[{8, 10}, EdgeStyle -> LightGray, ImageSize -> 32, AspectRatio -> 1],
            PacletSymbol["WolframInstitute/Hypergraph", "SimpleHypergraphPlot"][
                tn["Hyperedges"],
                ImageSize -> 32, AspectRatio -> 1
            ]
        ],
        (* Always shown *)
        {
            {BoxForm`SummaryItem[{"Tensors: ", nTensors}], BoxForm`SummaryItem[{"Binary: ", If[tn["BinaryQ"], "Yes", "No"]}]},
            {BoxForm`SummaryItem[{"Free indices: ", Length[freeIndices]}], BoxForm`SummaryItem[{"Sparse: ", If[tn["SparseQ"], "Yes", "No"]}]},
            {BoxForm`SummaryItem[{"Output dimension: ", tn["OutputDimension"]}]}
        },
        (* Expanded *)
        {
            BoxForm`SummaryItem[{"Dimensions: ", Pane[dims, 256]}]
        },
        fmt
    ]
]
