Package["Wolfram`TensorNetworks`"]

PackageExport[TensorNetworkGraphQ]
PackageExport[TensorNetworkIndexGraph]
PackageExport[ToTensorNetworkGraph]
PackageExport[TensorNetworkIndices]
PackageExport[TensorNetworkTensors]
PackageExport[TensorNetworkGraphData]
PackageExport[TensorNetworkIndexDimensions]
PackageExport[TensorNetworkFreeIndices]
PackageExport[TensorNetworkAdd]
PackageExport[TensorNetworkDelete]
PackageExport[TensorNetworkRemoveCycles]
PackageExport[TensorNetworkToNetGraph]
PackageExport[TensorNetworkReplaceIndices]
PackageExport[InitializeTensorNetwork]



TensorNetworkGraphQ::msg1 = "Not all vertices are annotated with tensors."
TensorNetworkGraphQ::msg2 = "Not all indices are duplicate free lists of Subscripts and Superscripts."
TensorNetworkGraphQ::msg3 = "Tensor ranks and indices are not compatible."
TensorNetworkGraphQ::msg4 = "Not all edges are tagged with indices."

TensorNetworkGraphQ[net_Graph, verbose : _ ? BooleanQ : False] := Block[{
    tensors, indices
},
    {tensors, indices} = AssociationThread[VertexList[net] -> #] & /@
        (AnnotationValue[{net, Developer`FromPackedArray[VertexList[net]]}, #] & /@ {"Tensor", "Index"});
    (
        AllTrue[indices, MatchQ[#, {(Superscript | Subscript)[_, _] ...}] && DuplicateFreeQ[#] &] ||
        (If[verbose, Message[TensorNetworkGraphQ::msg2]]; False)
     ) &&
    With[{ranks = tensorRank /@ Values[tensors]},
        (And @@ Thread[ranks == Length /@ Values[indices]] && Total[ranks] == CountDistinct[Catenate[Values[indices]]]) ||
        Total[ranks] == 0 ||
        (If[verbose, Message[TensorNetworkGraphQ::msg3]]; False)
    ]
]

TensorNetworkGraphQ[verbose : _ ? BooleanQ : False][net_Graph] := TensorNetworkGraphQ[net, verbose]



TensorNetworkIndices[net_Graph ? TensorNetworkGraphQ] := AnnotationValue[{net, Developer`FromPackedArray[VertexList[net]]}, "Index"]

TensorNetworkTensors[net_Graph ? TensorNetworkGraphQ] := AnnotationValue[{net, Developer`FromPackedArray[VertexList[net]]}, "Tensor"]


TensorNetworkGraphData[net_Graph ? TensorNetworkGraphQ] := With[{
    vs = Developer`FromPackedArray[VertexList[net]]
}, {
    tensors = AnnotationValue[{net, vs}, "Tensor"],
    indices = AnnotationValue[{net, vs}, "Index"],
    edges = EdgeList[net]
}, {
    dimensions = TensorNetworkIndexDimensions[indices, tensors],
    tags = edges[[All, 3]]
}, {
    contractions = Replace[indices, Catenate[Thread[# -> #, List, 1] & /@ tags], {2}]
},
    <|
        "Tensors" -> tensors,
        "Dimensions" -> tensorDimensions /@ tensors,
        "Indices" -> indices,
        "Vertices" -> vs,
        "FreeIndices" -> TensorNetworkFreeIndices[indices, tags],
        "Bonds" -> Thread[edges[[All, 3]] -> Lookup[dimensions, edges[[All, 3, 1]]]],
        "Contractions" -> contractions,
        "ContractionIndices" -> Replace[contractions, {i_, _} :> i, {2}]
    |>
]


TensorNetworkFreeIndices[net_Graph ? TensorNetworkGraphQ] :=
    TensorNetworkFreeIndices[TensorNetworkIndices[net], EdgeTags[net]]

TensorNetworkFreeIndices[indices_List, tags_List] :=
    SortBy[Replace[{Superscript[_, x_] :> {0, x}, Subscript[_, x_] :> {1, x}}]] @ DeleteElements[Catenate[indices], Catenate[tags]]

TensorNetworkFreeIndices[indices_List] := Keys @ Select[Counts[Catenate[indices]], # == 1 &]


TensorNetworkIndexDimensions[net_Graph ? TensorNetworkGraphQ] := TensorNetworkIndexDimensions[TensorNetworkGraphData[net]]

TensorNetworkIndexDimensions[KeyValuePattern[{"Indices" -> indices_, "Dimensions" -> dimensions_}]] :=
    Catenate @ MapThread[Thread[#1 -> #2] &, {indices, dimensions}]

TensorNetworkIndexDimensions[indices_List, tensors_List] :=
    TensorNetworkIndexDimensions[<|"Indices" -> indices, "Dimensions" -> tensorDimensions /@ tensors|>]


TensorNetworkReplaceIndices[net_ ? TensorNetworkGraphQ, rules_] := With[{
    vs = VertexList[net],
    newIndices = Replace[TensorNetworkIndices[net], rules, {2}],
    newEdges = Replace[EdgeList[net], e : DirectedEdge[_, _, _] :> MapAt[Replace[#, rules, {1}] &, e, 3], {1}]
},
    Graph[
        vs,
        newEdges,
        AnnotationRules -> MapThread[#1 -> {"Index" -> #2} &, {vs, newIndices}]
    ]
]


InitializeTensorNetwork::nostub = "Graph has no non-positive (boundary stub) vertex to replace. Construct an initial graph with at least one vertex labeled by a non-positive integer before calling InitializeTensorNetwork.";
InitializeTensorNetwork::rank = "Tensor rank `1` does not match the length of the index list `2`.";

InitializeTensorNetwork[net_Graph ? TensorNetworkGraphQ, tensor_, index : _List | Automatic : Automatic] :=
    Module[{resolvedIndex, rank},
        If[!MemberQ[VertexList[net], _ ? NonPositive],
            Message[InitializeTensorNetwork::nostub];
            Return[$Failed]
        ];
        rank = tensorRank[tensor];
        resolvedIndex = Replace[index, Automatic :> (Superscript[0, #] & /@ Range[rank])];
        If[Length[resolvedIndex] =!= rank,
            Message[InitializeTensorNetwork::rank, rank, Length[resolvedIndex]];
            Return[$Failed]
        ];
        Annotate[
            {
                EdgeAdd[
                    VertexDelete[net, _ ? NonPositive],
                    MapIndexed[
                        Replace[#1, DirectedEdge[_, i_, {_, to_}] :> DirectedEdge[0, i, {Superscript[0, #2[[1]]], to}]] &,
                        EdgeList[net, DirectedEdge[_ ? NonPositive, __]]
                    ]
                ],
                0
            },
            {
                "Tensor" -> tensor,
                "Index" -> resolvedIndex,
                VertexLabels -> "Initial"
            }
        ]
    ]

TensorNetworkAdd[net_Graph ? TensorNetworkGraphQ, Labeled[tensor_, label_ : None], autoIndex : _List | Automatic : Automatic] := Enclose @ With[{
    newVertex = Max[VertexList[net, _Integer], 0] + 1,
    toIndex = Replace[autoIndex, Automatic :> Take[SortBy[TensorNetworkFreeIndices[net], Replace[{Superscript[_, x_] :> {1, x}, Subscript[_, x_] :> {0, x}}]], UpTo[tensorRank[tensor]]]]
},
{
    index = Join[
        Replace[toIndex, {Superscript[_, q_] :> Subscript[newVertex, q], Subscript[_, q_] :> Superscript[newVertex, q]}, {1}],
        Subscript[newVertex, #] & /@ Range[tensorRank[tensor] - Length[toIndex]]
    ]
},
    ConfirmAssert[tensorRank[tensor] == Length[index]];
    Annotate[
        {
            EdgeAdd[
                net,
                MapThread[
                    If[MatchQ[#1, _Superscript], DirectedEdge[newVertex, First[#2], {#1, #2}], DirectedEdge[First[#2], newVertex, {#2, #1}]] &,
                    {Take[index, UpTo[Length[toIndex]]], toIndex}
                ]
            ],
            newVertex
        },
        {
            "Tensor" -> tensor,
            "Index" -> index,
            VertexLabels -> label
        }
    ]
]

TensorNetworkAdd[net_Graph ? TensorNetworkGraphQ, tensor_, index : _List | Automatic : Automatic] := TensorNetworkAdd[net, Labeled[tensor, None], index]

(* Helper function to avoid documentation introspection issues *)
tensorNetworkDeleteGraphImpl[net_, index_] := With[{
    vs = VertexList[net]
},
    VertexDelete[net, vs[[index]]]
]

TensorNetworkDelete[net_Graph ? TensorNetworkGraphQ, index_Integer : -1] := tensorNetworkDeleteGraphImpl[net, index]

VertexCompleteGraph[vs_List] := With[{n = Length[vs]}, AdjacencyGraph[vs, SparseArray[Band[{1, 1}] -> 0, {n, n}, 1]]]

TensorNetworkIndexGraph[net_Graph ? (TensorNetworkGraphQ[True]), opts : OptionsPattern[Graph]] := GraphUnion[
    DirectedEdge @@@ EdgeTags[net],
    Sequence @@ (VertexCompleteGraph /@ TensorNetworkIndices[net]),
    opts,
    VertexLabels -> Automatic
]


Options[ToTensorNetworkGraph] = Join[{Method -> "Symbolic"}, Options[Graph]]

ToTensorNetworkGraph[g_ /; DirectedGraphQ[g] && AcyclicGraphQ[g], opts : OptionsPattern[]] := Enclose @ Block[{
	vs = Developer`FromPackedArray[TopologicalSort[g]], edges = EdgeList[g],
	labels,
	inputs, outputs, inputOrder, outputOrder,
    orders, output,
	indices, outOrders, inOrders
},
	orders = <||>;
	output = {};
	Do[
		inputs = VertexInComponent[g, v, {1}];
		outputs = VertexOutComponent[g, v, {1}];
		inputOrder = Lookup[First /@ PositionIndex[output], inputs, Nothing];
		inputOrder = Take[Join[inputOrder, Length[output] + Range[Length[inputs] - Length[inputOrder]]], UpTo[Length[inputs]]];
		If[ Length[outputs] <= Length[inputs],
			outputOrder = Take[inputOrder, Length[outputs]],
			outputOrder = Take[Join[inputOrder, Lookup[PositionIndex[output], None, {}], Length[output] + Range[Length[outputs]]], Length[outputs]]
		];
		output = PadRight[output, Max[Length[output], outputOrder], None];
		output[[Complement[inputOrder, outputOrder]]] = None;
		Scan[(output[[#]] = v) &, outputOrder];
		orders[v] = {outputOrder, inputOrder};
		,
		{v, vs}
	];
	indices = AssociationThread[vs, AnnotationValue[{g, vs}, "Index"]];
	outOrders = KeyValueMap[{v, i} |->
		Replace[i, {
			$Failed :> orders[v][[1]],
			is_List :> Cases[is, Superscript[_, o_] :> o]
		}],
		indices
	];
	inOrders = KeyValueMap[{v, i} |->
		Replace[i, {
			$Failed :> orders[v][[2]],
			is_List :> Cases[is, Subscript[_, o_] :> o]
		}],
		indices
	];
    indices = Association @ MapThread[
        {v, idx, in, out} |-> v -> Replace[idx, $Failed :> Join[Superscript[v, #] & /@ Sort[out], Subscript[v, #] & /@ Sort[in]]],
        {vs, Values[indices], inOrders, outOrders}
    ];
	labels = KeyValueMap[
        Replace[#2, {$Failed | Automatic :> #1, Interpretation[_, label_] :> label}] &,
        AssociationThread[vs, AnnotationValue[{g, vs}, VertexLabels]]
    ];
    Block[{in = Cases[_Subscript] /@ indices, out = Cases[_Superscript] /@ indices, outIdx, inIdx},
        edges = Table[
            {outIdx, inIdx} = FirstCase[#, {_[_, x_], _[_, x_]}, First[#]] & @ Tuples[{Lookup[out, edge[[1]]], Lookup[in, edge[[2]]]}];
            out[edge[[1]]] //= DeleteCases[outIdx];
            in[edge[[2]]] //= DeleteCases[inIdx];
            Append[edge[[;; 2]], {outIdx, inIdx}]
            ,
            {edge, Catenate @ Lookup[GroupBy[edges, First], vs, {}]}   
        ]
    ];
	Graph[
        vs, edges,
        AnnotationRules -> MapThread[
            {v, t, i} |-> With[{label = labels[[i]], index = indices[[i]]},
                v -> {
                    VertexLabels -> label,
                    "Tensor" -> Replace[t, {
                        $Failed :> With[{rank = Length[index]}, Switch[
                            OptionValue[Method],
                            "Zero", ConstantArray[0, ConstantArray[2, rank]],
                            "Symbolic", ArraySymbol[label, ConstantArray[2, rank]],
                            "Random", RandomReal[{-1, 1}, ConstantArray[2, rank]],
                            "RandomComplex", RandomComplex[{-1 - I, 1 + I}, ConstantArray[2, rank]]
                        ]]
                    }],
                    "Index" -> index
                }
            ],
            {vs, AnnotationValue[{g, vs}, "Tensor"], Range[Length[vs]]}
        ],
        FilterRules[{opts}, Options[Graph]],
        Options[g]
    ]
]

ToTensorNetworkGraph[g_ ? DirectedGraphQ, opts : OptionsPattern[]] :=
    Enclose @ ToTensorNetworkGraph[ConfirmBy[TensorNetworkRemoveCycles[g], AcyclicGraphQ], opts]

ToTensorNetworkGraph[g_ ? GraphQ, opts : OptionsPattern[]] := ToTensorNetworkGraph[DirectedGraph[g, "Acyclic"], opts]

(* Hyperedges act as indices - when more than 2 tensors share an index, 
   insert a spider tensor (reshaped identity) to convert to binary edges.
   All index variance (Superscript/Subscript) is determined by edge direction:
   source vertex gets Superscript (contravariant/output), target gets Subscript (covariant/input).
   Edge tags are pairs {srcIndex, tgtIndex}. *)
ToTensorNetworkGraph[tensors_List, hyperedges : {___List}, opts : OptionsPattern[]] := Block[{
    n = Length[tensors],
    dims, indexPositions, 
    spiders = {}, spiderId,
    undirectedEdges = {},
    allVertices, directedEdges,
    vertexIndices,
    annotations, edgeMap
},
    (* Build dimension lookup *)
    dims = Association @ Catenate @ MapThread[
        Thread[#1 -> tensorDimensions[#2]] &, {hyperedges, tensors}
    ];

    (* Group vertices by shared index *)
    indexPositions = GroupBy[
        Catenate @ MapIndexed[Thread[{First[#2], #1}] &, hyperedges],
        Last -> First
    ];

    spiderId = n;

    (* Build undirected edges *)
    KeyValueMap[{idx, verts} |->
        Which[
            Length[verts] == 1, (* Free index -> edge to boundary 0 *)
                AppendTo[undirectedEdges, UndirectedEdge[verts[[1]], 0, idx]],
            Length[verts] == 2, (* Binary -> direct edge *)
                AppendTo[undirectedEdges, UndirectedEdge[verts[[1]], verts[[2]], idx]],
            True, (* Hyperedge -> spider *)
                spiderId++;
                With[{d = Lookup[dims, idx, 2], k = Length[verts]},
                    AppendTo[spiders, {spiderId, SymbolicDeltaProductArray[ConstantArray[d, k], {Range[k]}]}];
                    Scan[AppendTo[undirectedEdges, UndirectedEdge[#, spiderId, idx]] &, verts]
                ]
        ]
        ,
        indexPositions
    ];

    allVertices = Join[Range[n], spiders[[All, 1]]];

    (* Make acyclic to determine directions *)
    directedEdges = EdgeList[DirectedGraph[undirectedEdges, "Acyclic"]];

    (* Build vertex indices based on edge directions *)
    vertexIndices = <||>;

    (* Tensor vertices *)
    Do[
        vertexIndices[v] = MapIndexed[
            With[{idx = #1, i = First[#2]},
                FirstCase[directedEdges,
                    edge : DirectedEdge[v, _, idx] :> edge -> Superscript[v, i],
                    FirstCase[directedEdges, edge : DirectedEdge[_, v, idx] :> edge -> Subscript[v, i]]
                ]
            ] &,
            hyperedges[[v]]
        ],
        {v, Range[n]}
    ];

    (* Spider vertices *)
    Do[
        Block[{i = 1},
            vertexIndices[s] = Replace[
                directedEdges,
                {
                    edge : DirectedEdge[s, _, _] :> edge -> Superscript[s, i++],
                    edge : DirectedEdge[_, s, _] :> edge -> Subscript[s, i++],
                    _ -> Nothing
                },
                1
            ]
        ],
        {s, spiders[[All, 1]]}
    ];
    
    (* Build annotations *)
    annotations = Join[
        Table[v -> {"Tensor" -> tensors[[v]], "Index" -> Values @ vertexIndices[v], VertexLabels -> v}, {v, Range[n]}],
        Table[sp[[1]] -> {"Tensor" -> sp[[2]], "Index" -> Values @ vertexIndices[sp[[1]]], VertexLabels -> "Spider"}, {sp, spiders}]
    ];

    edgeMap = GroupBy[Catenate @ Values @ vertexIndices, First -> Last, SortBy[MatchQ[_Subscript]]];

    (* Build final edges with {srcIndex, tgtIndex} tags *)
    directedEdges = Map[
        ReplacePart[#, 3 -> Lookup[edgeMap, #]] &,
        DeleteCases[directedEdges, DirectedEdge[0, __] | DirectedEdge[_, 0, _]]
    ];
    
    Graph[
        allVertices,
        directedEdges,
        AnnotationRules -> annotations,
        opts
    ]
]

TensorNetworkRemoveCycles[inputNet_ ? DirectedGraphQ, opts : OptionsPattern[Graph]] := Enclose @ Block[{
    net = IndexGraph[inputNet], cycles, id, q, r, edge, tag, cup, cap, cupIndex, capIndex, dim
},
	id = Max[VertexList[net], 0] + 1;
	{q, r} = MinMax[EdgeTags[net][[All, All, 2]]];
    q = Min[q, 1];
    r = Max[r, 1];


	While[
        Length[cycles = FindCycle[net, Infinity, 1]] > 0,

        q--;
		edge = cycles[[1, -1]];
        tag = If[Length[edge] == 3 && MatchQ[edge[[3]], {Superscript[_Integer, _Integer], Subscript[_Integer, _Integer]}],
            edge[[3]],
            None
        ];
		cup = id++;
		cap = id++;
		net = EdgeDelete[net, edge];
		net = VertexAdd[net, {cap, cup}];
        If[ tag =!= None,

            cupIndex = {Superscript[cup, q], Superscript[cup, tag[[2, 2]]]};
            capIndex = {Subscript[cap, q], Subscript[cap, tag[[1, 2]]]};
            net = EdgeAdd[net, {
                DirectedEdge[cup, cap, {cupIndex[[1]], capIndex[[1]]}],
                DirectedEdge[cup, edge[[2]], {cupIndex[[2]], tag[[2]]}],
                DirectedEdge[edge[[1]], cap, {tag[[1]], capIndex[[2]]}]
            }];
            dim = Enclose[
                ConfirmBy[
                    Dimensions[Confirm[AnnotationValue[{net, edge[[1]]}, "Tensor"]]][[ Confirm @ Lookup[PositionIndex[AnnotationValue[{net, edge[[1]]}, "Index"]], tag[[1]], $Failed, First] ]],
                    IntegerQ
                ],
                2 &
            ];
            net = Annotate[{net, cup}, "Index" -> cupIndex];
		    net = Annotate[{net, cap}, "Index" -> capIndex];

            ,

            net = EdgeAdd[net, {
                DirectedEdge[cup, cap],
                DirectedEdge[cup, edge[[2]]],
                DirectedEdge[edge[[1]], cap]
            }];
            dim = Enclose[First[Dimensions[Confirm[AnnotationValue[{net, edge[[1]]}, "Tensor"]]], 1], 2 &]
        ];

		net = Annotate[{net, cup}, {"Tensor" -> IdentityMatrix[dim], VertexLabels -> "Cup"}];
		net = Annotate[{net, cap}, {"Tensor" -> IdentityMatrix[dim], VertexLabels -> "Cap"}];
	];
	Graph[net, opts]
]





TensorNetworkToNetGraph[net_ ? TensorNetworkGraphQ] := TensorNetworkToNetGraph[net, OptimalContractionPath[net]]

TensorNetworkToNetGraph[net_ ? TensorNetworkGraphQ, path_] := Enclose @ Block[{tensors, indices, freeIndices, g, tensorQueue, addEinsumLayer, n},
    tensors = Chop @* FullSimplify @* N @* Normal /@ TensorNetworkTensors[net];
    indices = TensorNetworkIndices[net];
    freeIndices = TensorNetworkFreeIndices[net];
    indices = Replace[indices, Rule @@@ EdgeTags[net], {2}];
    n = Length[tensors];
    g = NetGraph[
        Block[{body, symbols},
            symbols = Union @@ Reap[body = Replace[#, s_Symbol /; ! NumericQ[s] :> Slot @@ {Sow[ToString[s]]}, Infinity]][[2]];
            If[ symbols === {},
                Confirm @ NetArrayLayer["Array" -> NumericArray[#]],
                Confirm @ FunctionLayer[Function[Evaluate[body]], Sequence @@ (# -> {} & /@ symbols)]
            ]
        ] & /@ tensors,
        # -> NetPort["T" <> ToString[#]] & /@ Range[n]
    ];
    tensorQueue = "T" <> ToString[#] & /@ Range[n];
    addEinsumLayer[{i_, j_} -> k_, a_, b_] :=
		With[{
			c = Complement[Join[i, j], k],
			adim = Flatten[{NetExtract[g, a]}],
			bdim = Flatten[{NetExtract[g, b]}]
	    },
		With[{
			ac = Catenate @ Lookup[PositionIndex[i], c],
			bc = Catenate @ Lookup[PositionIndex[j], c]
		},
		With[{
			al = Complement[Range[Length[i]], ac],
			br = Complement[Range[Length[j]], bc],
			ad = Times @@ adim[[ac]],
			bd = Times @@ bdim[[bc]]
		},
		With[{
			reshapea = {Times @@ adim / ad, ad},
			reshapeb = {bd, Times @@ bdim / bd},
			perma = PermutationList @ FindPermutation[Join[al, ac]],
			permb = PermutationList @ FindPermutation[Join[bc, br]],
			reshape = Join[adim[[al]], bdim[[br]]],
			perm = PermutationList @ FindPermutation[Join[i[[al]], j[[br]]], k]
		},
		n++;
		g = Confirm @ NetGraph[
			{
				g,
				Confirm @ NetGraph[<|
                    (*ToString[n] -> FunctionLayer[Apply[
                        Transpose[
                            ArrayReshape[
                                ArrayReshape[Transpose[#1, perma], reshapea] . ArrayReshape[Transpose[#2, permb], reshapeb],
                                reshape
                            ],
                            perm
                        ] &
                    ]]*)
					"a" -> NetChain[{If[perma === {}, Nothing, TransposeLayer[perma]], ReshapeLayer[reshapea]}],
					"b" -> NetChain[{If[permb === {}, Nothing, TransposeLayer[permb]], ReshapeLayer[reshapeb]}],
					"dot" -> DotLayer[],
					"post" -> NetChain[{ReshapeLayer[reshape], If[perm === {}, Nothing, TransposeLayer[perm]]}]
				|>, {NetPort[a] -> "a", NetPort[b] -> "b", {"a", "b"} -> "dot" -> "post" -> NetPort["T" <> ToString[n]]}]
			},
			{NetPort[{1, a}] -> NetPort[{2, a}], NetPort[{1, b}] -> NetPort[{2, b}]}
		];
	]]]];
    Do[
		Replace[p, {
			{i_} :> (
				{tensorQueue, indices} = Append[Delete[#, {i}], #[[i]]] & /@ {tensorQueue, indices}
			),
			{i_, j_} :> With[{out = SymmetricDifference @@ Extract[indices, {{i}, {j}}]},
				addEinsumLayer[indices[[{i, j}]] -> out, tensorQueue[[i]], tensorQueue[[j]]];
				tensorQueue = Append[Delete[tensorQueue, {{i}, {j}}], "T" <> ToString[n]];
				indices = Append[Delete[indices, {{i}, {j}}], out];
			]
		}],
		{p, path}
	];
	ConfirmAssert[Length[tensorQueue] == Length[indices] == 1];
	ConfirmAssert[ContainsAll[indices[[1]], freeIndices]];
	With[{perm = PermutationList @ FindPermutation[indices[[1]], freeIndices]},
		If[perm === {}, g, NetAppend[g, TransposeLayer[perm]]]
	]
]

