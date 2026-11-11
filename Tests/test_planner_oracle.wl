(* The Automatic planner on networks of 8 to 12 tensors and more, where it searches: randomized
   greedy trials, half-weight greedy, the sweep, diagonal-reduced plans, the memory budget and
   the plan cache. Values are checked against a brute-force sum over every index assignment,
   computed here; plan prices against a flop and size count written here and against the best
   of many seeded randomized greedy trials run here. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

poPrivate[name_] := Symbol["Wolfram`TensorNetworks`Contraction`PackagePrivate`" <> name];

(* The planner's knobs, pinned so a test does not depend on the memory free when it runs.
   poPinned keeps the planner's own policy; poSearching makes it search even when the
   contraction is cheap (no planning threshold, trials always within the time allowance),
   with at most trialCap randomized trials. Both start from an empty plan cache. *)
SetAttributes[{poPinned, poSearching}, HoldFirst];

poPinned[expr_, budget_ : Infinity] := Block[{
    Wolfram`TensorNetworks`Contraction`PackagePrivate`memoryBudget = (budget &),
    Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache = <||>
},
    expr
]

poSearching[expr_, budget_ : Infinity, trialCap_ : 48] := Block[{
    Wolfram`TensorNetworks`Contraction`PackagePrivate`memoryBudget = (budget &),
    Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache = <||>,
    Wolfram`TensorNetworks`Contraction`PackagePrivate`planningThreshold = (0. &),
    Wolfram`TensorNetworks`Contraction`PackagePrivate`$secondsPerPrice = 1.,
    Wolfram`TensorNetworks`Contraction`PackagePrivate`$maxGreedyTrials = trialCap
},
    expr
]


(* ------------------------------------------------------------------ *)
(* Oracle                                                              *)
(* ------------------------------------------------------------------ *)

(* Brute force over the flattened space of every label, output labels first: each tensor's
   entry for every assignment is read by its row-major flat position, the entries multiplied,
   and the non-output part of the space summed. Repeated labels read the diagonal. *)
poOracle[tensors_, labels_, out_, dims_Association] := Block[{
    order = Join[out, Complement[Union @@ labels, out]], d, n, coordinate, entries, product
},
    d = Lookup[dims, order];
    n = Times @@ d;
    coordinate = AssociationThread[order,
        MapThread[Mod[Quotient[Range[0, n - 1], #1], #2] &, {Reverse[FoldList[Times, 1, Reverse[Rest[d]]]], d}]
    ];
    entries[t_, {}] := t;
    entries[t_, ls_] := Flatten[Normal[t]][[
        1 + Total[MapThread[#1 #2 &, {Lookup[coordinate, ls], Reverse[FoldList[Times, 1, Reverse[Rest[Dimensions[t]]]]]}]]
    ]];
    product = Times @@ MapThread[entries, {tensors, labels}];
    With[{summed = Total[ArrayReshape[product, {Times @@ Lookup[dims, out], n / (Times @@ Lookup[dims, out])}], {2}]},
        If[out === {}, First[summed], ArrayReshape[summed, Lookup[dims, out]]]
    ]
]

(* A random network of 8 to 12 tensors over 7 to 10 labels of unequal dimensions (1 to 4),
   at most cap assignments in all. Label 1 is a hyperedge on at least three tensors; about
   half the networks keep it in the output, a few have a tensor with a repeated label. *)
poShape[seed_, cap_] := BlockRandom[SeedRandom[seed]; Module[{tensorCount, labelCount, dims, labels, out},
    tensorCount = RandomInteger[{8, 12}];
    labelCount = RandomInteger[{7, 10}];
    dims = NestWhile[
        ReplacePart[#, First[Ordering[#, -1]] -> Max[#] - 1] &,
        RandomChoice[{1, 3, 4, 3} -> {1, 2, 3, 4}, labelCount],
        Times @@ # > cap &
    ];
    labels = Table[RandomSample[Range[labelCount], RandomInteger[{1, 4}]], tensorCount];
    labels = MapAt[DeleteDuplicates[Prepend[#, 1]] &, labels, List /@ RandomSample[Range[tensorCount], 3]];
    If[RandomReal[] < .25, labels[[2]] = Append[labels[[2]], First[labels[[2]]]]];
    out = RandomSample[DeleteCases[Union @@ labels, 1], RandomInteger[{0, 2}]];
    If[RandomReal[] < .5, out = Append[out, 1]];
    {labels, RandomSample[out], AssociationThread[Range[labelCount], dims]}
]]

poValues[kind_, d_] := Switch[kind,
    "Complex", RandomComplex[{-1 - I, 1 + I}, d],
    "Integer", RandomInteger[{-6, 6}, d],
    "Rational", RandomChoice[Join[Range[-9, -1], Range[9]], d] / RandomInteger[{1, 7}, d],
    "GaussianRational", (RandomInteger[{-5, 5}, d] + I RandomInteger[{-5, 5}, d]) / RandomInteger[{1, 4}, d],
    "Sparse", SparseArray[RandomChoice[{.7, .3} -> {0, 1}, d] RandomComplex[{-1 - I, 1 + I}, d]]
]

(* {tensors, labels, output, dims}; machine kinds get more assignments than exact ones *)
poNetwork[seed_, kind_, valueSeed_ : 0] := With[{shape = poShape[seed, If[MemberQ[{"Complex", "Sparse"}, kind], 2*^5, 4*^4]]},
    BlockRandom[SeedRandom[1000 + seed + 7919 valueSeed];
        {poValues[kind, Lookup[Last[shape], #]] & /@ First[shape], First[shape], shape[[2]], Last[shape]}
    ]
]

poRelativeError[x_, ref_] := Max[Abs[Flatten[{Normal[x] - ref}]]] / Max[10^-300, Max[Abs[Flatten[{ref}]]]]

poAgreeQ[x_, ref_, exactQ_] := If[exactQ, Normal[x] === ref, TrueQ[poRelativeError[x, ref] < 10^-10]]

(* the seeds whose contraction by route differs from the oracle *)
poDisagreements[route_, kind_, seeds_] := Select[seeds, Function[seed,
    With[{net = poNetwork[seed, kind]},
        ! poAgreeQ[
            route[TensorNetwork[net[[1]], net[[2]], net[[3]]]],
            poOracle @@ net,
            ! MemberQ[{"Complex", "Sparse"}, kind]
        ]
    ]
]]

$poSeeds = Range[14];

(* the oracle itself, on a closed form: a trace of a product of three matrices, and a
   hyperedge kept in the output (an elementwise product of three vectors) *)
VerificationTest[
    BlockRandom[SeedRandom[1]; With[{a = RandomInteger[{-5, 5}, {2, 3}], b = RandomInteger[{-5, 5}, {3, 4}], c = RandomInteger[{-5, 5}, {4, 2}], u = RandomInteger[{-5, 5}, 3]},
        {
            poOracle[{a, b, c}, {{1, 2}, {2, 3}, {3, 1}}, {}, <|1 -> 2, 2 -> 3, 3 -> 4|>] === Tr[a . b . c],
            poOracle[{a, b, c}, {{1, 2}, {2, 3}, {3, 1}}, {3, 1}, <|1 -> 2, 2 -> 3, 3 -> 4|>] === Transpose[a . b] c,
            poOracle[{u, 2 u, 3 u}, {{1}, {1}, {1}}, {1}, <|1 -> 3|>] === 6 u^3,
            poOracle[{{{1, 2}, {3, 4}}}, {{1, 1}}, {1}, <|1 -> 2|>] === {1, 4}
        }
    ]],
    {True, True, True, True},
    TestID -> "PlannerOracle_OracleClosedForms"
]

(* the generated networks are in the regime they claim: 8 to 12 tensors, a hyperedge on
   three or more, some with the hyperedge in the output *)
VerificationTest[
    With[{shapes = poShape[#, 2*^5] & /@ $poSeeds},
        {
            AllTrue[shapes, 8 <= Length[First[#]] <= 12 &],
            AllTrue[shapes, Count[First[#], l_ /; MemberQ[l, 1]] >= 3 &],
            AnyTrue[shapes, MemberQ[#[[2]], 1] &],
            AllTrue[shapes, Times @@ Last[#] <= 2*^5 &]
        }
    ],
    {True, True, True, True},
    TestID -> "PlannerOracle_NetworksInRegime"
]


(* ------------------------------------------------------------------ *)
(* A. Complex machine numbers against the oracle                       *)
(* ------------------------------------------------------------------ *)

VerificationTest[
    poPinned @ poDisagreements[TensorNetworkContract, "Complex", $poSeeds],
    {},
    TestID -> "PlannerOracle_Complex_Automatic"
]

(* with the search forced on: trials, half-weight greedy, the sweep and reduced plans compete *)
VerificationTest[
    poSearching @ poDisagreements[TensorNetworkContract, "Complex", $poSeeds],
    {},
    TestID -> "PlannerOracle_Complex_AutomaticSearching"
]

(* the forced search does change the plan: on some of these networks it is not greedy's *)
VerificationTest[
    Count[$poSeeds, seed_ /; With[{net = poNetwork[seed, "Complex"]}, With[{data = TensorNetworkData[TensorNetwork @@ Most[net]]},
        With[{plan = poSearching[poPrivate["automaticPlan"][data, "ArrayDot"]]},
            KeyExistsQ[First[plan], "Reduction"] ||
                Last[plan] =!= PathToTreePath[GreedyContractionPath @@ extractContractionParameters[data], data["Vertices"]]
        ]
    ]]] >= 3,
    True,
    TestID -> "PlannerOracle_SearchChangesPlans"
]

VerificationTest[
    poSearching @ Map[
        Function[method, poDisagreements[TensorNetworkContract[#, Method -> method] &, "Complex", $poSeeds]],
        {"ArrayDot", "Dot", "ArrayDotTranspose", "TensorContract"}
    ],
    {{}, {}, {}, {}},
    TestID -> "PlannerOracle_Complex_EachMethod"
]

VerificationTest[
    poSearching @ poDisagreements[TensorNetworkContract, "Sparse", $poSeeds],
    {},
    TestID -> "PlannerOracle_SparseLeaves_AutomaticSearching"
]


(* ------------------------------------------------------------------ *)
(* B. Exact integers and rationals: equal, not close                   *)
(* ------------------------------------------------------------------ *)

VerificationTest[
    poPinned @ Map[poDisagreements[TensorNetworkContract, #, $poSeeds] &, {"Integer", "Rational", "GaussianRational"}],
    {{}, {}, {}},
    TestID -> "PlannerOracle_Exact_Automatic"
]

VerificationTest[
    poSearching @ Map[poDisagreements[TensorNetworkContract, #, $poSeeds] &, {"Integer", "Rational", "GaussianRational"}],
    {{}, {}, {}},
    TestID -> "PlannerOracle_Exact_AutomaticSearching"
]

VerificationTest[
    poSearching @ Map[
        Function[method, poDisagreements[TensorNetworkContract[#, Method -> method] &, "Rational", $poSeeds]],
        {"ArrayDot", "Dot", "ArrayDotTranspose", "TensorContract"}
    ],
    {{}, {}, {}, {}},
    TestID -> "PlannerOracle_Rational_EachMethod"
]


(* ------------------------------------------------------------------ *)
(* C. Plan quality on PEPS norms and brickwork circuits                *)
(* ------------------------------------------------------------------ *)

(* Closed PEPS norm on a rows x cols grid: each site's ket and bra tensor share the
   physical label (dimension 2); ket and bra bonds (dimension chi) are distinct labels. *)
poPepsShape[{rows_, cols_}, chi_] := With[{
    site = Function[{r, c, side}, Join[
        {{"p", r, c}},
        If[c > 1, {{side, "h", r, c - 1}}, {}], If[c < cols, {{side, "h", r, c}}, {}],
        If[r > 1, {{side, "v", r - 1, c}}, {}], If[r < rows, {{side, "v", r, c}}, {}]
    ]]
},
    With[{labels = Join @@ Table[Catenate @ Table[site[r, c, side], {r, rows}, {c, cols}], {side, {"ket", "bra"}}]},
        {labels, {}, AssociationMap[If[First[#] === "p", 2, chi] &, Union @@ labels]}
    ]
]

(* Amplitude <0...0| C |0...0> of a brickwork circuit of two-qubit gates: a vector at each
   wire's start and end, label {q, t} for wire q after t gates *)
poBrickworkShape[n_, depth_] := Module[{time = ConstantArray[0, n], gates},
    gates = Catenate @ Table[
        Table[
            With[{before = {{q, time[[q]]}, {q + 1, time[[q + 1]]}}},
                time[[{q, q + 1}]] += 1;
                Join[before, {{q, time[[q]]}, {q + 1, time[[q + 1]]}}]
            ],
            {q, 1 + Mod[layer, 2], n - 1, 2}
        ],
        {layer, 0, depth - 1}
    ];
    With[{labels = Join[Table[{{q, 0}}, {q, n}], gates, Table[{{q, time[[q]]}}, {q, n}]]},
        {labels, {}, AssociationMap[2 &, Union @@ labels]}
    ]
]

poShapeNetwork[{labels_, out_, dims_}, seed_] := BlockRandom[SeedRandom[seed];
    TensorNetwork[RandomReal[{-1, 1}, Lookup[dims, #]] & /@ labels, labels, out]
]

(* Price of a contraction tree, counted here: a leaf first drops the labels nothing else
   holds; a step keeps the labels the output or a tensor outside it still holds. Each step
   costs the entries it moves (operands and result, twice past 2^20) plus its multiply-adds
   (the product of every label dimension it touches) over 70. Gives {price, largest result}. *)
poTreePrice[form_, tree_] := Block[{
    leafLabels = AssociationThread[form["Vertices"], DeleteDuplicates /@ form["ContractionIndices"]],
    out = form["FreeIndices"],
    dim = Association @ MapThread[Thread[#1 -> Dimensions[#2]] &, {form["ContractionIndices"], form["Tensors"]}],
    holders, size, moved, node, terms
},
    holders = Counts[Catenate[Values[leafLabels]]];
    size[ls_] := Times @@ Lookup[dim, ls];
    moved[s_] := If[s > 2^20, 2 s, s];
    (* a node: its labels, each with the number of its leaves that hold it *)
    node[{v_ ? (! ListQ[#] &)}] := AssociationMap[1 &, Select[leafLabels[v], holders[#] > 1 || MemberQ[out, #] &]];
    node[children_List] := Fold[
        Function[{x, y}, With[{touched = Merge[{x, y}, Total]},
            With[{kept = KeySelect[touched, MemberQ[out, #] || touched[#] < holders[#] &]},
                Sow[{moved[size[Keys[x]]] + moved[size[Keys[y]]] + moved[size[Keys[kept]]] + size[Keys[touched]] / 70, size[Keys[kept]]}];
                kept
            ]
        ]],
        node /@ children
    ];
    terms = Reap[node[tree]][[2]];
    If[terms === {}, {0, 0}, {Total[terms[[1, All, 1]]], Max[terms[[1, All, 2]]]}]
]

(* optimizer-format path (both operands removed, result appended) to a tree over the vertices *)
poPathToTree[path_, vertices_] := First @ Fold[
    Function[{trees, step}, Append[Delete[trees, List /@ step], If[Length[step] == 2, trees[[step]], trees[[First[step]]]]]],
    List /@ vertices,
    path
]

poGreedyTree[data_, opts___] := poPathToTree[GreedyContractionPath[Sequence @@ extractContractionParameters[data], opts], data["Vertices"]]

(* the Automatic plan as the paclet would run it: {network (given or reduced), tree} *)
poAutomaticPlan[data_] := poPrivate["automaticPlan"][data, "ArrayDot"]

$poQualityNetworks = <|
    "PEPS 3x3 chi 2" -> poPepsShape[{3, 3}, 2],
    "PEPS 3x3 chi 3" -> poPepsShape[{3, 3}, 3],
    "PEPS 3x4 chi 3" -> poPepsShape[{3, 4}, 3],
    "PEPS 4x4 chi 2" -> poPepsShape[{4, 4}, 2],
    "PEPS 4x4 chi 3" -> poPepsShape[{4, 4}, 3],
    "Brickwork 10x10" -> poBrickworkShape[10, 10],
    "Brickwork 14x12" -> poBrickworkShape[14, 12]
|>;

$poQualityData = Map[TensorNetworkData[poShapeNetwork[#, 7]] &, $poQualityNetworks];

(* {price, largest} of plain greedy and of the best of 384 seeded randomized greedy trials
   (memory weight 0.1, 0.3, 1 or 2; temperature 0.01, 0.1 or 0.5; seeds 1 to 32) whose largest
   result is within 4x greedy's, the window the planner accepts. The paclet's price screens the
   trials down to the ten cheapest; the count here prices those, so the best is a plan that
   exists at the price counted here. *)
poReference[data_] := With[{
    parameters = extractContractionParameters[data],
    greedy = poTreePrice[data, poGreedyTree[data]]
},
    With[{
        paths = Flatten[Table[
            GreedyContractionPath[Sequence @@ parameters, "MemoryWeight" -> w, "Temperature" -> t, "RandomSeed" -> k],
            {k, 32}, {w, {0.1, 0.3, 1., 2.}}, {t, {0.01, 0.1, 0.5}}
        ], 2],
        costInput = poPrivate["pathCostInput"][parameters]
    },
        With[{priced = poTreePrice[data, poPathToTree[#, data["Vertices"]]] & /@ TakeSmallestBy[paths, First[poPrivate["pathCost"][#, costInput]] &, 10]},
            <|"Greedy" -> greedy, "Best" -> MinimalBy[Select[priced, Last[#] <= 4 Last[greedy] &], First][[1]]|>
        ]
    ]
]

$poReference = poReference /@ $poQualityData;

(* the count here and the paclet's own pricing agree on greedy's plan *)
VerificationTest[
    Map[
        Function[data, With[{parameters = extractContractionParameters[data]},
            With[{mine = poTreePrice[data, poGreedyTree[data]], theirs = poPrivate["pathCost"][GreedyContractionPath @@ parameters, poPrivate["pathCostInput"][parameters]]},
                Abs[First[mine] - First[theirs]] <= 10^-9 First[mine] && Last[mine] == Last[theirs]
            ]
        ]],
        Values[$poQualityData]
    ],
    ConstantArray[True, Length[$poQualityData]],
    TestID -> "PlanQuality_PriceCountAgrees"
]

(* the planner's own policy, no memory limit: never priced above plain greedy, and its
   largest result within 4x of greedy's *)
VerificationTest[
    Select[
        Keys[$poQualityData],
        Function[name, With[{plan = poPinned[poAutomaticPlan[$poQualityData[name]]], greedy = $poReference[name, "Greedy"]},
            With[{price = poTreePrice @@ plan},
                ! (First[price] <= (1 + 10^-9) First[greedy] && Last[price] <= 4 Last[greedy])
            ]
        ]]
    ],
    {},
    TestID -> "PlanQuality_NoWorseThanGreedy"
]

(* the planner's own policy on the networks whose plain greedy plan is expensive enough to
   search: within 8x of the best of the 384 trials run here. Trials stop once they would cost
   more than the plan they have found, so one round of 16 may be all a small network gets; it
   lands about 6x from the best on the 4x4 PEPS with chi 3. A search allowed only a tenth of
   the contraction's time ran no trials there and kept a plan about 90x the best. Lists the
   networks that miss, with the ratio. *)
VerificationTest[
    Select[
        Map[
            Function[name, With[{plan = poPinned[poAutomaticPlan[$poQualityData[name]]]},
                name -> First[poTreePrice @@ plan] / First[$poReference[name, "Best"]]
            ]],
            Select[Keys[$poQualityData], First[$poReference[#, "Greedy"]] > 2.^16 Length[$poQualityData[#]["Tensors"]] &]
        ],
        Last[#] > 8 &
    ],
    {},
    TestID -> "PlanQuality_OwnPolicyNearBestTrial"
]

(* the search itself, given time (trials always within the allowance, at most 496): within
   2x of the best of the 384 trials run here *)
VerificationTest[
    Select[
        Keys[$poQualityData],
        Function[name, With[{plan = poSearching[poAutomaticPlan[$poQualityData[name]], Infinity, 496]},
            First[poTreePrice @@ plan] > 2 First[$poReference[name, "Best"]]
        ]]
    ],
    {},
    TestID -> "PlanQuality_SearchNearBestTrial"
]

(* a pinned memory budget below greedy's largest result: the plan's largest fits under it *)
VerificationTest[
    Map[
        Function[{name, budget}, With[{plan = poPinned[poAutomaticPlan[$poQualityData[name]], budget]},
            {Last[$poReference[name, "Greedy"]] > budget, Last[poTreePrice @@ plan] <= budget}
        ]] @@ # &,
        {{"PEPS 4x4 chi 3", 2^17}, {"PEPS 4x4 chi 3", 2^16}}
    ],
    ConstantArray[{True, True}, 2],
    TestID -> "PlanQuality_FitsPinnedBudget"
]

(* the same with the search forced on networks cheap enough that the planner would not
   search by itself *)
VerificationTest[
    Map[
        Function[{name, budget}, With[{plan = poSearching[poAutomaticPlan[$poQualityData[name]], budget, 4096]},
            {Last[$poReference[name, "Greedy"]] > budget, Last[poTreePrice @@ plan] <= budget}
        ]] @@ # &,
        {{"PEPS 3x4 chi 3", 2^11}, {"PEPS 4x4 chi 2", 2^9}, {"Brickwork 14x12", 2^11}}
    ],
    ConstantArray[{True, True}, 3],
    TestID -> "PlanQuality_SearchingFitsPinnedBudget"
]


(* ------------------------------------------------------------------ *)
(* D. The plan cache: same shape, new values                           *)
(* ------------------------------------------------------------------ *)

(* Two networks of one shape contracted in turn under one cache: both against the oracle,
   the two results different, and one cache entry, so the second was planned from the first's *)
poSameShapeCheck[nets_List] := With[{
    results = poSearching[{
        TensorNetworkContract[TensorNetwork @@ Most[nets[[1]]]],
        TensorNetworkContract[TensorNetwork @@ Most[nets[[2]]]],
        Length[Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache]
    }],
    exactQ = Precision[nets[[1, 1]]] === Infinity
},
    {
        poAgreeQ[results[[1]], poOracle @@ nets[[1]], exactQ],
        poAgreeQ[results[[2]], poOracle @@ nets[[2]], exactQ],
        Normal[results[[1]]] =!= Normal[results[[2]]],
        results[[3]]
    }
]

VerificationTest[
    poSameShapeCheck[{poNetwork[#, "Complex"], poNetwork[#, "Complex", 1]}] & /@ Range[4],
    ConstantArray[{True, True, True, 1}, 4],
    TestID -> "PlanCache_SameShapeNewValues_Complex"
]

VerificationTest[
    poSameShapeCheck[{poNetwork[#, "Rational"], poNetwork[#, "Rational", 1]}] & /@ Range[4],
    ConstantArray[{True, True, True, 1}, 4],
    TestID -> "PlanCache_SameShapeNewValues_Rational"
]

(* sparse leaves then dense ones of the same shape, and the reverse: two shapes to the cache
   (the nonzero pattern is part of it), each result against the oracle *)
VerificationTest[
    {
        poSameShapeCheck[{poNetwork[#, "Sparse"], poNetwork[#, "Complex"]}],
        poSameShapeCheck[{poNetwork[#, "Complex"], poNetwork[#, "Sparse"]}]
    } & /@ Range[3],
    ConstantArray[{{True, True, True, 2}, {True, True, True, 2}}, 3],
    TestID -> "PlanCache_SparseThenDense"
]

(* A network with a COPY tensor (diagonal in its three legs, dimension 4), where the plan
   over the diagonal-reduced network is the cheap one; then the same shape with that tensor
   full. A plan reduced for the first must not be reapplied to the second. *)
poCopyNetwork[seed_, form_] := BlockRandom[SeedRandom[seed]; With[{
    labels = {{1, 2, 3}, {1, 4}, {2, 5}, {3, 6}, {4, 5, 7}, {6, 7, 8}, {8, 9}, {9, 1}, {9, 4}},
    copy = SparseArray[Table[{i, i, i} -> RandomComplex[{-1 - I, 1 + I}], {i, 4}], {4, 4, 4}],
    full = RandomComplex[{-1 - I, 1 + I}, {4, 4, 4}]
},
    {
        Prepend[RandomComplex[{-1 - I, 1 + I}, ConstantArray[4, Length[#]]] & /@ Rest[labels],
            Switch[form, "CopyList", Normal[copy], "CopySparse", copy, "FullList", full, "FullSparse", SparseArray[full]]
        ],
        labels, {7}, AssociationMap[4 &, Range[9]]
    }
]]

(* the first network's plan is a reduced one *)
VerificationTest[
    poSearching[
        TensorNetworkContract[TensorNetwork @@ Most[poCopyNetwork[1, "CopyList"]]];
        Values[Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache][[All, 1]]
    ],
    {"Reduced"},
    TestID -> "PlanCache_CopyNetworkPlansReduced"
]

VerificationTest[
    {
        poSameShapeCheck[{poCopyNetwork[1, "CopyList"], poCopyNetwork[2, "FullList"]}],
        poSameShapeCheck[{poCopyNetwork[1, "CopySparse"], poCopyNetwork[2, "FullSparse"]}],
        poSameShapeCheck[{poCopyNetwork[1, "FullList"], poCopyNetwork[2, "CopyList"]}]
    },
    ConstantArray[{True, True, True, 2}, 3],
    TestID -> "PlanCache_ReducedPlanNotReusedForFullTensor"
]


(* ------------------------------------------------------------------ *)
(* E. Plan keys, memory-driven trials and the NetGraph path            *)
(* ------------------------------------------------------------------ *)

(* Dense leaves without a zero share one cache entry across new values; a single zero entry
   changes the zero pattern and gets its own; every value matches the explicit trace *)
VerificationTest[
    BlockRandom[SeedRandom[301]; Block[{Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache = <||>},
        With[{
            ring = TensorNetwork[#, Table[{k, Mod[k, 9] + 1}, {k, 9}]] &,
            first = RandomReal[{1, 2}, {9, 3, 3}], second = RandomReal[{1, 2}, {9, 3, 3}]
        }, With[{withZero = ReplacePart[second, {1, 1, 1} -> 0.]},
            {
                Abs[TensorNetworkContract[ring[first]] - Tr[Dot @@ first]] < 10^-9 Abs[Tr[Dot @@ first]],
                Abs[TensorNetworkContract[ring[second]] - Tr[Dot @@ second]] < 10^-9 Abs[Tr[Dot @@ second]],
                Length[Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache],
                Abs[TensorNetworkContract[ring[withZero]] - Tr[Dot @@ withZero]] < 10^-9 Abs[Tr[Dot @@ withZero]],
                Length[Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache]
            }
        ]]
    ]],
    {True, True, 1, True, 2},
    TestID -> "PlanCache_DenseLeavesWithoutZeros"
]

(* With no plan able to fit the memory budget, trials stop after three rounds in a row that do
   not lower the largest intermediate, well before the 4096-trial cap *)
VerificationTest[
    With[{data = $poQualityData["PEPS 3x3 chi 3"]},
        With[{parameters = extractContractionParameters[data]},
            With[{count = Length[poPrivate["randomGreedyPlans"][parameters, poPrivate["pathCostInput"][parameters], 1., Infinity, 1]]},
                16 <= count < 4096
            ]
        ]
    ],
    True,
    TestID -> "Planner_MemoryRoundsStopWithoutProgress"
]

(* The "NetGraph" method without a path plans with the array methods' search, never the
   exhaustive optimal one, and the net computes the trace of the ring *)
VerificationTest[
    BlockRandom[SeedRandom[302]; With[{ms = RandomReal[{-1, 1}, {6, 3, 3}]},
        Block[{OptimalContractionPath = Function[Throw["exhaustive search", poNetPath]]},
            Catch[
                Abs[TensorNetworkContract[TensorNetwork[ms, Table[{k, Mod[k, 6] + 1}, {k, 6}]], Method -> "NetGraph"] - Tr[Dot @@ ms]] < 10^-5,
                poNetPath
            ]
        ]
    ]],
    True,
    TestID -> "NetGraph_DefaultPathWithoutExhaustiveSearch"
]

(* A round that finds nothing smaller does not end the memory-driven search: on a 3-regular
   graph of 26 tensors the second round finds a plan within a budget the first round missed *)
VerificationTest[
    With[{tn = BlockRandom[SeedRandom[4]; RandomTensorNetwork[RandomGraph[DegreeGraphDistribution[ConstantArray[3, 26]]], {2}]]},
        With[{parameters = extractContractionParameters[TensorNetworkData[tn]]},
            Min[poPrivate["randomGreedyPlans"][parameters, poPrivate["pathCostInput"][parameters], 1., 64., 32.][[All, 2, 2]]] <= 32
        ]
    ],
    True,
    TestID -> "Planner_MemoryRoundsSurviveOneStall"
]
