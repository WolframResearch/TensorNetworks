Package["Wolfram`TensorNetworks`"]

PackageExport[TensorNetwork]
PackageExport[TensorNetworkQ]
PackageExport[TensorNetworkData]



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

TensorNetworkProp[tn_, "Ranks"] := tensorRank /@ tn["Tensors"]

TensorNetworkProp[tn_, "Graph", opts___] := GraphTensorNetwork[tn["Tensors"], tn["Hyperedges"], opts]

TensorNetworkProp[tn_, "GraphData"] := TensorNetworkProp[tn, "GraphData"] = TensorNetworkGraphData[tn["Graph"]]

TensorNetworkProp[tn_, "Data"] := TensorNetworkProp[tn, "Data"] = TensorNetworkData[tn]

TensorNetworkData[tn_TensorNetwork ? TensorNetworkQ] := With[{
    tensors = tn["Tensors"],
    hyperedges = tn["Hyperedges"]
}, {
    indices = MapIndexed[Thread[First[#2] -> #1] &, hyperedges],
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
        "Bonds" -> Thread[Values[indexGroups] -> Lookup[indexDimensions, Values[indexGroups][[All, 1]]]],
        "Contractions" -> Replace[hyperedges, indexGroups, {2}],
        "ContractionIndices" -> Replace[hyperedges, First /@ indexGroups, {2}]
    |>
]

TensorNetworkProp[tn_, prop_String] /;
    MemberQ[{"Indices", "Vertices", "FreeIndices", "Bonds", "Contractions", "ContractionIndices"}, prop] :=
        Lookup[tn["Data"], prop]

TensorNetworkProp[tn_, "Properties"] := {
    "Tensors", "Hyperedges",
    "Dimensions", "Ranks",
    "Indices", "Vertices", "FreeIndices", "Bonds", "Contractions", "ContractionIndices",
    "Graph", "GraphData", "Data"
}

(* Fallback for unknown properties *)
TensorNetworkProp[_, prop_] := Missing["UnknownProperty", prop]



TensorNetworkGraphData[tn_TensorNetwork ? TensorNetworkQ] := TensorNetworkGraphData[tn["Graph"]]
TensorNetworkTensors[tn_TensorNetwork ? TensorNetworkQ] := tn["Tensors"]
TensorNetworkIndices[tn_TensorNetwork ? TensorNetworkQ] := tn["ContractionIndices"]
TensorNetworkFreeIndices[tn_TensorNetwork ? TensorNetworkQ] := tn["FreeIndices"]

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
            BoxForm`SummaryItem[{"Tensors: ", nTensors}],
            BoxForm`SummaryItem[{"Free indices: ", Length[freeIndices]}]
        },
        (* Expanded *)
        {
            BoxForm`SummaryItem[{"Dimensions: ", dims}]
        },
        fmt
    ]
]
