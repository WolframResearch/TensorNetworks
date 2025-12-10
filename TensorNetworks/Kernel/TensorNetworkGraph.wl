Package["Wolfram`TensorNetworks`"]

PackageExport[TensorNetworkGraphQ]
PackageExport[TensorNetworkIndexGraph]
PackageExport[GraphTensorNetwork]
PackageExport[TensorNetworkIndices]
PackageExport[TensorNetworkTensors]
PackageExport[TensorNetworkGraphData]
PackageExport[TensorNetworkIndexDimensions]
PackageExport[TensorNetworkFreeIndices]
PackageExport[TensorNetworkAdd]
PackageExport[RemoveTensorNetworkCycles]
PackageExport[TensorNetworkNetGraph]
PackageExport[TensorNetworkIndexReplace]
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


TensorNetworkIndexDimensions[net_Graph ? TensorNetworkGraphQ] := TensorNetworkIndexDimensions @@ Lookup[TensorNetworkGraphData[net], {"Indices", "Tensors"}]

TensorNetworkIndexDimensions[indices_List, tensors_List] := Catenate @ MapThread[Thread[#1 -> TensorDimensions[#2]] &, {indices, tensors}]


TensorNetworkIndexReplace[net_ ? TensorNetworkGraphQ, rules_] :=
    Graph[net, AnnotationRules -> MapThread[#1 -> {"Index" -> #2} &, {VertexList[net], Replace[TensorNetworkIndices[net], rules, {2}]}]]


InitializeTensorNetwork[net_Graph ? TensorNetworkGraphQ, tensor_, index_List : Automatic] := Annotate[
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
        "Index" -> Replace[index, Automatic :> (Superscript[0, #] & /@ Range[tensorRank[tensor]])],
        VertexLabels -> "Initial"
    }
]

TensorNetworkAdd[net_Graph ? TensorNetworkGraphQ, Labeled[tensor_, label_ : None], autoIndex : _List | Automatic : Automatic] := Enclose @ With[{
    newVertex = Max[VertexList[net]] + 1,
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

VertexCompleteGraph[vs_List] := With[{n = Length[vs]}, AdjacencyGraph[vs, SparseArray[Band[{1, 1}] -> 0, {n, n}, 1]]]

TensorNetworkIndexGraph[net_Graph ? (TensorNetworkGraphQ[True]), opts : OptionsPattern[Graph]] := GraphUnion[
    DirectedEdge @@@ EdgeTags[net],
    Sequence @@ (VertexCompleteGraph /@ TensorNetworkIndices[net]),
    opts,
    VertexLabels -> Automatic
]


Options[GraphTensorNetwork] = Join[{Method -> "Symbolic"}, Options[Graph]]

GraphTensorNetwork[g_ /; DirectedGraphQ[g] && AcyclicGraphQ[g], opts : OptionsPattern[]] := Enclose @ Block[{
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

GraphTensorNetwork[g_ ? DirectedGraphQ, opts : OptionsPattern[]] :=
    Enclose @ GraphTensorNetwork[ConfirmBy[RemoveTensorNetworkCycles[g], AcyclicGraphQ], opts]

GraphTensorNetwork[g_ ? GraphQ, opts : OptionsPattern[]] := GraphTensorNetwork[DirectedGraph[g, "Acyclic"], opts]

(* Hyperedges act as indices - when more than 2 tensors share an index, 
   insert a spider tensor (reshaped identity) to convert to binary edges.
   All index variance (Superscript/Subscript) is determined by edge direction:
   source vertex gets Superscript (contravariant/output), target gets Subscript (covariant/input).
   Edge tags are pairs {srcIndex, tgtIndex}. *)
GraphTensorNetwork[tensors_List, hyperedges : {___List}, opts : OptionsPattern[]] := Block[{
    n = Length[tensors],
    dims, indexPositions, 
    spiderData = {}, (* list of {vertex, tensor, indices} *)
    undirectedEdges = {}, spiderId,
    allVertices, g0, directedEdges0,
    vertexIndices, (* association: vertex -> list of indices *)
    annotations, finalEdges
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
    KeyValueMap[Function[{idx, verts},
        Which[
            Length[verts] == 1, (* Free index -> edge to boundary 0 *)
                AppendTo[undirectedEdges, UndirectedEdge[verts[[1]], 0, idx]],
            Length[verts] == 2, (* Binary -> direct edge *)
                AppendTo[undirectedEdges, UndirectedEdge[verts[[1]], verts[[2]], idx]],
            True, (* Hyperedge -> spider *)
                spiderId++;
                With[{d = Lookup[dims, idx, 2], k = Length[verts]},
                    AppendTo[spiderData, {spiderId, SymbolicIdentityArray[ConstantArray[d, k]], ConstantArray[idx, k]}]
                ];
                Scan[AppendTo[undirectedEdges, UndirectedEdge[#, spiderId, idx]] &, verts]
        ]
    ], indexPositions];

    allVertices = Join[{0}, Range[n], If[spiderData === {}, {}, spiderData[[All, 1]]]];

    (* Make acyclic to determine directions *)
    g0 = DirectedGraph[Graph[allVertices, undirectedEdges], "Acyclic"];
    directedEdges0 = EdgeList[g0];

    (* Build vertex indices based on edge directions *)
    vertexIndices = <||>;

    (* Tensor vertices *)
    Do[
        vertexIndices[v] = MapIndexed[With[{idx = #1, slot = First[#2]},
            If[MemberQ[directedEdges0, DirectedEdge[v, _, idx]],
                Superscript[v, slot], (* source -> output *)
                Subscript[v, slot]    (* target -> input *)
            ]
        ] &, hyperedges[[v]]],
        {v, Range[n]}
    ];

    (* Spider vertices *)
    Do[With[{v = sp[[1]], spIdx = sp[[3]]},
        vertexIndices[v] = MapIndexed[With[{idx = #1, slot = First[#2]},
            If[MemberQ[directedEdges0, DirectedEdge[v, _, idx]],
                Superscript[v, slot],
                Subscript[v, slot]
            ]
        ] &, spIdx]
    ], {sp, spiderData}];
    
    (* Build annotations *)
    annotations = Join[
        Table[v -> {"Tensor" -> tensors[[v]], "Index" -> vertexIndices[v], VertexLabels -> v}, {v, Range[n]}],
        Table[sp[[1]] -> {"Tensor" -> sp[[2]], "Index" -> vertexIndices[sp[[1]]], VertexLabels -> "Spider"}, {sp, spiderData}]
    ];
    
    (* Build final edges with {srcIndex, tgtIndex} tags *)
    finalEdges = Table[
        With[{src = e[[1]], tgt = e[[2]], origIdx = e[[3]]},
            If[src === 0 || tgt === 0, Nothing, (* skip boundary edges *)
                With[{
                    srcSlot = FirstPosition[If[src <= n, hyperedges[[src]], spiderData[[src - n, 3]]], origIdx][[1]],
                    tgtSlot = FirstPosition[If[tgt <= n, hyperedges[[tgt]], spiderData[[tgt - n, 3]]], origIdx][[1]]
                },
                    DirectedEdge[src, tgt, {vertexIndices[src][[srcSlot]], vertexIndices[tgt][[tgtSlot]]}]
                ]
            ]
        ],
        {e, directedEdges0}
    ];
    
    Graph[
        DeleteCases[allVertices, 0],
        finalEdges,
        AnnotationRules -> annotations,
        opts
    ]
]

RemoveTensorNetworkCycles[inputNet_ ? DirectedGraphQ, opts : OptionsPattern[Graph]] := Enclose @ Block[{
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

		net = Annotate[{net, cup}, {"Tensor" -> Flatten[IdentityMatrix[dim]], VertexLabels -> "Cup"}];
		net = Annotate[{net, cap}, {"Tensor" -> Flatten[IdentityMatrix[dim]], VertexLabels -> "Cap"}];
	];
	Graph[net, opts]
]





TensorNetworkNetGraph[net_ ? TensorNetworkGraphQ] := TensorNetworkNetGraph[net, TensorNetworkContractionPath[net]]

TensorNetworkNetGraph[net_ ? TensorNetworkGraphQ, path_] := Enclose @ Block[{tensors, indices, freeIndices, g, tensorQueue, addEinsumLayer, n},
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

