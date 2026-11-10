(* Tests/external_validation/paclet_primitives/cotengra_benchmarks.wl

Tier-2 direct-validation tests against cotengra. Every test cites a specific
numerical value from the cotengra catalog and asserts the paclet's
OptimalContractionPath / GreedyContractionPath produces that value.

The pathCost helper from contraction_paths.wl is needed; this file Get's it
explicitly to avoid relying on tier-file load order.
*)

Module[{worktreeRoot},
    worktreeRoot = SelectFirst[
        NestList[ParentDirectory, Directory[], 12],
        FileExistsQ[FileNameJoin[{#, "TensorNetworks", "PacletInfo.wl"}]] &,
        $Failed];
    If[worktreeRoot === $Failed,
        Print["[paclet-cotengra] cannot find worktree root from ", Directory[]];
        Abort[];
    ];
    Get[FileNameJoin[{worktreeRoot, "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}]];
];
ClearValidationRecords[];

(* ----- T1: 4-tensor demo, optimal flops cost = 4656
   Source: cotengra docs/basics.ipynb (catalog cotengra_examples.md item 21)
   Inputs: T1[a,b,x] (4,5,2), T2[b,c,d] (5,6,7), T3[c,e,y] (6,8,3), T4[e,a,d] (8,4,7)
   Output: rank-2 (x, y) of dims (2, 3).
   cotengra HyperOptimizer reports tree.contraction_cost() == 4656 with path
   ((0,1),(1,2),(0,1)). *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-cotengra-T1-4tensor-cost-4656",
    "cotengra docs/basics.ipynb (4-tensor demo)",
    VerificationTest[
        Module[{tn, ts, shapes, sd, path, cost},
            sd = <|"a" -> 4, "b" -> 5, "c" -> 6, "d" -> 7, "e" -> 8, "x" -> 2, "y" -> 3|>;
            shapes = {{"a", "b", "x"}, {"b", "c", "d"}, {"c", "e", "y"}, {"e", "a", "d"}};
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            cost = pathCost[shapes, sd, path];
            cost === 4656
        ],
        True,
        TestID -> "paclet-cotengra-T1-4tensor-cost-4656"
    ]
];

(* ----- T2: the 4-tensor demo with complex random tensors, output asked for as (y, x):
   the contracted array equals the explicit sum over a, b, c, d, e written out here.
   Source: cotengra docs/basics.ipynb (same network as T1). *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-cotengra-T2-4tensor-result",
    "cotengra docs/basics.ipynb (4-tensor demo); explicit index sum",
    VerificationTest[
        Module[{shapes, sd, t1, t2, t3, t4, ref, result},
            sd = <|"a" -> 4, "b" -> 5, "c" -> 6, "d" -> 7, "e" -> 8, "x" -> 2, "y" -> 3|>;
            shapes = {{"a", "b", "x"}, {"b", "c", "d"}, {"c", "e", "y"}, {"e", "a", "d"}};
            {t1, t2, t3, t4} = BlockRandom[SeedRandom[211];
                RandomComplex[{-1 - I, 1 + I}, Lookup[sd, #]] & /@ shapes];
            ref = Table[
                Sum[t1[[a, b, x]] t2[[b, c, d]] t3[[c, e, y]] t4[[e, a, d]], {a, 4}, {b, 5}, {c, 6}, {d, 7}, {e, 8}],
                {y, 3}, {x, 2}];
            result = TensorNetworkContract[TensorNetwork[{t1, t2, t3, t4}, shapes -> {"y", "x"}]];
            Dimensions[result] === {3, 2} &&
                Max[Abs[Flatten[result - ref]]] <= 1.*^-10 Max[Abs[Flatten[ref]]]
        ],
        True,
        TestID -> "paclet-cotengra-T2-4tensor-result"
    ]
];

(* ----- T3: 4-tensor demo, optimal path matches cotengra structure.
   cotengra returns ((0,1),(1,2),(0,1)) (opt_einsum 0-indexed) which in
   paclet's 1-indexed form is {{1,2},{2,3},{1,2}}. Network has a symmetry
   between T1<->T3 and T2<->T4 (indices x<->y can be swapped). The optimizer
   may pick a symmetry-equivalent path. We accept any of the equivalent
   permutations. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-cotengra-T3-4tensor-path-shape",
    "cotengra docs/basics.ipynb (path = ((0,1),(1,2),(0,1)))",
    VerificationTest[
        Module[{tn, ts, shapes, sd, path, expected1, expected2},
            sd = <|"a" -> 4, "b" -> 5, "c" -> 6, "d" -> 7, "e" -> 8, "x" -> 2, "y" -> 3|>;
            shapes = {{"a", "b", "x"}, {"b", "c", "d"}, {"c", "e", "y"}, {"e", "a", "d"}};
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            expected1 = {{1, 2}, {2, 3}, {1, 2}};       (* cotengra's path, paclet 1-indexed *)
            expected2 = {{3, 4}, {2, 3}, {1, 2}};       (* T3<->T1, T4<->T2 swap symmetry *)
            path === expected1 || path === expected2
        ],
        True,
        TestID -> "paclet-cotengra-T3-4tensor-path-shape"
    ]
];

(* ----- T4: edgesort path on chain inputs=[(3,2),(2,1),(1,0)] all bond=2
   Source: cotengra tests/test_paths_basic.py:221-243
   cotengra's edgesort optimizer returns the deterministic path
   ((1,2),(0,1)) which in paclet 1-indexed is {{2,3},{1,2}}.
   The paclet doesn't expose edgesort directly, but optimal/greedy on this
   chain should give a path of length 2 contracting in the right order. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork", "TensorNetworkContract"},
    "paclet-cotengra-T4-chain-bond2-cost",
    "cotengra tests/test_paths_basic.py:221-243 (edgesort chain)",
    VerificationTest[
        Module[{tn, ts, shapes, sd, path, cost},
            sd = <|"e0" -> 2, "e1" -> 2, "e2" -> 2, "e3" -> 2|>;
            shapes = {{"e3", "e2"}, {"e2", "e1"}, {"e1", "e0"}};
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            cost = pathCost[shapes, sd, path];
            (* Chain a-b-c with all bond=2:
                 step 1 union dims = 2*2*2 = 8 (3 unique)
                 step 2 union dims = 2*2*2 = 8 (3 unique: 2 surviving from step 1
                                                + 1 new from c)
               Total = 16. *)
            Length[path] === 2 && cost === 16
        ],
        True,
        TestID -> "paclet-cotengra-T4-chain-bond2-cost"
    ]
];

(* ----- T5: 5-tensor closed cycle a-b-c-d-e-a, all bond=2
   Closed pentagon: each tensor has 2 indices, all dim 2; total flops?
   For path of length 4 contracting pairs in order:
     Step 1 (a,b): {i1,i2,i3} dims = 2*2*2 = 8
     Step 2 (ab,c): {i1,i3,i4} dims = 2*2*2 = 8
     Step 3 ((abc),d): {i1,i4,i5} dims = 2*2*2 = 8
     Step 4 (last pair to scalar): {i1,i5} dims = 2*2 = 4
     Total = 28.
   Closed network of all-ones 2x2 matrices -> Tr(M^5) where M=[[1,1],[1,1]].
   M^k = [[2^(k-1),2^(k-1)],[2^(k-1),2^(k-1)]] -> Tr(M^5) = 2 * 2^4 = 32. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork", "TensorNetworkContract"},
    "paclet-cotengra-T5-pentagon-cost-28",
    "cotengra tests/test_paths_basic.py (closed-cycle hand-computed)",
    VerificationTest[
        Module[{tn, ts, shapes, sd, path, cost, result},
            sd = <|"i1" -> 2, "i2" -> 2, "i3" -> 2, "i4" -> 2, "i5" -> 2|>;
            shapes = {{"i1", "i2"}, {"i2", "i3"}, {"i3", "i4"}, {"i4", "i5"}, {"i5", "i1"}};
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            cost = pathCost[shapes, sd, path];
            result = TensorNetworkContract[tn];
            cost === 28 && ValidationClose[result, 32.0, 1.*^-9]
        ],
        True,
        TestID -> "paclet-cotengra-T5-pentagon-cost-28"
    ]
];

(* ----- T6: lattice[4,5] d_max=3 seed=42 cost=1464
   cotengra's tests/test_paths_basic.py:194-205 asserts optimize_optimal cost == 1464.
   The seed=42 RNG selects per-edge dim 2 vs 3 in cotengra. We promote the
   former skip to a direct-validation test by loading the actual (inputs,
   size_dict) extracted offline from cotengra into a JSON fixture; the paclet
   must then reach the same optimal cost from the identical network. *)
WithCapability[{"TensorNetwork", "OptimalContractionPath"},
    "paclet-cotengra-T6-lattice45-seed42",
    "cotengra tests/test_paths_basic.py:194-205 (fixture: external_oracles/fixtures/cotengra_lattice45_seed42.json)",
    VerificationTest[
        Module[{fixture, shapes, sd, ts, tn, path, cost, expected},
            fixture = Import[OracleFixturePath["cotengra_lattice45_seed42.json"], "RawJSON"];
            shapes = fixture["inputs"];
            sd = Association @ KeyValueMap[Rule, fixture["size_dict"]];
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            cost = pathCost[shapes, sd, path];
            expected = fixture["expected_optimal_flops"];
            cost === expected
        ],
        True,
        TestID -> "paclet-cotengra-T6-lattice45-seed42"
    ]
];

(* ----- T7: Sycamore m=20 (381 tensors / 754 legs): CanonicalPath of cotengra's greedy
   path (fixture) must describe the same contraction tree, so walking the canonical
   path must give exactly the total flops cotengra reports for its own path. The walk
   is the opt_einsum mul-count convention, computed by this suite's pathCost helper,
   which T1, T5 and T6 tie to cotengra's numbers.
   Source: cotengra examples/benchmarks/sycamore_n53_m20_s0_e0_pABCDCDAB.json. *)
WithCapability[{"CanonicalPath"},
    "paclet-cotengra-T7-sycamore-m20",
    "cotengra examples/benchmarks/sycamore_n53_m20_s0_e0_pABCDCDAB.json (fixture: external_oracles/fixtures/cotengra_sycamore_m20.json)",
    VerificationTest[
        Module[{fixture, shapes, sd, pathWL, canonical},
            fixture = Import[OracleFixturePath["cotengra_sycamore_m20.json"], "RawJSON"];
            shapes = fixture["inputs"];
            sd = Association @ KeyValueMap[Rule, fixture["size_dict"]];
            pathWL = Map[# + 1 &, fixture["path"], {2}];       (* cotengra is 0-indexed *)
            canonical = CanonicalPath[pathWL];
            canonical =!= pathWL &&
                Length[canonical] === Length[pathWL] &&
                pathCost[shapes, sd, canonical] === fixture["expected_total_flops"]
        ],
        True,
        TestID -> "paclet-cotengra-T7-sycamore-m20"
    ]
];
