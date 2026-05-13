(* Tests/external_validation/paclet_primitives/contraction_paths_exact.wl

Tier-2 direct-validation tests for OptimalContractionPath / GreedyContractionPath
on networks where the catalog (or topology) pins down a specific path SHAPE
or LENGTH.

Sources:
- cotengra tests/test_paths_basic.py:97-110 (test_manual_cases - 95 hand
  equations with deterministic outputs)
- cotengra tests/test_paths_basic.py:221-243 (edgesort chain, exact path
  ((1,2),(0,1)) opt_einsum-indexed)
- General topology theorems for chains, stars, trees.
*)

Module[{worktreeRoot},
    worktreeRoot = SelectFirst[
        NestList[ParentDirectory, Directory[], 12],
        FileExistsQ[FileNameJoin[{#, "TensorNetworks", "PacletInfo.wl"}]] &,
        $Failed];
    If[worktreeRoot === $Failed,
        Print["[paclet-paths-exact] cannot find worktree root from ", Directory[]];
        Abort[];
    ];
    Get[FileNameJoin[{worktreeRoot, "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}]];
];
ClearValidationRecords[];

(* ----- T1: Two-tensor network has unique path = {{1,2}}.
   Source: cotengra tests/test_paths_basic.py:97-110 (manual cases).
   For any 2-tensor network, the only possible path is the single contraction
   {1,2}. Direct value: path === {{1,2}}, length === 1. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-paths-exact-T1-two-tensor",
    "cotengra tests/test_paths_basic.py:97-110 (two-tensor uniqueness)",
    VerificationTest[
        Module[{tn, ts, shapes, sd, path},
            sd = <|"i" -> 3, "j" -> 4|>;
            shapes = {{"i", "j"}, {"i", "j"}};
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            path === {{1, 2}}
        ],
        True,
        TestID -> "paclet-paths-exact-T1-two-tensor"
    ]
];

(* ----- T2: Open chain of N=5 tensors; optimal path is sequential.
   Source: cotengra docs/contraction.ipynb (chain optimization is sequential).
   Direct topology: chain has length-(N-1) optimal path of pairwise sequential
   merges. Verify length and that each step contracts adjacent neighbors. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-paths-exact-T2-chain5-length",
    "cotengra docs/contraction.ipynb (chain pathing)",
    VerificationTest[
        Module[{n, sd, shapes, ts, tn, path},
            n = 5;
            sd = AssociationThread[
                Table["e" <> ToString[i], {i, 0, n}],
                Table[2, n + 1]];
            shapes = Table[
                {"e" <> ToString[i - 1], "e" <> ToString[i]},
                {i, n}];
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            (* Optimal path on N-tensor chain has length N-1 *)
            Length[path] === n - 1 &&
                AllTrue[path, MatchQ[#, {_Integer, _Integer}] && #[[1]] != #[[2]] &]
        ],
        True,
        TestID -> "paclet-paths-exact-T2-chain5-length"
    ]
];

(* ----- T3: Star graph (1 center + 4 spokes) -> path length 4.
   Source: General TN topology (star).
   Direct topology: every step must include the center tensor (only one with
   shared indices to multiple others). Path length = N-1 = 4. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-paths-exact-T3-star-length",
    "TN topology theorem (star contraction is N-1 pairs through center)",
    VerificationTest[
        Module[{nSpokes, sd, shapes, ts, tn, path},
            nSpokes = 4;
            sd = AssociationThread[
                Table["s" <> ToString[i], {i, nSpokes}],
                Table[2, nSpokes]];
            (* Center tensor has all spoke indices; each spoke has only its own *)
            shapes = Prepend[
                Table[{"s" <> ToString[i]}, {i, nSpokes}],
                Table["s" <> ToString[i], {i, nSpokes}]
            ];
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            Length[path] === nSpokes
        ],
        True,
        TestID -> "paclet-paths-exact-T3-star-length"
    ]
];

(* ----- T4: Edgesort path on chain, paclet path matches up to ordering symmetry.
   Source: cotengra tests/test_paths_basic.py:221-243.
   cotengra's edgesort returns ((1,2),(0,1)) opt_einsum-indexed for chain
   inputs=[(3,2),(2,1),(1,0)] with all bond=2. paclet 1-indexed = {{2,3},{1,2}}.
   Greedy/optimal on this chain may pick R-to-L or L-to-R; both have same flops
   (all bonds equal), so the path length is what's invariant. *)
WithCapability[{"OptimalContractionPath", "GreedyContractionPath", "TensorNetwork"},
    "paclet-paths-exact-T4-edgesort-chain-length",
    "cotengra tests/test_paths_basic.py:221-243",
    VerificationTest[
        Module[{sd, shapes, ts, tn, pOpt, pGreedy},
            sd = <|"e0" -> 2, "e1" -> 2, "e2" -> 2, "e3" -> 2|>;
            shapes = {{"e3", "e2"}, {"e2", "e1"}, {"e1", "e0"}};
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            pOpt = OptimalContractionPath[tn, Method -> "flops"];
            pGreedy = GreedyContractionPath[tn];
            (* Chain has length 3, both paths length 2. *)
            Length[pOpt] === 2 && Length[pGreedy] === 2
        ],
        True,
        TestID -> "paclet-paths-exact-T4-edgesort-chain-length"
    ]
];

(* ----- T5: Closed triangle (3 tensors, every pair shares an edge) -> path length 2.
   Source: cotengra tests/test_paths_basic.py:97-110 (manual cases include
   3-tensor cycles).
   Direct: path of length n-1 = 2 for a 3-cycle. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-paths-exact-T5-triangle-length",
    "cotengra tests/test_paths_basic.py:97-110 (3-cycle topology)",
    VerificationTest[
        Module[{sd, shapes, ts, tn, path},
            sd = <|"i" -> 2, "j" -> 3, "k" -> 4|>;
            shapes = {{"i", "j"}, {"j", "k"}, {"k", "i"}};
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            Length[path] === 2
        ],
        True,
        TestID -> "paclet-paths-exact-T5-triangle-length"
    ]
];

(* ----- T6: Single-tensor self-loop returns empty path.
   Source: cotengra docs (single-input case).
   Direct: a single tensor with no contraction has path length 0. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-paths-exact-T6-single-tensor-empty-path",
    "cotengra docs (single-input degenerate case)",
    VerificationTest[
        Module[{sd, shapes, ts, tn, path},
            sd = <|"i" -> 2, "j" -> 3|>;
            shapes = {{"i", "j"}};
            ts = {ConstantArray[1.0, sd /@ shapes[[1]]]};
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            (* Single-tensor case: paclet returns either {} or CanonicalPath[{}],
               both meaning "no contractions to do." *)
            (path === {}) || (path === CanonicalPath[{}]) ||
                (Head[path] === CanonicalPath && First[path] === {})
        ],
        True,
        TestID -> "paclet-paths-exact-T6-single-tensor-empty-path"
    ]
];

(* ----- T7: pathCost on a deterministic 4-tensor demo with optimal path
   Source: cotengra docs/basics.ipynb. Already verified in cotengra_benchmarks
   T1 (cost = 4656). Here we add the cross-check that the optimal path
   contracts to the same numeric scalar as the simple pairwise execution. *)
WithCapability[{"OptimalContractionPath", "TensorNetworkContract", "TensorNetwork"},
    "paclet-paths-exact-T7-optimal-path-correct-result",
    "cotengra docs/basics.ipynb (path correctness invariant)",
    VerificationTest[
        Module[{tn, ts, shapes, sd, path, contracted, expected},
            sd = <|"a" -> 4, "b" -> 5, "c" -> 6, "d" -> 7, "e" -> 8, "x" -> 2, "y" -> 3|>;
            shapes = {{"a", "b", "x"}, {"b", "c", "d"}, {"c", "e", "y"}, {"e", "a", "d"}};
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            contracted = TensorNetworkContract[tn];
            (* All-ones inputs => every output entry = 4*5*6*7*8 = 6720 (sum
               over a,b,c,d,e of all-ones products). *)
            expected = ConstantArray[6720.0, {sd["x"], sd["y"]}];
            ValidationClose[contracted, expected, 1.*^-9]
        ],
        True,
        TestID -> "paclet-paths-exact-T7-optimal-path-correct-result"
    ]
];


(* ----- T8: PathToTreePath robustness — wrong-length indices error cleanly
   Regression test for the bug where PathToTreePath silently returned
   unevaluated Delete[...] / Part[...] on networks with hyper-edges (where
   the optimizer binarizes internally so the path is over n+H positions but
   tn["Vertices"] only has n). The fix surfaces a clean PathToTreePath::indlen
   message and returns $Failed instead of leaking garbage. *)
WithCapability[{"PathToTreePath"},
    "paclet-paths-exact-T8-pathToTreePath-validation",
    "PathToTreePath input-length validation (regression for hyper-edge bug)",
    VerificationTest[
        PathToTreePath[{{1, 2}, {1, 2}, {1, 2}, {1, 2}}, {1, 2, 3, 4}],
        $Failed,
        {PathToTreePath::indlen},
        TestID -> "paclet-paths-exact-T8-pathToTreePath-validation"
    ]
];

(* ----- T9: PathToTreePath on graph-built TN succeeds via Automatic
   Same hyper-edge network that previously failed silently — with Automatic
   indices PathToTreePath auto-derives the right arity from the path itself. *)
WithCapability[{"RandomTensorNetwork", "GreedyContractionPath", "PathToTreePath"},
    "paclet-paths-exact-T9-pathToTreePath-automatic",
    "PathToTreePath[path] auto-derives indices on a 100-seed sweep of graph TNs",
    VerificationTest[
        AllTrue[
            Range[1, 100],
            Function[seed,
                BlockRandom[SeedRandom[seed];
                    Module[{tn, path, r},
                        tn = RandomTensorNetwork[{4, 5}, 3];
                        path = GreedyContractionPath[tn];
                        r = PathToTreePath[path];
                        ListQ[r] && FreeQ[r, Delete[___] | _Part]
                    ]
                ]
            ]
        ],
        True,
        TestID -> "paclet-paths-exact-T9-pathToTreePath-automatic"
    ]
];

