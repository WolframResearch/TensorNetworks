(* ::Package:: *)

Package["Wolfram`TensorNetworks`"]

PackageExport[TensorNetwork]
PackageExport[TensorNetworkQ]
PackageExport[TensorNetworkData]
PackageScope[tensorNetworkData]
PackageExport[TensorNetworkSize]
PackageExport[TensorNetworkContractions]

PackageExport[BinaryTensorNetworkQ]
PackageExport[BinaryTensorNetwork]

PackageExport[SparseTensorNetwork]

PackageExport[RandomTensorNetwork]
PackageExport[TensorNetworkAdd]
PackageExport[TensorNetworkDelete]

(* Register autocomplete for RandomTensorNetwork named types *)
If[$FrontEnd =!= Null,
    FE`Evaluate[FEPrivate`AddSpecialArgCompletion[
        "RandomTensorNetwork" -> {
            {"MPS", "TT", "MPO", "PEPS", "TTN", "MERA"}
        }
    ]]
]



(* Internal validation function *)
tensorNetworkQ[TensorNetwork[tensors_List, hyperedges : {___List}, output : _List | Automatic]] := 
    Length[tensors] == Length[hyperedges] && 
    With[{dimensions = tensorDimensions /@ tensors},
        AllTrue[Thread[{dimensions, hyperedges}], Apply[Length[#1] == Length[#2] &]] &&
        With[{allDimensions = Catenate[dimensions]},
            AllTrue[PositionIndex[Catenate[hyperedges]], Equal @@ allDimensions[[#]] &]
        ]
    ] &&
    (output === Automatic || ContainsAll[Catenate[hyperedges], output])

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

(* Specific failure messages, mirroring EinsteinSummation::length/shape/dim/output. *)
TensorNetwork::length = "Number of hyperedges (`1`) does not match the number of tensors (`2`).";
TensorNetwork::shape = "Hyperedge `1` does not match the tensor dimensions `2`.";
TensorNetwork::dim = "Dimensions of contracted index `1` don't match: `2`.";
TensorNetwork::output = "The uncontracted indices can't compose the desired output `1`.";

tensorNetworkCheck[tensors_List, hyperedges_List, output_] := Enclose[
    Module[{dimensions, allDimensions, posMap},
        If[Length[tensors] != Length[hyperedges],
            Message[TensorNetwork::length, Length[hyperedges], Length[tensors]];
            Confirm[$Failed]
        ];
        dimensions = tensorDimensions /@ tensors;
        MapThread[
            If[Length[#1] != Length[#2],
                Message[TensorNetwork::shape, #1, #2];
                Confirm[$Failed]
            ] &,
            {hyperedges, dimensions}
        ];
        allDimensions = Catenate[dimensions];
        posMap = PositionIndex[Catenate[hyperedges]];
        KeyValueMap[
            Function[{idx, pos},
                If[! TrueQ[Equal @@ allDimensions[[pos]]],
                    Message[TensorNetwork::dim, idx, allDimensions[[pos]]];
                    Confirm[$Failed]
                ]
            ],
            posMap
        ];
        If[output =!= Automatic && ! ContainsAll[Catenate[hyperedges], output],
            Message[TensorNetwork::output, output];
            Confirm[$Failed]
        ];
        Null
    ],
    $Failed &
]

(* Loud-fail constructor rule for invalid input. Fires only when tensorNetworkQ rejects AND every
   tensor has a known, non-empty dimension list -- preserves the historical silent behavior for
   symbolic tensors (where tensorDimensions returns {} from unevaluated TensorDimensions). *)
tn : TensorNetwork[tensors_List, hyperedges : {___List}, output : _List | Automatic] /;
    AllTrue[tensorDimensions /@ tensors, ListQ[#] && Length[#] > 0 &] &&
        ! tensorNetworkQ[Unevaluated @ tn] :=
    tensorNetworkCheck[tensors, hyperedges, output]

(* Normalize 3-arg *)
TensorNetwork[tensors_List, hyperedges : {___List}] := TensorNetwork[tensors, hyperedges, Automatic]

TensorNetwork[arrays_List, in_List -> out_List] := TensorNetwork[arrays, in, out]

TensorNetwork[arrays_List, in_List, perm_Cycles ? PermutationCyclesQ] :=
    Enclose @ TensorNetwork[arrays, in, ConfirmBy[Permute[TensorNetworkFreeIndices[in], perm], ListQ]]

(* Handle Transpose[Inactive[TensorContract][...], perm] from EinsteinSummation output *)
(* Store the permutation to be applied to the output *)
TensorNetwork[HoldPattern[Transpose[expr_, perm_Cycles]]] := With[{
    tn = TensorNetwork[expr]
},
    TensorNetwork[tn["Tensors"], tn["Hyperedges"], perm] /; TensorNetworkQ[tn]
]

(* Handle TensorContract with multi-index contractions (generalized from binary-only) *)
tensorNetworkFromTensorContract[tensors_List, contractions_List] := Block[{ranks, indices},
    ranks = tensorRank /@ tensors;
    indices = Range[Total[ranks]];
    TensorNetwork[
        tensors,
        TakeList[
            (* For each contraction group, map all indices to the first one *)
            ReplacePart[indices, 
                Catenate[Thread[Rest[#] -> First[#]] & /@ contractions]
            ],
            ranks
        ]
    ]
]

TensorNetwork[
    IgnoringInactive @ HoldPattern @ TensorContract[
        TensorProduct[tensors__],
        contractions : {{__Integer} ...}
    ]
] := tensorNetworkFromTensorContract[{tensors}, contractions]

TensorNetwork[net_ ? TensorNetworkGraphQ] :=
    TensorNetwork @@ Lookup[TensorNetworkGraphData[net], {"Tensors", "ContractionIndices"}]

TensorNetwork[hypergraph : {___List}] := TensorNetwork[hypergraph -> Automatic]

TensorNetwork[hypergraph : {___List} -> out : _List | Automatic] := TensorNetwork[
    ArraySymbol[\[FormalCapitalT], ConstantArray[\[FormalD], Length[#]]] & /@ hypergraph,
    hypergraph,
    out
]

(* New pattern: hypergraph with dimension association *)
(* Indices can be integers or symbols; dims must cover all indices with integer values *)
TensorNetwork[
    hypergraph : {___List} -> out : _List | Automatic,
    dims_Association
] /; ContainsAll[Keys[dims], Union @@ hypergraph] && AllTrue[dims, IntegerQ] :=
    TensorNetwork[
        ArraySymbol[\[FormalCapitalT], Lookup[dims, Key[#]] & /@ #] & /@ hypergraph,
        hypergraph,
        out
    ]

(* New pattern: hypergraph with dimension list *)
(* Creates association by mapping Union of indices to the dimension list *)
TensorNetwork[
    hypergraph : {___List} -> out : _List | Automatic,
    dims_List
] /; Length[dims] == Length[Union @@ hypergraph] && AllTrue[dims, IntegerQ] :=
    TensorNetwork[hypergraph -> out, AssociationThread[Union @@ hypergraph, dims]]


(* Property dispatch - only called when TensorNetworkQ is True *)
(tn_TensorNetwork ? TensorNetworkQ)[prop_, args___] := TensorNetworkProp[tn, prop, args]

(* Property handlers *)
TensorNetworkProp[TensorNetwork[tensors_, _, _], "Tensors"] := tensors
TensorNetworkProp[TensorNetwork[_, hyperedges_, _], "Hyperedges"] := hyperedges
TensorNetworkProp[TensorNetwork[_, _, output_], "Output"] := output

TensorNetworkProp[tn_, "FreeIndices"] := Replace[tn["Output"], Automatic :> TensorNetworkFreeIndices[tn["Hyperedges"]]]

TensorNetworkProp[tn_, "Dimensions"] := tensorDimensions /@ tn["Tensors"]

TensorNetworkProp[tn_, "Indices"] := MapIndexed[Thread[Superscript[First[#2], #1]] &, tn["Hyperedges"]]

TensorNetworkSize[tn_ ? TensorNetworkQ] := Length[tn["Hyperedges"]]

TensorNetworkProp[tn_, "Size"] := TensorNetworkSize[tn]

TensorNetworkProp[tn_, "IndexDimensions"] := TensorNetworkIndexDimensions[tn]

TensorNetworkProp[tn_, "Ranks"] := tensorRank /@ tn["Tensors"]

ToTensorNetworkGraph[tn_ ? TensorNetworkQ, opts___] := ToTensorNetworkGraph[tn["Tensors"], tn["Hyperedges"], opts]

TensorNetworkProp[tn_, "Graph", opts___] := ToTensorNetworkGraph[tn, opts]

TensorNetworkProp[tn_, "GraphData"] := TensorNetworkGraphData[tn["Graph"]]

TensorNetworkProp[tn_, "Data"] := TensorNetworkData[tn]

TensorNetworkContractions[tn_ ? TensorNetworkQ]  := With[{
    hyperedges = tn["Hyperedges"],
    indices = tn["Indices"]
},
    Replace[
        hyperedges,
        Replace[GroupBy[Catenate[indices], Last], {x_} :> x, 1],
        {2}
    ]
]

TensorNetworkProp[tn_, "Contractions"] := TensorNetworkContractions[tn]

TensorNetworkData[tn_TensorNetwork ? TensorNetworkQ, key_String] := tn["Data"][key]

TensorNetworkData[tn_TensorNetwork ? TensorNetworkQ] := tensorNetworkData[tn["Tensors"], tn["Hyperedges"], tn["FreeIndices"]]

(* a network's data from its parts, without constructing the network *)
tensorNetworkData[tensors_List, hyperedges_List, freeIndices_] := With[{
    indices = MapIndexed[Thread[Superscript[First[#2], #1]] &, hyperedges],
    dimensions = tensorDimensions /@ tensors
}, {
    indexDimensions = Association @ Catenate @ MapThread[Thread[#1 -> #2] &, {indices, dimensions}],
    hyperedgeGroups = GroupBy[Catenate[hyperedges], Identity],
    indexGroups = GroupBy[Catenate[indices], Last]
},
    <|
        "Tensors" -> tensors,
        "Dimensions" -> dimensions,
        "Hyperedges" -> hyperedges,
        "Indices" -> indices,
        "Vertices" -> Range[Length[tensors]],
        "Bonds" -> With[{bondGroups = Select[indexGroups, Length[#] > 1 &]},
            Thread[Values[bondGroups] -> Lookup[indexDimensions, Values[bondGroups][[All, 1]]]]
        ],
        "Contractions" -> Replace[hyperedges, Replace[indexGroups, {x_} :> x, 1], {2}],
        "ContractionIndices" -> Replace[hyperedges, First /@ hyperedgeGroups, {2}],
        "FreeIndices" -> freeIndices
    |>
]

TensorNetworkProp[tn_, prop_String] /;
    MemberQ[{"Indices", "Vertices", "FreeIndices", "Bonds", "Contractions", "ContractionIndices"}, prop] :=
        Lookup[tn["Data"], prop]

TensorNetworkProp[tn_, "OutputDimensions"] := Lookup[TensorNetworkIndexDimensions[tn], tn["FreeIndices"]]

TensorNetworkProp[tn_, "OutputDimension"] := Times @@ tn["OutputDimensions"]

TensorNetworkProp[tn_, "Hypergraph", opts___] := With[{he = tn["Hyperedges"]},
    PacletSymbol["WolframInstitute/Hypergraph", "Hypergraph"][
        he,
        opts,
        VertexLabels -> Automatic,
        EdgeLabels -> Thread[he -> Range[Length[he]]],
        EdgeStyle -> MapIndexed[#1 -> ColorData[97][First[#2]] &, he],
        EdgeLabelStyle -> MapIndexed[#1 -> Directive[Bold, Darker[ColorData[97][First[#2]], 0.3]] &, he]
    ]
]

TensorNetworkProp[tn_, "BinaryQ"] := BinaryTensorNetworkQ[tn]
TensorNetworkProp[tn_, "SparseQ"] := AllTrue[tn["Tensors"], SparseArrayQ]

BinaryTensorNetworkQ[tn_TensorNetwork ? TensorNetworkQ] := AllTrue[Counts[Catenate @ tn["Hyperedges"]], # <= 2 &]

(* Helper function to avoid documentation introspection issues.
   An output index's spider gets an extra free leg under the index's name, so the output
   survives; an output index on two tensors is spidered too. *)
binaryTensorNetworkImpl[tn_] := Block[{
    hyperedges = tn["Hyperedges"],
    output = Replace[tn["Output"], Automatic -> {}],
    indexHyperedges, dimensions, spidersIndices
},
    indexHyperedges = Select[
        GroupBy[
            Catenate @ MapIndexed[List, hyperedges, {2}],
            First -> Last
        ],
        Length[#] > 2 &
    ];
    indexHyperedges = Join[
        indexHyperedges,
        KeySelect[
            GroupBy[Catenate @ MapIndexed[List, hyperedges, {2}], First -> Last],
            MemberQ[output, #] &
        ] // Select[Length[#] == 2 &]
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
                With[{rank = Length[#2] + Boole[MemberQ[output, #1]]},
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
            MapThread[
                Join[Values[#1], If[MemberQ[output, #2], {#2}, {}]] &,
                {spidersIndices, Keys[indexHyperedges]}
            ]
        ],
        tn["Output"]
    ]
]

BinaryTensorNetwork[tn_TensorNetwork ? TensorNetworkQ] := binaryTensorNetworkImpl[tn]

    

TensorNetworkProp[_, "Properties"] := {
    "Tensors", "Hyperedges", "FreeIndices",
    "Hypergraph",
    "Dimensions", "Ranks",
    "Indices", "IndexDimensions",
    "Vertices", "Bonds", "Contractions", "ContractionIndices",
    "BinaryQ",
    "SparseQ",
    "Graph", "GraphData", "Data"
}

(* Fallback for unknown properties *)
TensorNetworkProp[_, prop_] := Missing["UnknownProperty", prop]



TensorNetworkGraphData[tn_TensorNetwork ? TensorNetworkQ] := TensorNetworkGraphData[tn["Graph"]]
TensorNetworkTensors[tn_TensorNetwork ? TensorNetworkQ] := tn["Tensors"]
TensorNetworkIndices[tn_TensorNetwork ? TensorNetworkQ] := tn["Indices"]

TensorNetworkFreeIndices[tn_TensorNetwork ? TensorNetworkQ] := tn["FreeIndices"]
TensorNetworkFreeIndices[indices_List] /; AllTrue[indices, ListQ] := Keys @ Select[Counts[Catenate[indices]], # == 1 &]

TensorNetworkIndexDimensions[tn_TensorNetwork ? TensorNetworkQ] :=
    TensorNetworkIndexDimensions[<|"Indices" -> tn["Hyperedges"], "Dimensions" -> tn["Dimensions"]|>]

SparseTensorNetwork[tn_TensorNetwork ? TensorNetworkQ] :=
    TensorNetwork[If[tensorRank[#] > 0, SparseArray[#], #] & /@ tn["Tensors"], tn["Hyperedges"], tn["Output"]]

Options[RandomTensorNetwork] = {Method -> Automatic, "Boundary" -> "Open"}

RandomTensorNetwork[{n_Integer, m_Integer}, args___] := RandomTensorNetwork[RandomGraph[{n, m}], args];

(* Fixed dimension: {dim} means all indices have dimension dim *)
RandomTensorNetwork[g_ ? GraphQ, {fixedDim_Integer}, additionalRank_Integer : 0, opts : OptionsPattern[]] := 
    Enclose @ Block[{ranks, tensors, indices, curIndices, rules, dimensions},
        ranks = Table[
            RandomInteger[{minRank, minRank + additionalRank}],
            {minRank, VertexDegree[g]}
        ];
        
        indices = curIndices = TakeList[Range[Total[ranks]], ranks];
        rules = Map[
            With[
                {i = RandomInteger[{1, Length[curIndices[[#]]]}]},
                {ret = curIndices[[#, i]]},
                curIndices[[#]] = Delete[curIndices[[#]], i];
                ret
            ] &,
            Rule @@@ EdgeList[IndexGraph[g]],
            {2}
        ];
        indices = Replace[indices, rules, {2}];
        (* All dimensions are fixed to fixedDim *)
        dimensions = Map[ConstantArray[fixedDim, Length[#]] &, indices];
        tensors = Switch[OptionValue[Method], "Complex", RandomComplex[{-1 - I, 1 + I}, #], _, RandomReal[{-1, 1}, #]] & /@ dimensions;
        
        TensorNetwork[tensors, indices]
    ]

(* Random dimensions: up to maxDimension *)
RandomTensorNetwork[g_ ? GraphQ, maxDimension_Integer : 2, additionalRank_Integer : 0, OptionsPattern[]] := Enclose @ Block[{
    ranks, tensors, indices, curIndices, rules, dimensions
},
    ranks = Table[
        RandomInteger[{minRank, minRank + additionalRank}],
        {minRank, VertexDegree[g]}
    ];
	
	indices = curIndices = TakeList[Range[Total[ranks]], ranks];
	rules = Map[
        With[
            {i = RandomInteger[{1, Length[curIndices[[#]]]}]},
            {ret = curIndices[[#, i]]},
            curIndices[[#]] = Delete[curIndices[[#]], i];
            ret
        ] &,
        Rule @@@ EdgeList[IndexGraph[g]],
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

(* Helper: generate random tensor with given dimensions *)
randomTensor[dims_, opts___] := With[{method = OptionValue[{opts, Options[RandomTensorNetwork]}, Method]},
    Switch[method, "Complex", RandomComplex[{-1 - I, 1 + I}, dims], _, RandomReal[{-1, 1}, dims]]
]

(* ============================================ *)
(* MPS: Matrix Product State                   *)
(* ============================================ *)
RandomTensorNetwork["MPS"[length_Integer, bondDim_Integer, physicalDim_Integer : 2], opts : OptionsPattern[]] := 
    Block[{tensors, indices, boundary, periodic, physStart},
        boundary = OptionValue[{opts, Options[RandomTensorNetwork]}, "Boundary"];
        periodic = boundary === "Periodic";
        physStart = length + 1;  (* Physical indices start after bond indices *)
        
        If[periodic,
            (* Periodic MPS: all tensors are rank-3 *)
            tensors = Table[randomTensor[{bondDim, bondDim, physicalDim}, opts], length];
            indices = Table[{Mod[i - 1, length] + 1, Mod[i, length] + 1, physStart + i - 1}, {i, length}],
            (* Open MPS: boundaries are rank-2, bulk is rank-3 *)
            tensors = Join[
                {randomTensor[{bondDim, physicalDim}, opts]},  (* left boundary *)
                Table[randomTensor[{bondDim, bondDim, physicalDim}, opts], Max[0, length - 2]],  (* bulk *)
                If[length > 1, {randomTensor[{bondDim, physicalDim}, opts]}, {}]  (* right boundary *)
            ];
            indices = Join[
                {{1, physStart}},  (* left: bond to right, physical *)
                Table[{i - 1, i, physStart + i - 1}, {i, 2, length - 1}],  (* bulk *)
                If[length > 1, {{length - 1, physStart + length - 1}}, {}]  (* right: bond to left, physical *)
            ]
        ];
        
        TensorNetwork[tensors, indices]
    ]

(* ============================================ *)
(* TT: Tensor Train (no physical indices)      *)
(* ============================================ *)
RandomTensorNetwork["TT"[length_Integer, bondDim_Integer], opts : OptionsPattern[]] := 
    Block[{tensors, indices, boundary, periodic},
        boundary = OptionValue[{opts, Options[RandomTensorNetwork]}, "Boundary"];
        periodic = boundary === "Periodic";
        
        If[periodic,
            (* Periodic TT (Tensor Ring): all tensors are rank-2 matrices *)
            tensors = Table[randomTensor[{bondDim, bondDim}, opts], length];
            indices = Table[{Mod[i - 1, length] + 1, Mod[i, length] + 1}, {i, length}],
            (* Open TT: boundaries are vectors, bulk is matrices *)
            tensors = Join[
                {randomTensor[{bondDim}, opts]},  (* left boundary vector *)
                Table[randomTensor[{bondDim, bondDim}, opts], Max[0, length - 2]],  (* bulk matrices *)
                If[length > 1, {randomTensor[{bondDim}, opts]}, {}]  (* right boundary vector *)
            ];
            indices = Join[
                {{1}},  (* left *)
                Table[{i - 1, i}, {i, 2, length - 1}],  (* bulk *)
                If[length > 1, {{length - 1}}, {}]  (* right *)
            ]
        ];
        
        TensorNetwork[tensors, indices]
    ]

(* ============================================ *)
(* MPO: Matrix Product Operator                *)
(* ============================================ *)
RandomTensorNetwork["MPO"[length_Integer, bondDim_Integer, physicalDim_Integer : 2], opts : OptionsPattern[]] := 
    Block[{tensors, indices, boundary, periodic, physInStart, physOutStart},
        boundary = OptionValue[{opts, Options[RandomTensorNetwork]}, "Boundary"];
        periodic = boundary === "Periodic";
        physInStart = length + 1;
        physOutStart = 2 length + 1;
        
        If[periodic,
            (* Periodic MPO: all tensors are rank-4 *)
            tensors = Table[randomTensor[{bondDim, bondDim, physicalDim, physicalDim}, opts], length];
            indices = Table[{Mod[i - 1, length] + 1, Mod[i, length] + 1, physInStart + i - 1, physOutStart + i - 1}, {i, length}],
            (* Open MPO: boundaries are rank-3, bulk is rank-4 *)
            tensors = Join[
                {randomTensor[{bondDim, physicalDim, physicalDim}, opts]},  (* left *)
                Table[randomTensor[{bondDim, bondDim, physicalDim, physicalDim}, opts], Max[0, length - 2]],  (* bulk *)
                If[length > 1, {randomTensor[{bondDim, physicalDim, physicalDim}, opts]}, {}]  (* right *)
            ];
            indices = Join[
                {{1, physInStart, physOutStart}},  (* left *)
                Table[{i - 1, i, physInStart + i - 1, physOutStart + i - 1}, {i, 2, length - 1}],  (* bulk *)
                If[length > 1, {{length - 1, physInStart + length - 1, physOutStart + length - 1}}, {}]  (* right *)
            ]
        ];
        
        TensorNetwork[tensors, indices]
    ]

(* ============================================ *)
(* PEPS: Projected Entangled Pair State        *)
(* ============================================ *)
(* Label scheme (consecutive, like MPS): vertical bonds 1..(rows-1)*cols,
   horizontal bonds next rows*(cols-1), physical legs at the end. Both
   endpoints of a bond compute the same integer from their (r,c) coordinates,
   so no shared counter is needed across iterations. *)
RandomTensorNetwork["PEPS"[{rows_Integer, cols_Integer}, bondDim_Integer, physicalDim_Integer : 2], opts : OptionsPattern[]] := With[{
    horizOffset = (rows - 1) * cols
}, {
    (* sites in row-major order, each {tensor, labels}: up, down, left, right bonds, then physical *)
    sites = Flatten[
        Table[
            With[{
                bondList = Join[
                    If[r > 1, {(r - 2) * cols + c}, {}],
                    If[r < rows, {(r - 1) * cols + c}, {}],
                    If[c > 1, {horizOffset + (r - 1) * (cols - 1) + c - 1}, {}],
                    If[c < cols, {horizOffset + (r - 1) * (cols - 1) + c}, {}]
                ],
                phys = horizOffset + rows * (cols - 1) + (r - 1) * cols + c
            },
                {randomTensor[Join[ConstantArray[bondDim, Length[bondList]], {physicalDim}], opts], Append[bondList, phys]}
            ],
            {r, rows}, {c, cols}
        ],
        1
    ]
},
    TensorNetwork[sites[[All, 1]], sites[[All, 2]]]
]

(* Alternative PEPS syntax *)
RandomTensorNetwork["PEPS"[rows_Integer, cols_Integer, bondDim_Integer, physicalDim_Integer : 2], opts___] := 
    RandomTensorNetwork["PEPS"[{rows, cols}, bondDim, physicalDim], opts]

(* ============================================ *)
(* TTN: Tree Tensor Network                    *)
(* ============================================ *)
(* Label scheme: single counter starting at 1. Each level remembers where
   its nodes began so the next level can address its children by absolute
   index without arithmetic depending on the running counter. *)
RandomTensorNetwork["TTN"[depth_Integer, bondDim_Integer, branching_Integer : 2], opts : OptionsPattern[]] := With[{
    (* first label of each level: the leaves, then each internal level's parent bonds *)
    starts = FoldList[Plus, 1, Table[branching^(depth - 1 - level), {level, 0, depth - 2}]]
}, {
    nodes = Join[
        Table[{randomTensor[{bondDim}, opts], {k}}, {k, branching^(depth - 1)}],
        Catenate @ Table[
            Table[
                {
                    randomTensor[ConstantArray[bondDim, If[level < depth - 1, branching + 1, branching]], opts],
                    Join[
                        Table[starts[[level]] + (node - 1) * branching + k - 1, {k, branching}],
                        If[level < depth - 1, {starts[[level + 1]] + node - 1}, {}]
                    ]
                },
                {node, branching^(depth - 1 - level)}
            ],
            {level, 1, depth - 1}
        ]
    ]
},
    TensorNetwork[nodes[[All, 1]], nodes[[All, 2]]]
]

(* ============================================ *)
(* MERA: Multi-scale Entanglement Renormalization Ansatz *)
(* ============================================ *)
(* Label scheme: single counter starting at 1. Per layer, fresh integers are
   allocated for inputs (width slots), disentangler-to-isometry mid (width
   slots), and outputs (width/2 slots). Layer k > 1 reuses the prior layer's
   outputs as the first width/2 of its inputs; the remaining width/2 are
   fresh (and become free legs, matching the constant-width topology). *)
RandomTensorNetwork["MERA"[width_Integer, bondDim_Integer, layers_Integer : 1], opts : OptionsPattern[]] := With[{
    (* per layer {inputs, mid, outputs}; a layer's inputs start with the previous layer's outputs *)
    labelSets = Rest @ FoldList[
        Function[{state, layer}, With[{
            n = state[[1]], previous = state[[2]][[3]]
        }, With[{
            mid = n + width - Length[previous], half = Floor[width / 2]
        },
            {
                mid + width + half,
                {Join[previous, Range[n, mid - 1]], Range[mid, mid + width - 1], Range[mid + width, mid + width + half - 1]}
            }
        ]]],
        {1, {{}, {}, {}}},
        Range[layers]
    ][[All, 2]]
}, {
    nodes = Catenate @ Map[
        Function[sets, With[{inputs = sets[[1]], mid = sets[[2]], outputs = sets[[3]]},
            Join[
                (* disentanglers: 2 in, 2 out *)
                Table[{randomTensor[{bondDim, bondDim, bondDim, bondDim}, opts], {inputs[[2 i - 1]], inputs[[2 i]], mid[[2 i - 1]], mid[[2 i]]}}, {i, width / 2}],
                (* isometries: 2 in, 1 out *)
                Table[{randomTensor[{bondDim, bondDim, bondDim}, opts], {mid[[2 i - 1]], mid[[2 i]], outputs[[i]]}}, {i, width / 2}]
            ]
        ]],
        labelSets
    ]
},
    TensorNetwork[nodes[[All, 1]], nodes[[All, 2]]]
]


TensorNetworkAdd::rank = "Tensor rank `1` does not match the length of the index list `2`.";

TensorNetworkAdd[net_ ? TensorNetworkQ, tensor_, indices_List] /; tensorRank[tensor] =!= Length[indices] := (
    Message[TensorNetworkAdd::rank, tensorRank[tensor], Length[indices]];
    $Failed
)

TensorNetworkAdd[net_ ? TensorNetworkQ, tensor_, indices_List] := With[{
    newHyperedges = Append[net["Hyperedges"], indices]
},
    TensorNetwork[
        Append[net["Tensors"], tensor],
        newHyperedges,
        (* Update output: remove indices that become contracted, add new free indices *)
        Replace[net["Output"], Except[Automatic] :> With[{
            freeAfter = TensorNetworkFreeIndices[newHyperedges]
        },
            (* Keep indices from current output that are still free, then add new free indices *)
            Join[Select[net["FreeIndices"], MemberQ[freeAfter, #] &], DeleteElements[indices, Catenate[net["Hyperedges"]]]]
        ]]
    ]
]

(* An explicit output keeps the labels some remaining tensor still carries, and gains the bonds
   of the deleted tensor that are now carried by one tensor alone: they become free legs, as
   they would with an Automatic output *)
TensorNetworkDelete[net_ ? TensorNetworkQ, index_Integer : -1] /; 1 <= Abs[index] <= Length[net["Tensors"]] := With[{
    hyperedges = net["Hyperedges"], remaining = Delete[net["Hyperedges"], index]
}, {
    counts = Counts[Catenate[remaining]]
},
    TensorNetwork[
        Delete[net["Tensors"], index],
        remaining,
        Replace[net["Output"], Except[Automatic] :> With[{kept = Select[net["FreeIndices"], KeyExistsQ[counts, #] &]},
            Join[kept, Select[DeleteDuplicates[hyperedges[[index]]], Lookup[counts, Key[#], 0] == 1 && ! MemberQ[kept, #] &]]
        ]]
    ]
]


(* Summary Box - NoEntry is handled by System`Private`HoldSetNoEntry *)
TensorNetwork /: MakeBoxes[tn_TensorNetwork /; TensorNetworkQ[Unevaluated[tn]], fmt_] := With[{
    nTensors = Length[tn["Tensors"]],
    hyperedges = tn["Hyperedges"],
    freeIndices = tn["FreeIndices"],
    dims = tn["Dimensions"]
},
    BoxForm`ArrangeSummaryBox[
        TensorNetwork,
        tn,
        (* Icon - skip complex hypergraph plot for non-binary networks to avoid crashes *)
        If[ nTensors > 10 || !tn["BinaryQ"],
            BlockRandom[
                RandomGraph[{10, 20}, EdgeStyle -> LightGray, ImageSize -> 32, AspectRatio -> 1],
                RandomSeeding -> 42
            ],
            PacletSymbol["WolframInstitute/Hypergraph", "SimpleHypergraphPlot"][
                hyperedges,
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
            BoxForm`SummaryItem[{"Output dimensions: ", tn["OutputDimensions"]}],
            BoxForm`SummaryItem[{"Tensor dimensions: ", Pane[dims, 256]}]
        },
        fmt
    ]
]
