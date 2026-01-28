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



(* Internal validation function - 3-argument form *)
tensorNetworkQ[TensorNetwork[tensors_List, hyperedges : {___List}, output : _List | Automatic]] :=
    Length[tensors] == Length[hyperedges] &&
    With[{dimensions = tensorDimensions /@ tensors},
        AllTrue[Thread[{dimensions, hyperedges}], Apply[Length[#1] == Length[#2] &]] &&
        With[{allDimensions = Catenate[dimensions]},
            AllTrue[PositionIndex[Catenate[hyperedges]], Equal @@ allDimensions[[#]] &]
        ]
    ] &&
    (output === Automatic || ContainsAll[Catenate[hyperedges], output])

(* Internal validation function - 4-argument form with metadata *)
tensorNetworkQ[TensorNetwork[tensors_List, hyperedges : {___List}, output : _List | Automatic, metadata_Association]] :=
    tensorNetworkQ[TensorNetwork[tensors, hyperedges, output]]

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

(* Normalize 2-arg to 3-arg *)
TensorNetwork[tensors_List, hyperedges : {___List}] := TensorNetwork[tensors, hyperedges, Automatic]

(* Normalize 4-arg with empty metadata to 3-arg *)
TensorNetwork[tensors_List, hyperedges : {___List}, output : _List | Automatic, metadata_Association] /;
    metadata === <||> := TensorNetwork[tensors, hyperedges, output]

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


(* Property dispatch - only called when TensorNetworkQ is True *)
(tn_TensorNetwork ? TensorNetworkQ)[prop_, args___] := TensorNetworkProp[tn, prop, args]

(* Property handlers *)
TensorNetworkProp[TensorNetwork[tensors_, _, _], "Tensors"] := tensors
TensorNetworkProp[TensorNetwork[tensors_, _, _, _], "Tensors"] := tensors
TensorNetworkProp[TensorNetwork[_, hyperedges_, _], "Hyperedges"] := hyperedges
TensorNetworkProp[TensorNetwork[_, hyperedges_, _, _], "Hyperedges"] := hyperedges
TensorNetworkProp[TensorNetwork[_, _, output_], "Output"] := output
TensorNetworkProp[TensorNetwork[_, _, output_, _], "Output"] := output

(* Metadata property - 4-argument form *)
TensorNetworkProp[TensorNetwork[_, _, _, metadata_Association], "Metadata"] := metadata
(* Metadata property - 3-argument form returns empty Association *)
TensorNetworkProp[TensorNetwork[_, _, _], "Metadata"] := <||>

(* IndexCharges accessor - looks up from metadata *)
TensorNetworkProp[tn_, "IndexCharges"] := Lookup[tn["Metadata"], "IndexCharges", None]

(* SymmetryType accessor - looks up from metadata *)
TensorNetworkProp[tn_, "SymmetryType"] := Lookup[tn["Metadata"], "SymmetryType", None]

(* SymmetricQ - check if TensorNetwork has symmetry information *)
TensorNetworkProp[tn_, "SymmetricQ"] := tn["IndexCharges"] =!= None

TensorNetworkProp[tn_, "FreeIndices"] := Replace[tn["Output"], Automatic :> TensorNetworkFreeIndices[tn["Hyperedges"]]]

TensorNetworkProp[tn_, "Dimensions"] := tensorDimensions /@ tn["Tensors"]

TensorNetworkProp[tn_, "Indices"] := MapIndexed[Thread[Superscript[First[#2], #1]] &, tn["Hyperedges"]]

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
    freeIndices = tn["FreeIndices"]
}, {
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

TensorNetworkProp[tn_, "Hypergraph", opts___] :=
    PacletSymbol["WolframInstitute/Hypergraph", "Hypergraph"][
        tn["Hyperedges"],
        opts,
        VertexLabels -> Automatic, EdgeLabels -> Thread[tn["Hyperedges"] -> Range[Length[tn["Hyperedges"]]]]
    ]

TensorNetworkProp[tn_, "BinaryQ"] := BinaryTensorNetworkQ[tn]
TensorNetworkProp[tn_, "SparseQ"] := AllTrue[tn["Tensors"], SparseArrayQ]

BinaryTensorNetworkQ[tn_TensorNetwork ? TensorNetworkQ] := AllTrue[Counts[Catenate @ tn["Hyperedges"]], # <= 2 &]

(* Helper function to avoid documentation introspection issues *)
binaryTensorNetworkImpl[tn_] := Block[{hyperedges = tn["Hyperedges"], indexHyperedges, dimensions, spidersIndices},
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
    "SymmetricQ",
    "Metadata", "IndexCharges", "SymmetryType",
    "Graph", "GraphData", "Data"
}

(* Fallback for unknown properties *)
TensorNetworkProp[_, prop_] := Missing["UnknownProperty", prop]



TensorNetworkGraphData[tn_TensorNetwork ? TensorNetworkQ] := TensorNetworkGraphData[tn["Graph"]]
TensorNetworkTensors[tn_TensorNetwork ? TensorNetworkQ] := tn["Tensors"]
TensorNetworkIndices[tn_TensorNetwork ? TensorNetworkQ] := tn["ContractionIndices"]

TensorNetworkFreeIndices[tn_TensorNetwork ? TensorNetworkQ] := tn["FreeIndices"]
TensorNetworkFreeIndices[indices_List] /; AllTrue[indices, ListQ] := Keys @ Select[Counts[Catenate[indices]], # == 1 &]

TensorNetworkIndexDimensions[tn_TensorNetwork ? TensorNetworkQ] :=
    TensorNetworkIndexDimensions[<|"Indices" -> tn["Hyperedges"], "Dimensions" -> tn["Dimensions"]|>]

SparseTensorNetwork[tn_TensorNetwork ? TensorNetworkQ] :=
    TensorNetwork[If[tensorRank[#] > 0, SparseArray[#], #] & /@ tn["Tensors"], tn["Hyperedges"], tn["Output"]]

Options[RandomTensorNetwork] = {Method -> Automatic, "Boundary" -> "Open", "Symmetry" -> None}

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
(* Symmetry Helpers for U(1) charge conservation *)
(* ============================================ *)

(* Generate U(1) charges for bond indices: cycles through 0 to nSectors-1 *)
makeBondCharges[bondDim_Integer, nSectors_Integer] := Mod[Range[bondDim] - 1, nSectors]

(* Generate charges for physical indices: centered around 0 *)
(* For physDim=2: {0, 1}, for physDim=3: {-1, 0, 1}, for physDim=4: {-1, 0, 1, 2} *)
makePhysicalCharges[physDim_Integer] := Range[0, physDim - 1] - Floor[(physDim - 1) / 2]

(* Generate block-sparse MPS tensor using SparseArray with full charge conservation *)
(* Charge conservation: qLeft + qPhysical = qRight (mod nSectors) *)
(* Tensor shape: {leftDim, rightDim, physDim} to match index ordering {leftBond, rightBond, physical} *)
generateSymmetricMPSTensor[leftDim_Integer, physDim_Integer, rightDim_Integer, nSectors_Integer, opts___] :=
    Module[{chargesL, chargesP, chargesR, rules, method},
        method = OptionValue[{opts, Options[RandomTensorNetwork]}, Method];
        chargesL = makeBondCharges[leftDim, nSectors];
        chargesP = makePhysicalCharges[physDim];
        chargesR = makeBondCharges[rightDim, nSectors];

        (* Build sparse rules: only where qL + qP = qR (mod nSectors) *)
        (* Index ordering: {left, right, physical} to match MPS convention *)
        rules = Flatten[Table[
            If[Mod[chargesL[[i]] + chargesP[[s]], nSectors] == chargesR[[j]],
                {i, j, s} -> Switch[method,
                    "Complex", RandomComplex[{-1 - I, 1 + I}],
                    _, RandomReal[{-1, 1}]
                ],
                Nothing
            ],
            {i, leftDim}, {j, rightDim}, {s, physDim}
        ], 2];

        SparseArray[rules, {leftDim, rightDim, physDim}]
    ]

(* Generate symmetric boundary tensor (rank-2): left boundary *)
generateSymmetricLeftBoundaryTensor[bondDim_Integer, physDim_Integer, nSectors_Integer, opts___] :=
    Module[{chargesP, chargesR, rules, method},
        method = OptionValue[{opts, Options[RandomTensorNetwork]}, Method];
        chargesP = makePhysicalCharges[physDim];
        chargesR = makeBondCharges[bondDim, nSectors];

        (* Left boundary has no left index, so qPhysical = qRight (mod nSectors) *)
        rules = Flatten[Table[
            If[Mod[chargesP[[s]], nSectors] == chargesR[[j]],
                {j, s} -> Switch[method,
                    "Complex", RandomComplex[{-1 - I, 1 + I}],
                    _, RandomReal[{-1, 1}]
                ],
                Nothing
            ],
            {s, physDim}, {j, bondDim}
        ], 1];

        SparseArray[rules, {bondDim, physDim}]
    ]

(* Generate symmetric boundary tensor (rank-2): right boundary *)
generateSymmetricRightBoundaryTensor[bondDim_Integer, physDim_Integer, nSectors_Integer, opts___] :=
    Module[{chargesL, chargesP, rules, method},
        method = OptionValue[{opts, Options[RandomTensorNetwork]}, Method];
        chargesL = makeBondCharges[bondDim, nSectors];
        chargesP = makePhysicalCharges[physDim];

        (* Right boundary has no right index, so qLeft + qPhysical = 0 (mod nSectors) *)
        rules = Flatten[Table[
            If[Mod[chargesL[[i]] + chargesP[[s]], nSectors] == 0,
                {i, s} -> Switch[method,
                    "Complex", RandomComplex[{-1 - I, 1 + I}],
                    _, RandomReal[{-1, 1}]
                ],
                Nothing
            ],
            {i, bondDim}, {s, physDim}
        ], 1];

        SparseArray[rules, {bondDim, physDim}]
    ]

(* Generate symmetric MPO bulk tensor (rank-4): qLeft + qPhysIn = qRight + qPhysOut (mod nSectors) *)
generateSymmetricMPOTensor[leftDim_Integer, rightDim_Integer, physDim_Integer, nSectors_Integer, opts___] :=
    Module[{chargesL, chargesR, chargesP, rules, method},
        method = OptionValue[{opts, Options[RandomTensorNetwork]}, Method];
        chargesL = makeBondCharges[leftDim, nSectors];
        chargesR = makeBondCharges[rightDim, nSectors];
        chargesP = makePhysicalCharges[physDim];

        (* MPO charge conservation: qLeft + qPhysIn = qRight + qPhysOut *)
        rules = Flatten[Table[
            If[Mod[chargesL[[i]] + chargesP[[pIn]], nSectors] == Mod[chargesR[[j]] + chargesP[[pOut]], nSectors],
                {i, j, pIn, pOut} -> Switch[method, "Complex", RandomComplex[{-1 - I, 1 + I}], _, RandomReal[{-1, 1}]],
                Nothing
            ],
            {i, leftDim}, {j, rightDim}, {pIn, physDim}, {pOut, physDim}
        ], 3];

        SparseArray[rules, {leftDim, rightDim, physDim, physDim}]
    ]

(* Generate symmetric MPO left boundary tensor (rank-3): qPhysIn = qRight + qPhysOut (mod nSectors) *)
generateSymmetricMPOLeftBoundary[bondDim_Integer, physDim_Integer, nSectors_Integer, opts___] :=
    Module[{chargesR, chargesP, rules, method},
        method = OptionValue[{opts, Options[RandomTensorNetwork]}, Method];
        chargesR = makeBondCharges[bondDim, nSectors];
        chargesP = makePhysicalCharges[physDim];

        rules = Flatten[Table[
            If[Mod[chargesP[[pIn]], nSectors] == Mod[chargesR[[j]] + chargesP[[pOut]], nSectors],
                {j, pIn, pOut} -> Switch[method, "Complex", RandomComplex[{-1 - I, 1 + I}], _, RandomReal[{-1, 1}]],
                Nothing
            ],
            {j, bondDim}, {pIn, physDim}, {pOut, physDim}
        ], 2];

        SparseArray[rules, {bondDim, physDim, physDim}]
    ]

(* Generate symmetric MPO right boundary tensor (rank-3): qLeft + qPhysIn = qPhysOut (mod nSectors) *)
generateSymmetricMPORightBoundary[bondDim_Integer, physDim_Integer, nSectors_Integer, opts___] :=
    Module[{chargesL, chargesP, rules, method},
        method = OptionValue[{opts, Options[RandomTensorNetwork]}, Method];
        chargesL = makeBondCharges[bondDim, nSectors];
        chargesP = makePhysicalCharges[physDim];

        rules = Flatten[Table[
            If[Mod[chargesL[[i]] + chargesP[[pIn]], nSectors] == Mod[chargesP[[pOut]], nSectors],
                {i, pIn, pOut} -> Switch[method, "Complex", RandomComplex[{-1 - I, 1 + I}], _, RandomReal[{-1, 1}]],
                Nothing
            ],
            {i, bondDim}, {pIn, physDim}, {pOut, physDim}
        ], 2];

        SparseArray[rules, {bondDim, physDim, physDim}]
    ]

(* Generate symmetric TT/TTN vector (boundary): only charge 0 elements *)
generateSymmetricBoundaryVector[bondDim_Integer, nSectors_Integer, opts___] :=
    Module[{charges, rules, method},
        method = OptionValue[{opts, Options[RandomTensorNetwork]}, Method];
        charges = makeBondCharges[bondDim, nSectors];

        rules = Table[
            If[charges[[i]] == 0,
                {i} -> Switch[method, "Complex", RandomComplex[{-1 - I, 1 + I}], _, RandomReal[{-1, 1}]],
                Nothing
            ],
            {i, bondDim}
        ];

        SparseArray[rules, {bondDim}]
    ]

(* Generate symmetric TT matrix (bulk): qLeft = qRight (mod nSectors) *)
generateSymmetricTTMatrix[bondDim_Integer, nSectors_Integer, opts___] :=
    Module[{charges, rules, method},
        method = OptionValue[{opts, Options[RandomTensorNetwork]}, Method];
        charges = makeBondCharges[bondDim, nSectors];

        rules = Flatten[Table[
            If[charges[[i]] == charges[[j]],
                {i, j} -> Switch[method, "Complex", RandomComplex[{-1 - I, 1 + I}], _, RandomReal[{-1, 1}]],
                Nothing
            ],
            {i, bondDim}, {j, bondDim}
        ], 1];

        SparseArray[rules, {bondDim, bondDim}]
    ]

(* Generate symmetric TTN leaf tensor (vector): charge = 0 at boundary *)
generateSymmetricTTNLeaf[bondDim_Integer, nSectors_Integer, opts___] :=
    Module[{charges, rules, method},
        method = OptionValue[{opts, Options[RandomTensorNetwork]}, Method];
        charges = makeBondCharges[bondDim, nSectors];

        (* Leaf has charge 0 outgoing *)
        rules = Table[
            If[charges[[i]] == 0,
                {i} -> Switch[method,
                    "Complex", RandomComplex[{-1 - I, 1 + I}],
                    _, RandomReal[{-1, 1}]
                ],
                Nothing
            ],
            {i, bondDim}
        ];

        SparseArray[rules, {bondDim}]
    ]

(* Generate symmetric TTN internal tensor: sum of child charges = parent charge (mod nSectors) *)
generateSymmetricTTNInternal[bondDim_Integer, branching_Integer, nSectors_Integer, hasParent_?BooleanQ, opts___] :=
    Module[{charges, dims, rules, method, rank},
        method = OptionValue[{opts, Options[RandomTensorNetwork]}, Method];
        charges = makeBondCharges[bondDim, nSectors];
        rank = If[hasParent, branching + 1, branching];
        dims = ConstantArray[bondDim, rank];

        (* Build sparse rules: sum of child charges = parent charge (or 0 if no parent) *)
        rules = Flatten[
            Table[
                With[{
                    idxList = Table[Subscript[i, k], {k, rank}],
                    childCharges = Table[charges[[Subscript[i, k]]], {k, branching}],
                    parentCharge = If[hasParent, charges[[Subscript[i, rank]]], 0]
                },
                    If[Mod[Total[childCharges], nSectors] == parentCharge,
                        idxList -> Switch[method,
                            "Complex", RandomComplex[{-1 - I, 1 + I}],
                            _, RandomReal[{-1, 1}]
                        ],
                        Nothing
                    ]
                ],
                Evaluate[Sequence @@ Table[{Subscript[i, k], bondDim}, {k, rank}]]
            ],
            rank - 1
        ];

        SparseArray[rules, dims]
    ]

(* ============================================ *)
(* MPS: Matrix Product State                   *)
(* ============================================ *)
RandomTensorNetwork["MPS"[length_Integer, bondDim_Integer, physicalDim_Integer : 2], opts : OptionsPattern[]] :=
    Block[{tensors, indices, boundary, periodic, physStart, symmetry, symType, nSectors, bondCharges, indexCharges, metadata},
        boundary = OptionValue[{opts, Options[RandomTensorNetwork]}, "Boundary"];
        symmetry = OptionValue[{opts, Options[RandomTensorNetwork]}, "Symmetry"];
        periodic = boundary === "Periodic";
        physStart = length + 1;  (* Physical indices start after bond indices *)

        (* Handle symmetry option *)
        If[symmetry =!= None,
            (* Extract symmetry type and number of sectors from {"U1", nSectors} *)
            symType = If[ListQ[symmetry], symmetry[[1]], "U1"];
            nSectors = If[ListQ[symmetry], symmetry[[2]], symmetry];
            bondCharges = makeBondCharges[bondDim, nSectors];

            If[periodic,
                (* Periodic symmetric MPS: all tensors are rank-3 *)
                tensors = Table[
                    generateSymmetricMPSTensor[bondDim, physicalDim, bondDim, nSectors, opts],
                    length
                ];
                indices = Table[{Mod[i - 1, length] + 1, Mod[i, length] + 1, physStart + i - 1}, {i, length}];
                (* All bond indices carry charges *)
                indexCharges = Association[Table[i -> bondCharges, {i, 1, length}]],

                (* Open symmetric MPS: boundaries are rank-2, bulk is rank-3 *)
                tensors = Join[
                    {generateSymmetricLeftBoundaryTensor[bondDim, physicalDim, nSectors, opts]},
                    Table[generateSymmetricMPSTensor[bondDim, physicalDim, bondDim, nSectors, opts], Max[0, length - 2]],
                    If[length > 1, {generateSymmetricRightBoundaryTensor[bondDim, physicalDim, nSectors, opts]}, {}]
                ];
                indices = Join[
                    {{1, physStart}},
                    Table[{i - 1, i, physStart + i - 1}, {i, 2, length - 1}],
                    If[length > 1, {{length - 1, physStart + length - 1}}, {}]
                ];
                (* Bond indices 1 through length-1 carry charges *)
                indexCharges = Association[Table[i -> bondCharges, {i, 1, length - 1}]]
            ];

            (* Build metadata and return TensorNetwork with metadata *)
            metadata = <|"IndexCharges" -> indexCharges, "SymmetryType" -> symType|>;
            TensorNetwork[tensors, indices, Automatic, metadata],

            (* Original dense implementation when no symmetry *)
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
    ]

(* ============================================ *)
(* TT: Tensor Train (no physical indices)      *)
(* ============================================ *)
RandomTensorNetwork["TT"[length_Integer, bondDim_Integer], opts : OptionsPattern[]] :=
    Block[{tensors, indices, boundary, periodic, symmetry, symType, nSectors, bondCharges, indexCharges, metadata},
        boundary = OptionValue[{opts, Options[RandomTensorNetwork]}, "Boundary"];
        symmetry = OptionValue[{opts, Options[RandomTensorNetwork]}, "Symmetry"];
        periodic = boundary === "Periodic";

        If[symmetry =!= None,
            (* Symmetric TT implementation *)
            symType = If[ListQ[symmetry], symmetry[[1]], "U1"];
            nSectors = If[ListQ[symmetry], symmetry[[2]], symmetry];
            bondCharges = makeBondCharges[bondDim, nSectors];

            If[periodic,
                (* Periodic symmetric TT: all tensors are rank-2 block-diagonal matrices *)
                tensors = Table[generateSymmetricTTMatrix[bondDim, nSectors, opts], length];
                indices = Table[{Mod[i - 1, length] + 1, Mod[i, length] + 1}, {i, length}];
                indexCharges = Association[Table[i -> bondCharges, {i, 1, length}]],

                (* Open symmetric TT: boundaries are sparse vectors, bulk is block-diagonal matrices *)
                tensors = Join[
                    {generateSymmetricBoundaryVector[bondDim, nSectors, opts]},
                    Table[generateSymmetricTTMatrix[bondDim, nSectors, opts], Max[0, length - 2]],
                    If[length > 1, {generateSymmetricBoundaryVector[bondDim, nSectors, opts]}, {}]
                ];
                indices = Join[
                    {{1}},
                    Table[{i - 1, i}, {i, 2, length - 1}],
                    If[length > 1, {{length - 1}}, {}]
                ];
                indexCharges = Association[Table[i -> bondCharges, {i, 1, length - 1}]]
            ];

            (* Build metadata and return TensorNetwork with metadata *)
            metadata = <|"IndexCharges" -> indexCharges, "SymmetryType" -> symType|>;
            TensorNetwork[tensors, indices, Automatic, metadata],

            (* Original dense implementation *)
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
    ]

(* ============================================ *)
(* MPO: Matrix Product Operator                *)
(* ============================================ *)
RandomTensorNetwork["MPO"[length_Integer, bondDim_Integer, physicalDim_Integer : 2], opts : OptionsPattern[]] :=
    Block[{tensors, indices, boundary, periodic, physInStart, physOutStart, symmetry, symType, nSectors, bondCharges, indexCharges, metadata},
        boundary = OptionValue[{opts, Options[RandomTensorNetwork]}, "Boundary"];
        symmetry = OptionValue[{opts, Options[RandomTensorNetwork]}, "Symmetry"];
        periodic = boundary === "Periodic";
        physInStart = length + 1;
        physOutStart = 2 length + 1;

        If[symmetry =!= None,
            (* Symmetric MPO implementation *)
            symType = If[ListQ[symmetry], symmetry[[1]], "U1"];
            nSectors = If[ListQ[symmetry], symmetry[[2]], symmetry];
            bondCharges = makeBondCharges[bondDim, nSectors];

            If[periodic,
                (* Periodic symmetric MPO: all tensors are rank-4 *)
                tensors = Table[generateSymmetricMPOTensor[bondDim, bondDim, physicalDim, nSectors, opts], length];
                indices = Table[{Mod[i - 1, length] + 1, Mod[i, length] + 1, physInStart + i - 1, physOutStart + i - 1}, {i, length}];
                indexCharges = Association[Table[i -> bondCharges, {i, 1, length}]],

                (* Open symmetric MPO: boundaries are rank-3, bulk is rank-4 *)
                tensors = Join[
                    {generateSymmetricMPOLeftBoundary[bondDim, physicalDim, nSectors, opts]},
                    Table[generateSymmetricMPOTensor[bondDim, bondDim, physicalDim, nSectors, opts], Max[0, length - 2]],
                    If[length > 1, {generateSymmetricMPORightBoundary[bondDim, physicalDim, nSectors, opts]}, {}]
                ];
                indices = Join[
                    {{1, physInStart, physOutStart}},
                    Table[{i - 1, i, physInStart + i - 1, physOutStart + i - 1}, {i, 2, length - 1}],
                    If[length > 1, {{length - 1, physInStart + length - 1, physOutStart + length - 1}}, {}]
                ];
                indexCharges = Association[Table[i -> bondCharges, {i, 1, length - 1}]]
            ];

            (* Build metadata and return TensorNetwork with metadata *)
            metadata = <|"IndexCharges" -> indexCharges, "SymmetryType" -> symType|>;
            TensorNetwork[tensors, indices, Automatic, metadata],

            (* Original dense implementation *)
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
    Block[{tensors = {}, indices = {}, idx = 1, leafCount, nodesAtLevel, symmetry, symType, nSectors, bondCharges, indexCharges, allBondIndices, metadata},
        symmetry = OptionValue[{opts, Options[RandomTensorNetwork]}, "Symmetry"];

        If[symmetry =!= None,
            (* Symmetric TTN implementation *)
            symType = If[ListQ[symmetry], symmetry[[1]], "U1"];
            nSectors = If[ListQ[symmetry], symmetry[[2]], symmetry];
            bondCharges = makeBondCharges[bondDim, nSectors];
            leafCount = branching^(depth - 1);
            allBondIndices = {};

            (* Leaves: vectors with charge 0 *)
            Do[
                AppendTo[tensors, generateSymmetricTTNLeaf[bondDim, nSectors, opts]];
                AppendTo[indices, {idx}];
                AppendTo[allBondIndices, idx];
                idx++,
                leafCount
            ];

            (* Internal nodes level by level *)
            Do[
                nodesAtLevel = branching^(depth - 1 - level);
                Do[
                    With[{
                        childIndices = Table[idx - nodesAtLevel * branching - branching + (node - 1) * branching + k, {k, branching}],
                        hasParent = level < depth - 1,
                        parentIdx = If[level < depth - 1, idx++, Nothing]
                    },
                        AppendTo[tensors, generateSymmetricTTNInternal[bondDim, branching, nSectors, hasParent, opts]];
                        AppendTo[indices, DeleteCases[Append[childIndices, parentIdx], Nothing]];
                        If[hasParent, AppendTo[allBondIndices, parentIdx - 1]];
                    ],
                    {node, nodesAtLevel}
                ],
                {level, 1, depth - 1}
            ];

            (* Build index charges for all bond indices *)
            indexCharges = Association[Table[i -> bondCharges, {i, allBondIndices}]];

            (* Build metadata and return TensorNetwork with metadata *)
            metadata = <|"IndexCharges" -> indexCharges, "SymmetryType" -> symType|>;
            TensorNetwork[tensors, indices, Automatic, metadata],

            (* Original dense implementation *)
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

TensorNetworkDelete[net_ ? TensorNetworkQ, index_Integer : -1] := With[{hyperedges = net["Hyperedges"]},
    TensorNetwork[
        Delete[net["Tensors"], index],
        Delete[hyperedges, index],
        Replace[net["Output"], Except[Automatic] :> DeleteElements[net["FreeIndices"], hyperedges[[index]]]]
    ]
]


(* Summary Box - NoEntry is handled by System`Private`HoldSetNoEntry *)
TensorNetwork /: MakeBoxes[tn_TensorNetwork /; TensorNetworkQ[tn], fmt_] := With[{
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
