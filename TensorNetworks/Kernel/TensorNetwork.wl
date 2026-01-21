(* ::Package:: *)

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
tensorNetworkQ[TensorNetwork[tensors_List, hyperedges : {___List}, perm : _Cycles : Cycles[{}]]] := 
    Length[tensors] == Length[hyperedges] && 
    With[{dimensions = tensorDimensions /@ tensors},
        AllTrue[Thread[{dimensions, hyperedges}], Apply[Length[#1] == Length[#2] &]] &&
        With[{allDimensions = Catenate[dimensions]},
            AllTrue[PositionIndex[Catenate[hyperedges]], Equal @@ allDimensions[[#]] &]
        ]
    ] &&
    Length[Select[Counts[Catenate[hyperedges]], # == 1 &]] >= PermutationMax[perm]

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

(* Normalize 2-arg form to 3-arg form with identity permutation *)
TensorNetwork[tensors_List, hyperedges : {___List}] := TensorNetwork[tensors, hyperedges, Cycles[{}]]

(* Direct EinsteinSummation-style input: TensorNetwork[arrays, in -> out] *)
TensorNetwork[arrays_List, in_List -> out_List] := Module[{
    nonFreePos, freePos, nonFreeIn, nonFreeArray,
    newArrays, newIn, indexMap
},
    (* Check if any output index appears in multiple tensors (needs TensorJoin) *)
    If[AnyTrue[out, Count[in, {___, #, ___}] > 1 &],
        (* Use TensorJoin like EinsteinSummation does *)
        nonFreePos = Catenate @ Position[in, _ ? (ContainsAny[out]), {1}, Heads -> False];
        freePos = Complement[Range[Length[in]], nonFreePos];
        {nonFreeIn, nonFreeArray} = TensorJoin[in[[nonFreePos]], arrays[[nonFreePos]]];
        newArrays = Prepend[arrays[[freePos]], nonFreeArray];
        newIn = Prepend[in[[freePos]], nonFreeIn],
        (* No TensorJoin needed *)
        newArrays = arrays;
        newIn = in
    ];
    
    (* Build TensorNetwork from (possibly transformed) tensors *)
    indexMap = First /@ PositionIndex[Catenate[newIn]];
    TensorNetwork[
        newArrays,
        Map[Lookup[indexMap, #] &, newIn, {2}],
        FindPermutation[
            SortBy[out, Lookup[indexMap, #] &],
            out
        ]
    ]
]

(* Without output - identity permutation *)
TensorNetwork[arrays_List, in_List] /; AllTrue[in, ListQ] := With[{
    indexMap = First /@ PositionIndex[Catenate[in]]
},
    TensorNetwork[
        arrays,
        Map[Lookup[indexMap, #] &, in, {2}],
        Cycles[{}]
    ]
]

(* Handle Transpose[Inactive[TensorContract][...], perm] from EinsteinSummation output *)
(* Store the permutation to be applied to the output *)
TensorNetwork[HoldPattern[Transpose[expr_, perm_Cycles]]] := With[{
    tn = TensorNetwork[expr]
},
    TensorNetwork[tn["Tensors"], tn["Hyperedges"], perm] /; TensorNetworkQ[tn]
]

(* Handle TensorContract with multi-index contractions (generalized from binary-only) *)
TensorNetwork[
    IgnoringInactive @ HoldPattern @ TensorContract[
        TensorProduct[tensors__],
        contractions : {{__Integer} ...}
    ]
] := With[{
    ranks = tensorRank /@ {tensors}
}, {
    indices = Range[Total[ranks]]
},
    TensorNetwork[
        {tensors},
        TakeList[
            (* For each contraction group, map all indices to the first one *)
            ReplacePart[indices, 
                Catenate[Thread[Rest[#] -> First[#]] & /@ contractions]
            ],
            ranks
        ],
        Cycles[{}]
    ]
]

TensorNetwork[net_ ? TensorNetworkGraphQ] :=
    TensorNetwork @@ Lookup[TensorNetworkGraphData[net], {"Tensors", "ContractionIndices"}]

TensorNetwork[hypergraph : {___List}, perm : _Cycles : Cycles[{}]] := TensorNetwork[
    ArraySymbol[\[FormalCapitalT], ConstantArray[\[FormalD], Length[#]]] & /@ hypergraph,
    hypergraph,
    perm
]

TensorNetwork[args___, perm : {___Integer}] := TensorNetwork[args, PermutationCycles[perm]]


(* Property dispatch - only called when TensorNetworkQ is True *)
(tn_TensorNetwork ? TensorNetworkQ)[prop_, args___] := TensorNetworkProp[tn, prop, args]

(* Property handlers *)
TensorNetworkProp[TensorNetwork[tensors_, _, _], "Tensors"] := tensors
TensorNetworkProp[TensorNetwork[_, hyperedges_, _], "Hyperedges"] := hyperedges
TensorNetworkProp[TensorNetwork[_, _, perm_], "Permutation"] := perm

TensorNetworkProp[tn_, "Dimensions"] := tensorDimensions /@ tn["Tensors"]

TensorNetworkProp[tn_, "Indices"] := MapIndexed[Thread[Labeled[First[#2], #1]] &, tn["Hyperedges"]]

TensorNetworkSize[tn_ ? TensorNetworkQ] := Length[tn["Hyperedges"]]

TensorNetworkProp[tn_, "Size"] := TensorNetworkSize[tn]

TensorNetworkProp[tn_, "IndexDimensions"] := TensorNetworkIndexDimensions[tn]

TensorNetworkProp[tn_, "Ranks"] := tensorRank /@ tn["Tensors"]

ToTensorNetworkGraph[tn_ ? TensorNetworkQ, opts___] := ToTensorNetworkGraph[tn["Tensors"], tn["Hyperedges"], opts]

TensorNetworkProp[tn_, "Graph", opts___] := ToTensorNetworkGraph[tn, opts]

TensorNetworkProp[tn_, "GraphData"] := TensorNetworkProp[tn, "GraphData"] = TensorNetworkGraphData[tn["Graph"]]

TensorNetworkProp[tn_, "Data"] := TensorNetworkProp[tn, "Data"] = TensorNetworkData[tn]

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

TensorNetworkData[tn_TensorNetwork ? TensorNetworkQ] := With[{
    tensors = tn["Tensors"],
    hyperedges = tn["Hyperedges"],
    perm = tn["Permutation"]
}, {
    indices = MapIndexed[Thread[Labeled[First[#2], #1]] &, hyperedges],
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
        "FreeIndices" -> Permute[Catenate @ Values @ Select[hyperedgeGroups, Length[#] == 1 &], perm]
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

BinaryTensorNetwork[tn_TensorNetwork ? TensorNetworkQ] := Block[{hyperedges = tn["Hyperedges"], perm = tn["Permutation"], indexHyperedges, dimensions, spidersIndices},
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
        ],
        perm  (* Preserve the original permutation *)
    ]
    
]
    

TensorNetworkProp[_, "Properties"] := {
    "Tensors", "Hyperedges", "Permutation",
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
    TensorNetworkIndexDimensions[<|"Indices" -> tn["Hyperedges"], "Dimensions" -> tn["Dimensions"]|>]

SparseTensorNetwork[tn_TensorNetwork ? TensorNetworkQ] :=
    TensorNetwork[If[tensorRank[#] > 0, SparseArray[#], #] & /@ tn["Tensors"], tn["Hyperedges"], tn["Permutation"]]

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
                curIndices[[#, i]] = Nothing;
                ret
            ] &,
            Rule @@@ EdgeList[g],
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
        RandomInteger[{minRank, minRank+ additionalRank}],
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
RandomTensorNetwork["PEPS"[{rows_Integer, cols_Integer}, bondDim_Integer, physicalDim_Integer : 2], opts : OptionsPattern[]] := 
    Block[{tensors = {}, indices = {}, physIdx = 1000, vertBondBase = 100, horizBondBase = 200},
        Do[
            With[{
                (* Determine which bonds exist *)
                upBond = If[r > 1, vertBondBase + (r - 2) * cols + c, Nothing],
                downBond = If[r < rows, vertBondBase + (r - 1) * cols + c, Nothing],
                leftBond = If[c > 1, horizBondBase + (r - 1) * cols + c - 1, Nothing],
                rightBond = If[c < cols, horizBondBase + (r - 1) * cols + c, Nothing],
                phys = physIdx++
            },
                With[{
                    bondList = DeleteCases[{upBond, downBond, leftBond, rightBond}, Nothing],
                    dims = Join[ConstantArray[bondDim, Length @ DeleteCases[{upBond, downBond, leftBond, rightBond}, Nothing]], {physicalDim}]
                },
                    AppendTo[tensors, randomTensor[dims, opts]];
                    AppendTo[indices, Append[bondList, phys]];
                ]
            ],
            {r, rows}, {c, cols}
        ];
        
        TensorNetwork[tensors, indices]
    ]

(* Alternative PEPS syntax *)
RandomTensorNetwork["PEPS"[rows_Integer, cols_Integer, bondDim_Integer, physicalDim_Integer : 2], opts___] := 
    RandomTensorNetwork["PEPS"[{rows, cols}, bondDim, physicalDim], opts]

(* ============================================ *)
(* TTN: Tree Tensor Network                    *)
(* ============================================ *)
RandomTensorNetwork["TTN"[depth_Integer, bondDim_Integer, branching_Integer : 2], opts : OptionsPattern[]] := 
    Block[{tensors = {}, indices = {}, idx = 1, leafCount, nodesAtLevel},
        leafCount = branching^(depth - 1);
        
        (* Leaves: vectors *)
        Do[
            AppendTo[tensors, randomTensor[{bondDim}, opts]];
            AppendTo[indices, {idx++}],
            leafCount
        ];
        
        (* Internal nodes level by level *)
        Do[
            nodesAtLevel = branching^(depth - 1 - level);
            Do[
                With[{
                    childIndices = Table[idx - nodesAtLevel * branching - branching + (node - 1) * branching + k, {k, branching}],
                    parentIdx = If[level < depth - 1, idx++, Nothing]
                },
                    AppendTo[tensors, randomTensor[
                        ConstantArray[bondDim, If[level < depth - 1, branching + 1, branching]], 
                        opts
                    ]];
                    AppendTo[indices, DeleteCases[Append[childIndices, parentIdx], Nothing]];
                ],
                {node, nodesAtLevel}
            ],
            {level, 1, depth - 1}
        ];
        
        TensorNetwork[tensors, indices]
    ]

(* ============================================ *)
(* MERA: Multi-scale Entanglement Renormalization Ansatz *)
(* ============================================ *)
RandomTensorNetwork["MERA"[width_Integer, bondDim_Integer, layers_Integer : 1], opts : OptionsPattern[]] := 
    Block[{tensors = {}, indices = {}, idx = 1, disentanglerBase, isometryBase, inputBase, outputBase},
        Do[
            inputBase = If[layer == 1, 1000, 3000 + (layer - 2) * width];
            disentanglerBase = 1000 + (layer - 1) * 2 * width;
            isometryBase = disentanglerBase + width;
            outputBase = If[layer == layers, 2000, 3000 + (layer - 1) * width];
            
            (* Disentanglers: rank-4 tensors (2 in, 2 out) *)
            Do[
                AppendTo[tensors, randomTensor[{bondDim, bondDim, bondDim, bondDim}, opts]];
                AppendTo[indices, {
                    inputBase + 2 i - 1,      (* input 1 *)
                    inputBase + 2 i,          (* input 2 *)
                    disentanglerBase + 2 i - 1,  (* output 1 to isometry *)
                    disentanglerBase + 2 i       (* output 2 to isometry *)
                }],
                {i, width / 2}
            ];
            
            (* Isometries: rank-3 tensors (2 in, 1 out) *)
            Do[
                AppendTo[tensors, randomTensor[{bondDim, bondDim, bondDim}, opts]];
                AppendTo[indices, {
                    disentanglerBase + 2 i - 1,  (* from disentangler *)
                    disentanglerBase + 2 i,      (* from disentangler *)
                    outputBase + i               (* output *)
                }],
                {i, width / 2}
            ],
            {layer, layers}
        ];
        
        TensorNetwork[tensors, indices]
    ]

TensorNetworkAdd[net_ ? TensorNetworkQ, tensor_, indices_List] := Block[{
    hyperedges = net["Hyperedges"],
    perm = net["Permutation"],
    allIndices, existingFreeCount, newFreeIndices, newFreeCount, newPerm
},
    allIndices = Catenate[hyperedges];
    existingFreeCount = Count[Counts[allIndices], 1];
    
    (* Find which new indices are free (not contracting with existing indices) *)
    newFreeIndices = Select[indices, Count[allIndices, #] == 0 &];
    newFreeCount = Length[newFreeIndices];
    
    (* Extend permutation: keep existing, add identity for new positions *)
    newPerm = If[newFreeCount == 0,
        perm,
        PermutationCycles @ Join[
            PermutationList[perm, existingFreeCount],
            Range[existingFreeCount + 1, existingFreeCount + newFreeCount]
        ]
    ];
    
    TensorNetwork[Append[net["Tensors"], tensor], Append[hyperedges, indices], newPerm]
]

TensorNetworkDelete[net_ ? TensorNetworkQ, index_Integer : -1] := Block[{
    hyperedges = net["Hyperedges"],
    perm = net["Permutation"],
    actualIndex, deletedHyperedge,
    freeIndicesOrdered, nFree, deletedPositions,
    remainingPositions, oldPermList, newPerm
},
    actualIndex = If[index < 0, Length[hyperedges] + index + 1, index];
    deletedHyperedge = hyperedges[[actualIndex]];
    
    (* Get free indices in order they appear *)
    freeIndicesOrdered = Keys @ Select[Counts[Catenate[hyperedges]], # == 1 &];
    nFree = Length[freeIndicesOrdered];
    
    (* Which positions (1-indexed) in the free index list are being deleted *)
    deletedPositions = Catenate @ Lookup[PositionIndex[freeIndicesOrdered], deletedHyperedge, {}];
    
    If[ Length[deletedPositions] == 0,
        (* No free indices deleted, permutation unchanged *)
        Return[TensorNetwork[Delete[net["Tensors"], index], Delete[hyperedges, index], perm]]
    ];
    
    remainingPositions = Complement[Range[nFree], deletedPositions];
    
    (* Get permutation as list *)
    oldPermList = PermutationList[perm, nFree];
    
    (* Filter: keep only positions that remain, and update values *)
    (* oldPermList[[remainingPositions]] gives which old positions map to remaining output positions *)
    (* Then we need to renumber: old position -> new position *)
    newPerm = PermutationCycles @ Ordering @ Ordering @ 
        (oldPermList[[remainingPositions]] /. Thread[remainingPositions -> Range[Length[remainingPositions]]]);
    
    TensorNetwork[Delete[net["Tensors"], index], Delete[hyperedges, index], newPerm]
]


(* Summary Box - NoEntry is handled by System`Private`HoldSetNoEntry *)
TensorNetwork /: MakeBoxes[tn_TensorNetwork /; TensorNetworkQ[tn], fmt_] := With[{
    nTensors = Length[tn["Tensors"]],
    freeIndices = tn["FreeIndices"],
    dims = tn["Dimensions"],
    perm = tn["Permutation"]
},
    BoxForm`ArrangeSummaryBox[
        TensorNetwork,
        tn,
        (* Icon - skip complex hypergraph plot for non-binary networks to avoid crashes *)
        If[ nTensors > 10 || !tn["BinaryQ"],
            RandomGraph[{Min[nTensors, 8], Min[nTensors, 10]}, EdgeStyle -> LightGray, ImageSize -> 32, AspectRatio -> 1],
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
            BoxForm`SummaryItem[{"Dimensions: ", Pane[dims, 256]}],
            BoxForm`SummaryItem[{"Permutation: ", perm}]
        },
        fmt
    ]
]
