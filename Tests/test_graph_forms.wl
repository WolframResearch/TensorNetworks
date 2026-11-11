(* Tests/test_graph_forms.wl

   Graph forms of a tensor network, checked by value against explicit index
   sums written here.

   A tensor-network graph stores, on every vertex, a "Tensor" and an
   "Index" list naming its legs (Superscript[v, k] for an outgoing slot k,
   Subscript[v, k] for an incoming one); every edge carries a tag
   {srcLeg, tgtLeg} that joins one leg of its source to one leg of its
   target. Legs on no edge are free. The value of such a graph is computed
   here by renaming each tag's target leg to its source leg and summing the
   product of entries over every assignment of the shared names
   (gfListOracle), the same brute-force sum used for list-form networks
   TensorNetwork[tensors, labels, out]. Neither sum calls the paclet.

   Tensors are random Gaussian integers (a + b I) with unequal dimensions 2
   to 4, so every comparison is exact. Networks with hyperedges are only
   contracted by the brute-force sums or by TensorNetworkContract with the
   Automatic (greedy) plan; nothing here reaches the Netcon engine.

   A.  ToTensorNetworkGraph on list-form networks with hyperedges: the
       graph is well formed and binary (each leg on at most one edge), has
       one spider per hyperedge, keeps the original tensors, and has the
       value of the list form. TensorNetworkContract of the graph and the
       round trip TensorNetwork[graph] agree with the list-form sum.
   B.  BinaryTensorNetwork: every label on at most two slots, the output
       forwarded, the original tensors kept, one spider per hyperedge (with
       an extra leg when the label is an output), and the same value, for
       explicit outputs that include hyperedge labels and for Automatic
       output; binary input comes back unchanged.
   C.  TensorNetworkRemoveCycles on hand-built cyclic graphs (directed
       rings, a double edge, the complete digraph on three vertices, a
       figure eight, two disjoint cycles): the result is acyclic, well
       formed, two vertices larger per broken cycle, keeps every original
       tensor, has the same free legs and the same value.
       ToTensorNetworkGraph on a cyclic annotated graph has the same value.

   C7 and C8 are cases of bugs that were found and fixed. C7: with vertices
   not named 1..n, TensorNetworkRemoveCycles renumbered them but kept the
   leg names, so a new cap leg Subscript[5, 1] could collide with leg
   Subscript[5, 1] of vertex 5. C8: on an annotated graph,
   ToTensorNetworkGraph rebuilt every edge tag, pairing legs by slot number,
   so two crossed edges 1 -> 2 turned Tr[A . B] into Sum A[i, j] B[i, j].
   C9 breaks a ring whose vertices are named by strings.
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];


(* ============================================ *)
(* Independent references                       *)
(* ============================================ *)

(* Brute force: for every assignment of the label values, add the product
   of entries to the output entry named by the out labels. A label repeated
   on one tensor is a trace. *)
gfListOracle[tensors_List, labels_List, out_List] :=
    Module[{all = Union @@ labels, dims, acc = <||>},
        dims = Association @ Catenate @ MapThread[Thread[#1 -> Dimensions[#2]] &, {labels, tensors}];
        Scan[
            Function[assignment, With[{value = AssociationThread[all, assignment]},
                With[{
                    key = Lookup[value, out],
                    term = Times @@ MapThread[If[#2 === {}, #1, Extract[#1, Lookup[value, #2]]] &, {tensors, labels}]
                },
                    acc[key] = Lookup[acc, Key[key], 0] + term
                ]
            ]],
            Tuples[Range /@ Lookup[dims, all]]
        ];
        If[out === {}, Lookup[acc, Key[{}], 0], Array[Lookup[acc, Key[{##}], 0] &, Lookup[dims, out]]]
    ]

(* Labels appearing on exactly one slot, in order of first appearance. *)
gfFreeLabels[labels_List] := Keys @ Select[Counts[Catenate[labels]], # == 1 &]

gfVertexTensors[g_Graph] := Normal[AnnotationValue[{g, #}, "Tensor"]] & /@ VertexList[g]
gfVertexIndices[g_Graph] := AnnotationValue[{g, #}, "Index"] & /@ VertexList[g]
gfTags[g_Graph] := EdgeList[g][[All, 3]]

(* A graph is well formed when its leg names are distinct across all
   vertices, every vertex has one leg per tensor slot, every edge tag joins
   a leg of the edge's source to a leg of its target, no leg is on two
   edges, and joined legs have equal dimensions. *)
gfWellFormedQ[g_Graph] :=
    With[{
        tensors = gfVertexTensors[g],
        indices = gfVertexIndices[g],
        legs = Catenate[gfVertexIndices[g]],
        edges = EdgeList[g]
    },
        And[
            AllTrue[indices, ListQ],
            DuplicateFreeQ[legs],
            ArrayDepth /@ tensors === Length /@ indices,
            AllTrue[edges, MatchQ[#, DirectedEdge[_, _, {_, _}]] &],
            DuplicateFreeQ[Catenate[gfTags[g]]],
            AllTrue[edges,
                MemberQ[AnnotationValue[{g, #[[1]]}, "Index"], #[[3, 1]]] &&
                    MemberQ[AnnotationValue[{g, #[[2]]}, "Index"], #[[3, 2]]] &
            ],
            With[{dims = Association @ Catenate @ MapThread[Thread[#1 -> Dimensions[#2]] &, {indices, tensors}]},
                AllTrue[gfTags[g], dims[#[[1]]] === dims[#[[2]]] &]
            ]
        ]
    ]

(* Free legs of a graph: legs on no edge. *)
gfFreeLegs[g_Graph] := DeleteElements[Catenate[gfVertexIndices[g]], Catenate[gfTags[g]]]

(* Value of a graph with the free legs in the given order. *)
gfGraphValue[g_Graph, freeLegs_List] :=
    gfListOracle[
        gfVertexTensors[g],
        Replace[gfVertexIndices[g], Rule @@@ Reverse /@ gfTags[g], {2}],
        freeLegs
    ]

gfRandomArray[dims_List, seed_Integer] :=
    BlockRandom[SeedRandom[seed]; RandomInteger[{-3, 3}, dims] + I RandomInteger[{-3, 3}, dims]]

(* Random list-form network: 3 to 5 labels of dimension 2 or 3 on 3 to 5
   tensors with 1 to 3 distinct labels each. Labels shared by three or
   more tensors are hyperedges. *)
gfRandomLayout[seed_] := BlockRandom[SeedRandom[seed]; Module[{k = RandomInteger[{3, 5}], names, dims},
    names = Symbol["gfL" <> ToString[#]] & /@ Range[k];
    dims = AssociationThread[names, RandomInteger[{2, 3}, k]];
    {dims, Table[RandomSample[names, RandomInteger[{1, 3}]], RandomInteger[{3, 5}]]}
]]

(* Size of the brute-force sum over the graph form (a label on c >= 3
   tensors becomes c spider legs); seeds are kept below 20000 terms. *)
gfGraphCost[{dims_, labels_}] := Times @@ KeyValueMap[dims[#1]^If[#2 >= 3, #2, 1] &, Counts[Catenate[labels]]]

gfSeeds = Take[Select[Range[200], gfGraphCost[gfRandomLayout[#]] <= 20000 &], 40];

gfRandomNetwork[seed_] := With[{layout = gfRandomLayout[seed]},
    {MapIndexed[gfRandomArray[Lookup[layout[[1]], #1], 100 seed + First[#2]] &, layout[[2]]], layout[[2]]}
]

gfHyperedgeLabels[labels_List] := Keys @ Select[Counts[Catenate[labels]], # >= 3 &]

(* The leg a free list label becomes in the graph: slot k of tensor v. *)
gfLegOfLabel[g_Graph, labels_List, x_] := Extract[gfVertexIndices[g], First[Position[labels, x, {2}]]]

(* Graph built by hand: spec is <|v -> {tensor, legs}|>, edges are
   {{v, k}, {w, j}} joining Superscript[v, k] to Subscript[w, j]. *)
gfBuild[spec_Association, edges_List] := Graph[
    Keys[spec],
    DirectedEdge[#[[1, 1]], #[[2, 1]], {Superscript[#[[1, 1]], #[[1, 2]]], Subscript[#[[2, 1]], #[[2, 2]]]}] & /@ edges,
    AnnotationRules -> KeyValueMap[#1 -> {"Tensor" -> #2[[1]], "Index" -> #2[[2]]} &, spec]
]

(* Directed ring v1 -> v2 -> ... -> v1: vertex v has its outgoing ring leg
   at slot 1, its incoming ring leg at slot 2, and optionally a free
   Superscript leg at slot 3. bond[[i]] is the dimension of the edge
   leaving the i-th vertex. *)
gfRingParts[names_List, bond_List, freeDims_List, seed_] :=
    With[{m = Length[names]},
        {
            AssociationThread[names, Table[
                With[{dims = Join[{bond[[i]], bond[[Mod[i - 2, m] + 1]]}, freeDims[[i]]]},
                    {gfRandomArray[dims, 100 seed + i],
                     Join[{Superscript[names[[i]], 1], Subscript[names[[i]], 2]}, Superscript[names[[i]], 3] & /@ freeDims[[i]]]}
                ],
                {i, m}
            ]],
            Table[{{names[[i]], 1}, {names[[Mod[i, m] + 1]], 2}}, {i, m}]
        }
    ]

gfRing[args__] := gfBuild @@ gfRingParts[args]

(* Every check of a cycle-removal result r of a cyclic graph g at once:
   acyclic, well formed, 2 more vertices per broken cycle, original
   vertices keep their tensors (in order), the same free legs, the same
   value. *)
gfRemoveCyclesReport[g_Graph, cycles_Integer] :=
    With[{r = TensorNetworkRemoveCycles[g], free = gfFreeLegs[g]},
        {
            AcyclicGraphQ[r],
            TensorNetworkGraphQ[r] && gfWellFormedQ[r],
            VertexCount[r] - VertexCount[g],
            Take[gfVertexTensors[r], VertexCount[g]] === gfVertexTensors[g],
            Sort[gfFreeLegs[r]] === Sort[free],
            TensorNetworkGraphQ[r] && gfWellFormedQ[r] && gfGraphValue[r, free] === gfGraphValue[g, free]
        }
    ]

gfRemoveCyclesExpected[cycles_Integer] := {True, True, 2 cycles, True, True, True}


(* ============================================ *)
(* A. ToTensorNetworkGraph from list form       *)
(* ============================================ *)

(* A1. Structure: the graph is a valid tensor-network graph, acyclic and
   well formed, every edge leaves through a Superscript and enters through
   a Subscript, vertices 1..n keep the input tensors, and one spider vertex
   is added per hyperedge. Lists the seeds that fail. *)
VerificationTest[
    Select[gfSeeds, Function[seed, Module[{t, l, g},
        {t, l} = gfRandomNetwork[seed];
        g = ToTensorNetworkGraph[TensorNetwork[t, l]];
        ! And[
            TensorNetworkGraphQ[g],
            AcyclicGraphQ[g],
            gfWellFormedQ[g],
            MatchQ[gfTags[g], {{_Superscript, _Subscript} ...}],
            Take[gfVertexTensors[g], Length[t]] === t,
            VertexCount[g] === Length[t] + Length[gfHyperedgeLabels[l]]
        ]
    ]]],
    {},
    TestID -> "GraphForm_A1_structure"
]

(* A2. Value: the graph's brute-force sum, with each free list label read
   at the leg its slot became, equals the list-form sum. *)
VerificationTest[
    Select[gfSeeds, Function[seed, Module[{t, l, free, g},
        {t, l} = gfRandomNetwork[seed];
        free = gfFreeLabels[l];
        g = ToTensorNetworkGraph[TensorNetwork[t, l]];
        gfGraphValue[g, gfLegOfLabel[g, l, #] & /@ free] =!= gfListOracle[t, l, free]
    ]]],
    {},
    TestID -> "GraphForm_A2_value_matches_list_form"
]

(* A3. TensorNetworkContract of the graph (Automatic plan) returns the
   list-form sum with its free legs in TensorNetworkFreeIndices order. *)
VerificationTest[
    Select[gfSeeds, Function[seed, Module[{t, l, free, g, labelOfLeg},
        {t, l} = gfRandomNetwork[seed];
        free = gfFreeLabels[l];
        g = ToTensorNetworkGraph[TensorNetwork[t, l]];
        labelOfLeg = AssociationThread[gfLegOfLabel[g, l, #] & /@ free, free];
        Normal[TensorNetworkContract[g]] =!= gfListOracle[t, l, Lookup[labelOfLeg, TensorNetworkFreeIndices[g]]]
    ]]],
    {},
    TestID -> "GraphForm_A3_contract_graph"
]

(* A4. Round trip: TensorNetwork[graph] is a list-form network whose
   brute-force sum (spiders made explicit with Normal) equals the original
   one, with free labels renamed to their legs. *)
VerificationTest[
    Select[gfSeeds, Function[seed, Module[{t, l, free, g, back},
        {t, l} = gfRandomNetwork[seed];
        free = gfFreeLabels[l];
        g = ToTensorNetworkGraph[TensorNetwork[t, l]];
        back = TensorNetwork[g];
        ! TensorNetworkQ[back] ||
            gfListOracle[Normal /@ back["Tensors"], back["Hyperedges"], gfLegOfLabel[g, l, #] & /@ free] =!= gfListOracle[t, l, free]
    ]]],
    {},
    TestID -> "GraphForm_A4_round_trip_to_list_form"
]

(* A5. A label repeated on one tensor is a trace; with a second tensor
   sharing another label (dimensions 2, 3, 4). *)
VerificationTest[
    With[{t = {gfRandomArray[{2, 3, 2}, 1], gfRandomArray[{3, 4}, 2]}, l = {{gfA, gfB, gfA}, {gfB, gfC}}},
        With[{g = ToTensorNetworkGraph[TensorNetwork[t, l]]},
            {
                gfWellFormedQ[g],
                gfGraphValue[g, {gfLegOfLabel[g, l, gfC]}] === gfListOracle[t, l, {gfC}],
                Normal[TensorNetworkContract[g]] === gfListOracle[t, l, {gfC}]
            }
        ]
    ],
    {True, True, True},
    TestID -> "GraphForm_A5_trace_label"
]


(* ============================================ *)
(* B. BinaryTensorNetwork                       *)
(* ============================================ *)

(* Random outputs: up to three labels drawn from all labels, so hyperedge
   labels and labels shared by two tensors are often outputs. *)
gfRandomOutput[seed_, labels_] := BlockRandom[SeedRandom[100 seed + 99]; RandomSample[Union @@ labels, RandomInteger[{0, Min[3, Length[Union @@ labels]]}]]]

(* B1. Structure with explicit outputs: binary, output forwarded, input
   tensors kept as the leading tensors, one spider per hyperedge or shared
   output label, each a Kronecker delta of rank (count + 1 if output). *)
VerificationTest[
    Select[gfSeeds, Function[seed, Module[{t, l, out, bin, counts, spidered},
        {t, l} = gfRandomNetwork[seed];
        out = gfRandomOutput[seed, l];
        bin = BinaryTensorNetwork[TensorNetwork[t, l, out]];
        counts = Counts[Catenate[l]];
        spidered = Select[Keys[counts], counts[#] >= 3 || (counts[#] == 2 && MemberQ[out, #]) &];
        ! And[
            TensorNetworkQ[bin],
            Max[Counts[Catenate[bin["Hyperedges"]]]] <= 2,
            bin["Output"] === out,
            Take[bin["Tensors"], Length[t]] === t,
            Sort[ArrayDepth /@ Normal /@ Drop[bin["Tensors"], Length[t]]] === Sort[counts[#] + Boole[MemberQ[out, #]] & /@ spidered],
            AllTrue[Normal /@ Drop[bin["Tensors"], Length[t]],
                # === Array[Boole[Equal[##]] &, Dimensions[#]] &
            ]
        ]
    ]]],
    {},
    TestID -> "GraphForm_B1_binary_structure"
]

(* B2. Value with explicit outputs: the binary network's brute-force sum
   (spiders made explicit with Normal) equals the original's. *)
VerificationTest[
    Select[gfSeeds, Function[seed, Module[{t, l, out, bin},
        {t, l} = gfRandomNetwork[seed];
        out = gfRandomOutput[seed, l];
        bin = BinaryTensorNetwork[TensorNetwork[t, l, out]];
        gfListOracle[Normal /@ bin["Tensors"], bin["Hyperedges"], out] =!= gfListOracle[t, l, out]
    ]]],
    {},
    TestID -> "GraphForm_B2_binary_value_explicit_output"
]

(* B3. Automatic output: the free labels (on one slot) are the same set
   before and after, and the values agree. *)
VerificationTest[
    Select[gfSeeds, Function[seed, Module[{t, l, free, bin},
        {t, l} = gfRandomNetwork[seed];
        free = gfFreeLabels[l];
        bin = BinaryTensorNetwork[TensorNetwork[t, l]];
        Sort[gfFreeLabels[bin["Hyperedges"]]] =!= Sort[free] ||
            gfListOracle[Normal /@ bin["Tensors"], bin["Hyperedges"], free] =!= gfListOracle[t, l, free]
    ]]],
    {},
    TestID -> "GraphForm_B3_binary_value_automatic_output"
]

(* B4. TensorNetworkContract of the binary network, spiders left symbolic,
   against the original's brute-force sum. *)
VerificationTest[
    Select[gfSeeds, Function[seed, Module[{t, l, out, bin},
        {t, l} = gfRandomNetwork[seed];
        out = gfRandomOutput[seed, l];
        bin = BinaryTensorNetwork[TensorNetwork[t, l, out]];
        Normal[TensorNetworkContract[bin]] =!= gfListOracle[t, l, out]
    ]]],
    {},
    TestID -> "GraphForm_B4_contract_binary_network"
]

(* B5. A network that is already binary comes back as the same object. *)
VerificationTest[
    Select[gfSeeds, Function[seed, Module[{t, l, tn},
        {t, l} = gfRandomNetwork[seed];
        tn = TensorNetwork[t, l, gfFreeLabels[l]];
        Max[Counts[Catenate[l]]] <= 2 && BinaryTensorNetwork[tn] =!= tn
    ]]],
    {},
    TestID -> "GraphForm_B5_binary_input_unchanged"
]


(* ============================================ *)
(* C. TensorNetworkRemoveCycles                 *)
(* ============================================ *)

(* C1. Directed ring of three matrices with bonds of dimension 2, 3, 4:
   a closed network whose value is a trace of a matrix product. *)
VerificationTest[
    gfRemoveCyclesReport[gfRing[{1, 2, 3}, {2, 3, 4}, {{}, {}, {}}, 1], 1],
    gfRemoveCyclesExpected[1],
    TestID -> "GraphForm_C1_ring_of_three"
]

(* C2. Directed ring of four rank-3 tensors, each with a free leg
   (bonds 3, 2, 4, 2; free dimensions 2, 3, 2, 2), and TensorNetworkContract
   of the result in TensorNetworkFreeIndices order. *)
VerificationTest[
    With[{g = gfRing[{1, 2, 3, 4}, {3, 2, 4, 2}, {{2}, {3}, {2}, {2}}, 2]},
        Append[
            gfRemoveCyclesReport[g, 1],
            With[{r = TensorNetworkRemoveCycles[g]},
                Normal[TensorNetworkContract[r]] === gfGraphValue[g, TensorNetworkFreeIndices[r]]
            ]
        ]
    ],
    Append[gfRemoveCyclesExpected[1], True],
    TestID -> "GraphForm_C2_open_ring_of_four"
]

(* C3. Two tensors joined both ways (a 2-cycle) with bonds of dimension 3
   and 4 and a free leg of dimension 2 on the first. *)
VerificationTest[
    With[{g = gfBuild[
        <|
            1 -> {gfRandomArray[{3, 4, 2}, 3], {Superscript[1, 1], Subscript[1, 2], Superscript[1, 3]}},
            2 -> {gfRandomArray[{3, 4}, 4], {Subscript[2, 1], Superscript[2, 2]}}
        |>,
        {{{1, 1}, {2, 1}}, {{2, 2}, {1, 2}}}
    ]},
        Append[
            gfRemoveCyclesReport[g, 1],
            Normal[TensorNetworkContract[TensorNetworkRemoveCycles[g]]] === gfGraphValue[g, {Superscript[1, 3]}]
        ]
    ],
    Append[gfRemoveCyclesExpected[1], True],
    TestID -> "GraphForm_C3_two_cycle"
]

(* C4. The complete digraph on three vertices (six edges, several
   overlapping cycles), bonds of dimension 2, 3, 4 and a free leg of
   dimension 2 on vertex 1. The number of broken cycles is whatever the loop needed, so it
   is checked as two new vertices per new cap. *)
gfK3 = gfBuild[
    <|
        1 -> {gfRandomArray[{2, 3, 4, 2, 2}, 5], {Superscript[1, 1], Superscript[1, 2], Subscript[1, 3], Subscript[1, 4], Superscript[1, 5]}},
        2 -> {gfRandomArray[{4, 2, 2, 3}, 6], {Superscript[2, 1], Superscript[2, 2], Subscript[2, 3], Subscript[2, 4]}},
        3 -> {gfRandomArray[{2, 3, 3, 2}, 7], {Superscript[3, 1], Superscript[3, 2], Subscript[3, 3], Subscript[3, 4]}}
    |>,
    {
        {{1, 1}, {2, 3}}, {{2, 1}, {1, 3}},
        {{1, 2}, {3, 3}}, {{3, 1}, {1, 4}},
        {{2, 2}, {3, 4}}, {{3, 2}, {2, 4}}
    }
];

VerificationTest[
    With[{r = TensorNetworkRemoveCycles[gfK3]},
        {
            AcyclicGraphQ[r],
            TensorNetworkGraphQ[r] && gfWellFormedQ[r],
            VertexCount[r] - 3 === 2 Count[AnnotationValue[{r, #}, VertexLabels] & /@ VertexList[r], "Cap"],
            Take[gfVertexTensors[r], 3] === gfVertexTensors[gfK3],
            gfWellFormedQ[r] && gfGraphValue[r, gfFreeLegs[gfK3]] === gfGraphValue[gfK3, gfFreeLegs[gfK3]],
            Normal[TensorNetworkContract[r]] === gfGraphValue[gfK3, TensorNetworkFreeIndices[r]]
        }
    ],
    {True, True, True, True, True, True},
    TestID -> "GraphForm_C4_complete_digraph"
]

(* C5. Figure eight: two directed cycles 1 -> 2 -> 1 and 1 -> 3 -> 1
   sharing vertex 1; and two disjoint rings (a disconnected network, only
   summed here, never contracted by the paclet). *)
VerificationTest[
    {
        gfRemoveCyclesReport[
            gfBuild[
                <|
                    1 -> {gfRandomArray[{2, 3, 4, 2}, 8], {Superscript[1, 1], Subscript[1, 2], Superscript[1, 3], Subscript[1, 4]}},
                    2 -> {gfRandomArray[{2, 3}, 9], {Subscript[2, 1], Superscript[2, 2]}},
                    3 -> {gfRandomArray[{4, 2, 3}, 10], {Subscript[3, 1], Superscript[3, 2], Superscript[3, 3]}}
                |>,
                {{{1, 1}, {2, 1}}, {{2, 2}, {1, 2}}, {{1, 3}, {3, 1}}, {{3, 2}, {1, 4}}}
            ],
            2
        ],
        gfRemoveCyclesReport[
            With[{a = gfRingParts[{1, 2}, {2, 3}, {{}, {4}}, 11], b = gfRingParts[{3, 4, 5}, {3, 2, 4}, {{2}, {}, {}}, 12]},
                gfBuild[Join[a[[1]], b[[1]]], Join[a[[2]], b[[2]]]]
            ],
            2
        ]
    },
    {gfRemoveCyclesExpected[2], gfRemoveCyclesExpected[2]},
    TestID -> "GraphForm_C5_figure_eight_and_disjoint_rings"
]

(* C6. ToTensorNetworkGraph on a cyclic annotated graph removes the cycle
   and keeps the value: the open ring of C2, whose edges all join slot 1
   of one vertex to slot 2 of the next. *)
VerificationTest[
    With[{ring = gfRing[{1, 2, 3, 4}, {3, 2, 4, 2}, {{2}, {3}, {2}, {2}}, 2]},
        With[{h = ToTensorNetworkGraph[ring]},
            {
                AcyclicGraphQ[h],
                gfWellFormedQ[h] && gfGraphValue[h, gfFreeLegs[ring]] === gfGraphValue[ring, gfFreeLegs[ring]],
                gfWellFormedQ[h] && Normal[TensorNetworkContract[h]] === gfGraphValue[ring, TensorNetworkFreeIndices[h]]
            }
        ]
    ],
    {True, True, True},
    TestID -> "GraphForm_C6_to_graph_from_cyclic_ring"
]

(* C7. Vertices named 5, 1, 2 (not 1..n): vertex 5 has a free incoming leg
   Subscript[5, 1], an outgoing ring leg at slot 2 and an incoming ring leg
   at slot 3. Breaking the ring must not reuse a leg name of vertex 5. *)
VerificationTest[
    gfRemoveCyclesReport[
        gfBuild[
            <|
                5 -> {gfRandomArray[{2, 4, 3}, 13], {Subscript[5, 1], Superscript[5, 2], Subscript[5, 3]}},
                1 -> {gfRandomArray[{3, 4}, 14], {Superscript[1, 1], Subscript[1, 2]}},
                2 -> {gfRandomArray[{3, 3}, 15], {Superscript[2, 1], Subscript[2, 2]}}
            |>,
            {{{5, 2}, {1, 2}}, {{1, 1}, {2, 2}}, {{2, 1}, {5, 3}}}
        ],
        1
    ],
    gfRemoveCyclesExpected[1],
    TestID -> "GraphForm_C7_vertex_names_not_one_to_n"
]

(* C8. ToTensorNetworkGraph on an annotated graph must keep the legs each
   edge joins. Two cases: an acyclic graph with two edges 1 -> 2 that
   cross slots (Superscript[1, 1] to Subscript[2, 2] and Superscript[1, 2]
   to Subscript[2, 1], all dimensions 3, value Tr[A . B]); and the
   complete digraph of C4, where two legs of a vertex have different
   dimensions. *)
VerificationTest[
    With[{
        crossed = gfBuild[
            <|
                1 -> {gfRandomArray[{3, 3}, 16], {Superscript[1, 1], Superscript[1, 2]}},
                2 -> {gfRandomArray[{3, 3}, 17], {Subscript[2, 1], Subscript[2, 2]}}
            |>,
            {{{1, 1}, {2, 2}}, {{1, 2}, {2, 1}}}
        ]
    },
        {
            gfGraphValue[crossed, {}] === Tr[gfRandomArray[{3, 3}, 16] . gfRandomArray[{3, 3}, 17]],
            With[{h = ToTensorNetworkGraph[crossed]}, gfWellFormedQ[h] && gfGraphValue[h, {}] === gfGraphValue[crossed, {}]],
            With[{h = ToTensorNetworkGraph[gfK3]}, gfWellFormedQ[h] && gfGraphValue[h, gfFreeLegs[gfK3]] === gfGraphValue[gfK3, gfFreeLegs[gfK3]]]
        }
    ],
    {True, True, True},
    TestID -> "GraphForm_C8_to_graph_keeps_edge_legs"
]


(* C9. A ring of three vertices named by strings: breaking it adds one cup
   and one cap and keeps the value *)
VerificationTest[
    gfRemoveCyclesReport[
        gfBuild[
            <|
                "a" -> {gfRandomArray[{2, 4}, 18], {Superscript["a", 1], Subscript["a", 2]}},
                "b" -> {gfRandomArray[{3, 2}, 19], {Superscript["b", 1], Subscript["b", 2]}},
                "c" -> {gfRandomArray[{4, 3}, 20], {Superscript["c", 1], Subscript["c", 2]}}
            |>,
            {{{"a", 1}, {"b", 2}}, {{"b", 1}, {"c", 2}}, {{"c", 1}, {"a", 2}}}
        ],
        1
    ],
    gfRemoveCyclesExpected[1],
    TestID -> "GraphForm_C9_string_vertex_names"
]

(* C10. Two rings of the same shape whose vertices have different names (vertex k carries
   legs {out, in} of dimensions {d(k, k+1), d(k-1, k)}; the value is Tr[A . C . B]), contracted
   one after the other in one kernel: the second must not reuse the plan of the first, which names the
   first ring's vertices *)
gfNamedRing[names_] := gfBuild[
    AssociationThread[names, MapThread[
        {#1, {Superscript[#2, 1], Subscript[#2, 2]}} &,
        {{gfRandomArray[{2, 4}, 21], gfRandomArray[{3, 2}, 22], gfRandomArray[{4, 3}, 23]}, names}
    ]],
    {{{names[[1]], 1}, {names[[2]], 2}}, {{names[[2]], 1}, {names[[3]], 2}}, {{names[[3]], 1}, {names[[1]], 2}}}
]

VerificationTest[
    With[{trace = Tr[gfRandomArray[{2, 4}, 21] . gfRandomArray[{4, 3}, 23] . gfRandomArray[{3, 2}, 22]]},
        Abs[Normal[TensorNetworkContract[TensorNetworkRemoveCycles[gfNamedRing[#]]]] - trace] < 10^-10 & /@ {{1, 2, 3}, {"a", "b", "c"}, {7, 8, 9}}
    ],
    {True, True, True},
    TestID -> "GraphForm_C10_same_shape_other_vertex_names"
]

(* D1. Building the graph of a long network grows about linearly: eight times the tensors takes
   well under 64 times as long, which a construction that scans every edge per label would *)
gfChain[m_] := TensorNetwork[
    ConstantArray[ConstantArray[1., {2, 2, 2}], m],
    Table[{k, k + 1, 10^6 + Mod[k, 7]}, {k, m}]
];

VerificationTest[
    With[{times = Table[Median[Table[First[AbsoluteTiming[ToTensorNetworkGraph[gfChain[m]]]], 3]], {m, {400, 3200}}]},
        Last[times] / First[times] < 24
    ],
    True,
    TestID -> "GraphForm_D1_construction_scales_linearly"
]

(* A1b. A label that is a list, shared by three tensors: its spider has the label's dimension *)
VerificationTest[
    With[{g = ToTensorNetworkGraph[TensorNetwork[
        {gfRandomArray[{2, 3}, 31], gfRandomArray[{3, 4}, 32], gfRandomArray[{3}, 33], gfRandomArray[{4}, 34]},
        {{{"a", 1}, {"b"}}, {{"b"}, {"c", 2}}, {{"b"}}, {{"c", 2}}}
    ]]},
        Dimensions[Normal[#]] & /@ Select[AnnotationValue[{g, Developer`FromPackedArray[VertexList[g]]}, "Tensor"], MatchQ[#, _SymbolicDeltaProductArray] &]
    ],
    {{3, 3, 3}},
    TestID -> "GraphForm_A1b_list_label_spider_dimension"
]
