(* The evaluated contraction routes chosen by shape: real times complex as one real product,
   batch steps with large and small blocks, and the Automatic planner's choice of plan.
   Contraction values are checked against products computed here, outside the paclet;
   plan choices against the paclet's own path prices. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

$contractionPrivate = "Wolfram`TensorNetworks`Contraction`PackagePrivate`";
private[name_] := Symbol[$contractionPrivate <> name];

relativeError[x_, ref_] := Max[Abs[Flatten[{Normal[x] - ref}]]] / Max[Abs[Flatten[{ref}]]];


(* ------------------------------------------------------------------ *)
(* A. A real operand meeting a complex one, summed length 16 or more   *)
(* ------------------------------------------------------------------ *)

(* real {30, 32} times complex {32, 7}: the complex side is split *)
VerificationTest[
    BlockRandom[SeedRandom[101]; With[{x = RandomReal[{-1, 1}, {30, 32}], y = RandomComplex[{-1 - I, 1 + I}, {32, 7}]},
        relativeError[TensorNetworkContract[TensorNetwork[{x, y}, {{1, 2}, {2, 3}}, {1, 3}], {{1, 2}}], x . y] < 10^-12
    ]],
    True,
    TestID -> "FastPath_RealTimesComplex"
]

(* complex {30, 32} times real {32, 7}: the complex side is the left one *)
VerificationTest[
    BlockRandom[SeedRandom[102]; With[{x = RandomComplex[{-1 - I, 1 + I}, {30, 32}], y = RandomReal[{-1, 1}, {32, 7}]},
        relativeError[TensorNetworkContract[TensorNetwork[{x, y}, {{1, 2}, {2, 3}}, {1, 3}], {{1, 2}}], x . y] < 10^-12
    ]],
    True,
    TestID -> "FastPath_ComplexTimesReal"
]

(* two summed legs (4 x 8 = 32), output reordered, both engines that take the matrix step *)
VerificationTest[
    BlockRandom[SeedRandom[103]; With[{x = RandomReal[{-1, 1}, {6, 4, 8}], y = RandomComplex[{-1 - I, 1 + I}, {4, 8, 5}]},
        With[{ref = Transpose[ArrayReshape[ArrayReshape[x, {6, 32}] . ArrayReshape[y, {32, 5}], {6, 5}]]},
            relativeError[TensorNetworkContract[TensorNetwork[{x, y}, {{1, 2, 3}, {2, 3, 4}}, {4, 1}], {{1, 2}}, Method -> #], ref] < 10^-12 & /@ {"ArrayDot", "Dot"}
        ]
    ]],
    {True, True},
    TestID -> "FastPath_RealTimesComplexTwoLegsReordered"
]


(* ------------------------------------------------------------------ *)
(* B. Batch steps: a label both operands keep for the output or later  *)
(* ------------------------------------------------------------------ *)

(* {b, i, s} with {b, s, k} to {b, i, k}: blocks 4 x 5 by 5 x 6, one product per entry *)
VerificationTest[
    BlockRandom[SeedRandom[201]; With[{a = RandomInteger[{-9, 9}, {3, 4, 5}], b = RandomInteger[{-9, 9}, {3, 5, 6}]},
        TensorNetworkContract[TensorNetwork[{a, b}, {{1, 2, 3}, {1, 3, 4}}, {1, 2, 4}], {{1, 2}}] ===
            Table[a[[n]] . b[[n]], {n, 3}]
    ]],
    True,
    TestID -> "FastPath_BatchLargeBlocks"
]

(* the same with the batch label last in the requested output *)
VerificationTest[
    BlockRandom[SeedRandom[202]; With[{a = RandomInteger[{-9, 9}, {3, 4, 5}], b = RandomInteger[{-9, 9}, {3, 5, 6}]},
        TensorNetworkContract[TensorNetwork[{a, b}, {{1, 2, 3}, {1, 3, 4}}, {4, 2, 1}], {{1, 2}}] ===
            Transpose[Table[a[[n]] . b[[n]], {n, 3}], {3, 2, 1}]
    ]],
    True,
    TestID -> "FastPath_BatchLargeBlocksReordered"
]

(* a hyperedge through three tensors, kept for the output: a batched chain product *)
VerificationTest[
    BlockRandom[SeedRandom[203]; With[{
        a = RandomInteger[{-5, 5}, {3, 4, 5}], b = RandomInteger[{-5, 5}, {3, 5, 6}], c = RandomInteger[{-5, 5}, {3, 6, 4}]
    },
        With[{tn = TensorNetwork[{a, b, c}, {{1, 2, 3}, {1, 3, 4}, {1, 4, 5}}, {1, 2, 5}], ref = Table[a[[n]] . b[[n]] . c[[n]], {n, 3}]},
            {TensorNetworkContract[tn] === ref, TensorNetworkContract[tn, {{1, 2}, {1, 2}}] === ref, TensorNetworkContract[tn, {{2, 3}, {1, 2}}] === ref}
        ]
    ]],
    {True, True, True},
    TestID -> "FastPath_BatchHyperedgeChain"
]

(* a hyperedge summed only at the last step: the first step keeps it as a batch label *)
VerificationTest[
    BlockRandom[SeedRandom[204]; With[{
        a = RandomInteger[{-5, 5}, {3, 4, 5}], b = RandomInteger[{-5, 5}, {3, 5, 6}], c = RandomInteger[{-5, 5}, {3, 6}]
    },
        TensorNetworkContract[TensorNetwork[{a, b, c}, {{1, 2, 3}, {1, 3, 4}, {1, 4}}, {2}], {{1, 2}, {1, 2}}] ===
            Total[Table[a[[n]] . b[[n]] . c[[n]], {n, 3}]]
    ]],
    True,
    TestID -> "FastPath_BatchSummedLater"
]

(* sparse operands in a batch step with large blocks *)
VerificationTest[
    BlockRandom[SeedRandom[205]; With[{
        a = SparseArray[RandomChoice[{0.7, 0.3} -> {0, 1}, {3, 4, 5}] RandomInteger[{1, 9}, {3, 4, 5}]],
        b = SparseArray[RandomChoice[{0.7, 0.3} -> {0, 1}, {3, 5, 6}] RandomInteger[{1, 9}, {3, 5, 6}]]
    },
        Normal[TensorNetworkContract[TensorNetwork[{a, b}, {{1, 2, 3}, {1, 3, 4}}, {1, 2, 4}], {{1, 2}}]] ===
            Table[Normal[a][[n]] . Normal[b][[n]], {n, 3}]
    ]],
    True,
    TestID -> "FastPath_BatchLargeBlocksSparse"
]

(* blocks of 2 x 2 by 2 x 2: one broadcast multiply and sum over many entries *)
VerificationTest[
    BlockRandom[SeedRandom[206]; With[{a = RandomInteger[{-9, 9}, {50, 2, 2}], b = RandomInteger[{-9, 9}, {50, 2, 2}]},
        TensorNetworkContract[TensorNetwork[{a, b}, {{1, 2, 3}, {1, 3, 4}}, {1, 2, 4}], {{1, 2}}] ===
            Table[a[[n]] . b[[n]], {n, 50}]
    ]],
    True,
    TestID -> "FastPath_BatchSmallBlocks"
]

(* machine numbers in a batch step with large blocks, complex on one side *)
VerificationTest[
    BlockRandom[SeedRandom[207]; With[{a = RandomReal[{-1, 1}, {4, 6, 7}], b = RandomComplex[{-1 - I, 1 + I}, {4, 7, 5}]},
        relativeError[TensorNetworkContract[TensorNetwork[{a, b}, {{1, 2, 3}, {1, 3, 4}}, {1, 2, 4}], {{1, 2}}], Table[a[[n]] . b[[n]], {n, 4}]] < 10^-12
    ]],
    True,
    TestID -> "FastPath_BatchLargeBlocksMachine"
]


(* ------------------------------------------------------------------ *)
(* C. The Automatic planner                                            *)
(* ------------------------------------------------------------------ *)

(* closed PEPS norm: each site tensor and its conjugate, bond labels offset for the bra *)
pepsNorm[{rows_, cols_}, bond_, seed_] := BlockRandom[SeedRandom[seed]; With[{ket = RandomTensorNetwork["PEPS"[{rows, cols}, bond, 2]]},
    With[{offset = Max[Catenate[ket["Hyperedges"]]], physical = ket["FreeIndices"]},
        TensorNetwork[
            Join[ket["Tensors"], Conjugate[ket["Tensors"]]],
            Join[ket["Hyperedges"], Map[If[MemberQ[physical, #], #, # + offset] &, ket["Hyperedges"], {2}]],
            {}
        ]
    ]
]]

priceOf[form_, path_] := With[{parameters = extractContractionParameters[form]},
    private["pathCost"][path, private["pathCostInput"][parameters]]
]

(* the budget is pinned so plans don't depend on the memory free when the test runs *)
plannedCosts[tn_, budget_ : Infinity] := Block[{Wolfram`TensorNetworks`Contraction`PackagePrivate`memoryBudget = (budget &)}, plannedCosts0[tn]]

plannedCosts0[tn_] := With[{data = TensorNetworkData[tn]}, With[{
    parameters = extractContractionParameters[data],
    plan = private["cheapestPlan"][data, extractContractionParameters[data], "ArrayDot"]
},
    {
        priceOf[data, GreedyContractionPath @@ parameters],
        priceOf[First[plan], Last[plan]]
    }
]]

(* with no memory limit the chosen plan is never priced above plain greedy, always a candidate *)
VerificationTest[
    AllTrue[plannedCosts /@ {pepsNorm[{4, 4}, 3, 301], pepsNorm[{5, 5}, 3, 302], pepsNorm[{4, 5}, 4, 303]}, First[Last[#]] <= First[First[#]] &],
    True,
    TestID -> "Planner_NoWorseThanGreedy"
]

(* on a 5 x 5 bond-4 PEPS norm, greedy's largest intermediate is 2^28 entries; the plan's is far smaller *)
VerificationTest[
    With[{costs = plannedCosts[pepsNorm[{5, 5}, 4, 304]]}, Last[Last[costs]] <= Last[First[costs]] / 8],
    True,
    TestID -> "Planner_FindsSmallerIntermediate"
]

(* choosing among priced plans {network, path, {price, largest}}, greedy first:
   cheapest overall without a limit; the cheapest that fits under a limit; with none
   fitting, the smallest intermediate, cheapest among equals *)
VerificationTest[
    With[{
        affordable = private["affordablePlan"],
        plans = {{f, "greedy", {100, 50}}, {f, "cheapBig", {10, 200}}, {f, "mid", {20, 40}}, {f, "fitsPricey", {300, 30}}},
        ties = {{f, "greedy", {100, 50}}, {f, "smallPricey", {90, 30}}, {f, "smallCheap", {60, 30}}},
        tiesCheapFirst = {{f, "greedy", {100, 50}}, {f, "smallCheap", {60, 30}}, {f, "smallPricey", {90, 30}}}
    },
        {
            affordable[plans, 50, Infinity][[2]], affordable[plans, 50, 35][[2]],
            affordable[ties, 50, 10][[2]], affordable[tiesCheapFirst, 50, 10][[2]]
        }
    ],
    {"cheapBig", "fitsPricey", "smallCheap", "smallCheap"},
    TestID -> "Planner_AffordablePlanRules"
]

(* a budget below greedy's largest intermediate (2^28 entries): the plan fits under it *)
VerificationTest[
    With[{costs = plannedCosts[pepsNorm[{5, 5}, 4, 306], 2^26]}, {Last[First[costs]] > 2^26, Last[Last[costs]] <= 2^26}],
    {True, True},
    TestID -> "Planner_FitsMemoryBudget"
]

(* the same network plans the same path twice, and contracts to greedy's value *)
VerificationTest[
    With[{tn = pepsNorm[{4, 4}, 3, 305]}, With[{data = TensorNetworkData[tn]},
        {
            Block[{Wolfram`TensorNetworks`Contraction`PackagePrivate`memoryBudget = (Infinity &)},
                SameQ @@ Table[Last[private["cheapestPlan"][data, extractContractionParameters[data], "ArrayDot"]], 2]
            ],
            Block[{Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache = <||>},
                relativeError[TensorNetworkContract[tn], TensorNetworkContract[tn, GreedyContractionPath[tn]]] < 10^-10
            ]
        }
    ]],
    {True, True},
    TestID -> "Planner_ReproducibleAndCorrect"
]
