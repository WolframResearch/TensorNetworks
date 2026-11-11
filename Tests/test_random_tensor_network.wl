(* RandomTensorNetwork: the documented connectivity and dimensions, checked against
   hand-built expected structures *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

SeedRandom[42];

(* Tensor positions joined by each label carried by two tensors, as sorted pairs *)
bondPairs[tn_] := Sort @ Values @ Select[
    GroupBy[Catenate @ MapIndexed[Thread[#1 -> First[#2]] &, tn["Hyperedges"]], First -> Last],
    Length[#] === 2 &
]

(* Labels carried by exactly one tensor *)
openLabels[tn_] := Keys @ Select[Counts[Catenate[tn["Hyperedges"]]], # === 1 &]

labelDimensions[tn_] := Association @ Flatten @ MapThread[Thread[#1 -> Dimensions[#2]] &, {tn["Hyperedges"], tn["Tensors"]}]

(* Two triangles joined by an edge, plus a pendant vertex *)
fixedGraph = Graph[Range[7], {1 <-> 2, 2 <-> 3, 1 <-> 3, 3 <-> 4, 4 <-> 5, 5 <-> 6, 4 <-> 6, 6 <-> 7}];
fixedGraphPairs = Sort[Sort /@ List @@@ EdgeList[fixedGraph]];


(* ============================================ *)
(* Arbitrary graph                              *)
(* ============================================ *)

(* Seeds whose network breaks the documented structure; the generator draws at random,
   so each promise is checked over many seeds *)
badSeeds[make_, ok_] := Select[Range[20], Function[seed, ! TrueQ[ok[BlockRandom[SeedRandom[seed]; make[]]]]]]

(* One tensor per vertex, one bond per edge, every bond dimension in {2, maxDim}, no free legs *)
VerificationTest[
    badSeeds[
        RandomTensorNetwork[fixedGraph, 4] &,
        Function[tn, And[
            Length[tn["Tensors"]] === 7,
            bondPairs[tn] === fixedGraphPairs,
            openLabels[tn] === {},
            SubsetQ[Range[2, 4], Values[labelDimensions[tn]]]
        ]]
    ],
    {},
    TestID -> "RandomTensorNetwork_Graph_BondsAreTheEdges"
]

(* {dim}: every dimension is exactly dim; up to r extra free legs per vertex *)
VerificationTest[
    badSeeds[
        RandomTensorNetwork[fixedGraph, {3}, 2] &,
        Function[tn, And[
            bondPairs[tn] === fixedGraphPairs,
            Union[Values[labelDimensions[tn]]] === {3},
            And @@ MapThread[LessEqual[#1, #2, #1 + 2] &, {VertexDegree[fixedGraph], Length /@ tn["Hyperedges"]}],
            Length[openLabels[tn]] === Total[Length /@ tn["Hyperedges"]] - Total[VertexDegree[fixedGraph]]
        ]]
    ],
    {},
    TestID -> "RandomTensorNetwork_Graph_FixedDimensionAndFreeLegs"
]

(* {n, m}: n tensors joined by m bonds *)
VerificationTest[
    badSeeds[
        RandomTensorNetwork[{8, 12}, 3] &,
        Function[tn, And[Length[tn["Tensors"]] === 8, Length[bondPairs[tn]] === 12, openLabels[tn] === {}]]
    ],
    {},
    TestID -> "RandomTensorNetwork_NM_TensorAndBondCount"
]

(* Default entries are reals in [-1, 1]; Method -> "Complex" gives complex entries *)
VerificationTest[
    {
        With[{e = Flatten[RandomTensorNetwork[fixedGraph, 3]["Tensors"]]}, AllTrue[e, Head[#] === Real && -1 <= # <= 1 &]],
        With[{e = Flatten[RandomTensorNetwork[fixedGraph, 3, Method -> "Complex"]["Tensors"]]}, AllTrue[e, Head[#] === Complex &]]
    },
    {True, True},
    TestID -> "RandomTensorNetwork_EntryType"
]


(* ============================================ *)
(* MPS                                          *)
(* ============================================ *)

(* MPS[L, D, d]: bonds 1..L-1 between neighbours, physical legs L+1..2L *)
VerificationTest[
    With[{tn = RandomTensorNetwork["MPS"[5, 4, 3]]},
        {tn["Hyperedges"], Dimensions /@ tn["Tensors"]}
    ],
    {
        {{1, 6}, {1, 2, 7}, {2, 3, 8}, {3, 4, 9}, {4, 10}},
        {{4, 3}, {4, 4, 3}, {4, 4, 3}, {4, 4, 3}, {4, 3}}
    },
    TestID -> "RandomTensorNetwork_MPS_Open"
]

(* Periodic: a ring, every site rank 3 *)
VerificationTest[
    With[{tn = RandomTensorNetwork["MPS"[4, 2, 3], "Boundary" -> "Periodic"]},
        {bondPairs[tn], tn["FreeIndices"], Union[Dimensions /@ tn["Tensors"]]}
    ],
    {{{1, 2}, {1, 4}, {2, 3}, {3, 4}}, {5, 6, 7, 8}, {{2, 2, 3}}},
    TestID -> "RandomTensorNetwork_MPS_Periodic"
]


(* ============================================ *)
(* PEPS                                         *)
(* ============================================ *)

(* PEPS[{r, c}, D, d]: row-major sites joined as the r x c grid, one physical leg each *)
VerificationTest[
    With[{tn = RandomTensorNetwork["PEPS"[{3, 4}, 2, 3]]},
        {
            bondPairs[tn],
            Length[tn["FreeIndices"]],
            Union @ Lookup[labelDimensions[tn], tn["FreeIndices"]],
            Union @ Lookup[labelDimensions[tn], Complement[Catenate[tn["Hyperedges"]], tn["FreeIndices"]]]
        }
    ],
    {
        Sort @ Join[
            Catenate @ Table[{(r - 1) 4 + c, (r - 1) 4 + c + 1}, {r, 3}, {c, 3}],
            Catenate @ Table[{(r - 1) 4 + c, r 4 + c}, {r, 2}, {c, 4}]
        ],
        12, {3}, {2}
    },
    TestID -> "RandomTensorNetwork_PEPS_Grid"
]


(* ============================================ *)
(* TTN and MERA                                 *)
(* ============================================ *)

(* TTN[depth, D, b]: b^(depth-1) leaf vectors labelled 1.., each level's node joins b children
   of the level below and, below the top, one parent bond; the top node has no parent *)
VerificationTest[
    With[{tn = RandomTensorNetwork["TTN"[3, 2, 2]]},
        {tn["Hyperedges"], Dimensions /@ tn["Tensors"], tn["FreeIndices"]}
    ],
    {
        {{1}, {2}, {3}, {4}, {1, 2, 5}, {3, 4, 6}, {5, 6}},
        {{2}, {2}, {2}, {2}, {2, 2, 2}, {2, 2, 2}, {2, 2}},
        {}
    },
    TestID -> "RandomTensorNetwork_TTN_Tree"
]

(* MERA[w, D, layers]: per layer w/2 disentanglers (2 in, 2 out) then w/2 isometries (2 in,
   1 out); a later layer's inputs start with the earlier layer's outputs *)
VerificationTest[
    With[{tn = RandomTensorNetwork["MERA"[4, 2, 2]]},
        {tn["Hyperedges"], Dimensions /@ tn["Tensors"]}
    ],
    {
        {
            {1, 2, 5, 6}, {3, 4, 7, 8}, {5, 6, 9}, {7, 8, 10},
            {9, 10, 13, 14}, {11, 12, 15, 16}, {13, 14, 17}, {15, 16, 18}
        },
        {{2, 2, 2, 2}, {2, 2, 2, 2}, {2, 2, 2}, {2, 2, 2}, {2, 2, 2, 2}, {2, 2, 2, 2}, {2, 2, 2}, {2, 2, 2}}
    },
    TestID -> "RandomTensorNetwork_MERA_Layers"
]

(* The same seed gives the same tensors: draws are taken site by site in a fixed order *)
VerificationTest[
    SameQ @@ Table[BlockRandom[SeedRandom[11]; RandomTensorNetwork[#]["Tensors"]], 2] & /@
        {"PEPS"[{2, 3}, 2], "TTN"[3, 2], "MERA"[4, 2, 2]},
    {True, True, True},
    TestID -> "RandomTensorNetwork_StructuredReproducible"
]

(* MERA with an odd width: the remaining input becomes a free leg, every label an integer *)
VerificationTest[
    With[{tn = RandomTensorNetwork["MERA"[3, 2, 2]]},
        {tn["Hyperedges"], VectorQ[Catenate[tn["Hyperedges"]], IntegerQ]}
    ],
    {{{1, 2, 4, 5}, {4, 5, 7}, {7, 8, 10, 11}, {10, 11, 13}}, True},
    TestID -> "RandomTensorNetwork_MERA_OddWidth"
]
