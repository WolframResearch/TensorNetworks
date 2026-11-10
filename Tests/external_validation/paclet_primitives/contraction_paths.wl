(* Tests/external_validation/paclet_primitives/contraction_paths.wl

Contraction paths and the values contracted along them, each checked against an
answer computed here without the paclet:

- the value of a network: an explicit sum over every index assignment
  (cpOracle), on complex random tensors with unequal dimensions;
- the flops of a path (sum over steps of the product of the dimensions of both
  operands' labels) and its largest intermediate, by walking the path (cpPathCosts);
- the optimal flops and the optimal largest intermediate, by exhaustive search over
  every order of pairwise contractions (cpBest) or, for 12 tensors, by dynamic
  programming over connected subsets (cpSubsetBest); like the paclet's search, both
  exclude outer products unless asked;
- the greedy path: the same greedy rule as cotengra's (contract the sharing pair with
  the smallest signed log of size(ab)/w - w (size(a) + size(b))), run here with every
  tie-break (cpGreedyCosts), so the paclet's path must cost one of those amounts;
- the price the Automatic planner gives a path, from its documented rule (cpPrice).

Kept unchanged: B2, B3, B6 (values against plain Dot and an explicit sum), Bcost1 and
Bcost2 (hand-computed optimal costs).

Sources:
- cotengra docs/basics.ipynb (4-tensor demo)
- cotengra tests/test_optimizers.py:139-167 (fixture cotengra_hyperopt_bound.json)
- cotengra tests/test_paths_basic.py:97-110, 221-243
- quimb tests/test_tensor_core.py:1095-1101 (chain of (8,8) tensors)
*)

Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "Helpers", "ValidationHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}],
        FileNameJoin[{Directory[], "external_validation", "Helpers", "ValidationHelpers.wl"}],
        FileNameJoin[{Directory[], "Helpers", "ValidationHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed,
        Print["[paclet-paths] ERROR: cannot locate ValidationHelpers.wl. Tried: ", candidates];
        Abort[];
    ];
    Get[found];
];
ClearValidationRecords[];

(* ===================== Independent references ===================== *)

(* agreement to 1e-10 relative to the size of the reference, same dimensions *)
cpClose[x_, y_] := TrueQ[Dimensions[x] === Dimensions[y] && Max[Abs[Flatten[{x - y}]]] <= 1.*^-10 Max[1, Max[Abs[Flatten[{y}]]]]];
(* explicit index sum *)
cpSizes[ts_, shapes_] := Association @ Catenate @ MapThread[Thread[#2 -> Dimensions[#1]] &, {ts, shapes}];
cpEntry[ts_, shapes_, val_] := Times @@ MapThread[Extract[#1, Lookup[val, #2]] &, {ts, shapes}];
cpOracle[ts_, shapes_, out_] := Block[{sd = cpSizes[ts, shapes], internal, tuples, labels, sumAt},
    internal = Complement[DeleteDuplicates[Catenate[shapes]], out];
    tuples = Tuples[Range /@ Lookup[sd, internal]];
    labels = Join[out, internal];
    sumAt[o_List] := Total[cpEntry[ts, shapes, AssociationThread[labels, Join[o, #]]] & /@ tuples];
    If[out === {}, sumAt[{}], Array[sumAt[{##}] &, Lookup[sd, out]]]
];
cpKept[a_, b_, rest_, out_] := Select[Union[a, b], Function[l, MemberQ[out, l] || AnyTrue[rest, MemberQ[#, l] &]]];
cpPathCosts[shapes_, out_, sd_, path_] := Module[{state = Union /@ shapes, flops = 0, largest = 0, a, b, rest, k},
    Scan[Function[step,
        a = state[[step[[1]]]]; b = state[[step[[2]]]]; rest = Delete[state, List /@ step];
        k = cpKept[a, b, rest, out];
        flops += Times @@ Lookup[sd, Union[a, b]];
        largest = Max[largest, Times @@ Lookup[sd, k]];
        state = Append[rest, k]], path];
    {flops, largest}
];
cpBest[shapes_, out_, sd_, objective_, outerQ_ : False] := Module[{rec},
    rec[state_] := rec[state] = If[Length[state] == 1, 0,
        Min @ Map[
            Function[p, With[{a = state[[p[[1]]]], b = state[[p[[2]]]], rest = Delete[state, List /@ p]},
                With[{k = cpKept[a, b, rest, out]},
                    If[objective === "flops",
                        Times @@ Lookup[sd, Union[a, b]] + rec[Sort[Append[rest, k]]],
                        Max[Times @@ Lookup[sd, k], rec[Sort[Append[rest, k]]]]]]]],
            Select[Subsets[Range[Length[state]], {2}], outerQ || IntersectingQ[state[[#[[1]]]], state[[#[[2]]]]] &]]];
    rec[Sort[Union /@ shapes]]
];
(* Rust scores log(sab/w - w(sa+sb)) as a signed log in single precision; a difference
   within rounding of zero can come out at either extreme, so it is marked ambiguous *)
cpGreedyScore[sa_, sb_, sab_, w_] := With[{d = sab / w - w (sa + sb)},
    Which[Abs[d] <= 1.*^-5 (sab / w + w (sa + sb)), None, d > 0, Log[d], True, -Log[-d]]];
cpGreedyCosts[shapes_, out_, sd_, w_] := Module[{rec, size},
    size[l_] := Times @@ Lookup[sd, l];
    rec[state_] := rec[state] = If[Length[state] == 1, {0},
        With[{cands = Map[
                Function[p, With[{a = state[[p[[1]]]], b = state[[p[[2]]]], rest = Delete[state, List /@ p]},
                    With[{k = cpKept[a, b, rest, out]},
                        {cpGreedyScore[size[a], size[b], size[k], w], size[Union[a, b]], Sort[Append[rest, k]]}]]],
                Select[Subsets[Range[Length[state]], {2}], IntersectingQ[state[[#[[1]]]], state[[#[[2]]]]] &]]},
            With[{definite = Select[cands, NumericQ[First[#]] &], ambiguous = Select[cands, First[#] === None &]},
                With[{best = If[definite === {}, None, Min[definite[[All, 1]]]]},
                    Union @@ Map[Function[c, c[[2]] + rec[c[[3]]]],
                        Join[ambiguous, If[best === None, {}, Select[definite, #[[1]] <= best + 1.*^-5 Max[1, Abs[best]] &]]]]]]]];
    rec[Sort[Union /@ shapes]]
];

(* the kernel's plan price, from its documented rule: per step the elements of both operands
   and the result (each doubled past 2^20) plus the flops over 70; a leaf first drops labels
   only it holds; a label survives a step while another tensor or the output holds it *)
cpPrice[shapes_, out_, sd_, path_] := Module[{holders, state, price = 0, largest = 0, w, a, b, k, c},
    holders = Counts[Catenate[DeleteDuplicates /@ shapes]];
    state = Select[DeleteDuplicates[#], Function[l, holders[l] > 1 || MemberQ[out, l]]] & /@ shapes;
    w[s_] := If[s > 2.^20, 2 s, s];
    Scan[Function[step,
        a = state[[step[[1]]]]; b = state[[step[[2]]]];
        k = {};
        Scan[Function[l,
            c = Boole[MemberQ[a, l]] + Boole[MemberQ[b, l]];
            If[holders[l] > c || MemberQ[out, l], holders[l] += 1 - c; AppendTo[k, l], holders[l] -= c]],
            DeleteDuplicates[Join[a, b]]];
        price += w[Times @@ Lookup[sd, a]] + w[Times @@ Lookup[sd, b]] + w[Times @@ Lookup[sd, k]] +
            (Times @@ Lookup[sd, Union[a, b]]) / 70.;
        largest = Max[largest, Times @@ Lookup[sd, k]];
        state = Append[Delete[state, List /@ step], k]], path];
    {price, largest}
];

(* exact optimum by dynamic programming over connected subsets (no outer products) *)
cpSubsetBest[shapes_, out_, sd_] := Module[{n = Length[shapes], legsets = Union /@ shapes, legsOf, best = <||>, all, cost},
    all = 2^n - 1;
    legsOf[s_] := legsOf[s] = With[{inside = Union @@ legsets[[Flatten @ Position[Reverse @ IntegerDigits[s, 2, n], 1]]],
            outside = Union @@ Append[legsets[[Flatten @ Position[Reverse @ IntegerDigits[s, 2, n], 0]]], {}]},
        Select[inside, MemberQ[outside, #] || MemberQ[out, #] &]];
    Scan[(best[2^(# - 1)] = 0) &, Range[n]];
    Scan[Function[s,
        Module[{m = s, a, b, v = Infinity},
            a = BitAnd[s - 1, s];
            While[a > 0,
                b = BitXor[s, a];
                If[a < b && KeyExistsQ[best, a] && KeyExistsQ[best, b] && IntersectingQ[legsOf[a], legsOf[b]],
                    v = Min[v, best[a] + best[b] + Times @@ Lookup[sd, Union[legsOf[a], legsOf[b]]]]];
                a = BitAnd[a - 1, s]];
            If[v < Infinity, best[s] = v]]],
        SortBy[Select[Range[all], DigitCount[#, 2, 1] >= 2 &], DigitCount[#, 2, 1] &]];
    best[all]
];

(* seeded random connected network: spanning tree + extra bonds, optional 3-tensor
   hyperedges, open legs; every open leg is in the output, in random order *)
cpRandomNetwork[seed_, n_, extra_, hyper_, open_, maxTotal_ : 200000] := Module[{try = seed, net},
    While[True,
        net = BlockRandom[SeedRandom[try];
            Module[{legs = ConstantArray[{}, n], k = 0, sd = <||>, add, out = {}},
                add[label_, members_, d_] := (sd[label] = d; Scan[(legs[[#]] = Append[legs[[#]], label]) &, members]);
                Do[add["e" <> ToString[++k], {t, RandomInteger[{1, t - 1}]}, RandomInteger[{2, 4}]], {t, 2, n}];
                Do[add["e" <> ToString[++k], RandomSample[Range[n], 2], RandomInteger[{2, 4}]], {extra}];
                Do[add["h" <> ToString[m], RandomSample[Range[n], 3], RandomInteger[{2, 3}]], {m, hyper}];
                Do[add["o" <> ToString[m], {RandomInteger[{1, n}]}, RandomInteger[{2, 3}]]; AppendTo[out, "o" <> ToString[m]], {m, open}];
                {RandomSample[#] & /@ legs, RandomSample[out], sd}]];
        If[DuplicateFreeQ[Sort /@ net[[1]]] && Times @@ Values[net[[3]]] <= maxTotal && AllTrue[net[[1]], Length[#] <= 5 &],
            Return[net]];
        try += 1000]
];

(* ===================== Networks ===================== *)

(* cotengra's 4-tensor demo, output (x, y) *)
cpDemoShapes = {{"a", "b", "x"}, {"b", "c", "d"}, {"c", "e", "y"}, {"e", "a", "d"}};
cpDemoSizes = <|"a" -> 4, "b" -> 5, "c" -> 6, "d" -> 7, "e" -> 8, "x" -> 2, "y" -> 3|>;

(* 5 tensors with a loop, unequal bonds, one open leg *)
cpFiveShapes = {{"a", "b"}, {"b", "c", "d"}, {"d", "e"}, {"e", "a", "f"}, {"c", "f", "g"}};
cpFiveSizes = <|"a" -> 2, "b" -> 3, "c" -> 4, "d" -> 5, "e" -> 2, "f" -> 3, "g" -> 2|>;

(* 6 tensors where the flops-optimal path is not size-optimal: its largest intermediate
   is 96 while the size optimum is 72 (exhaustive search) *)
cpSplitShapes = {{"e8", "e1", "o1"}, {"o2", "e2", "e1", "e7", "e4"}, {"e2", "e6", "e3"}, {"e3"},
    {"e6", "e7", "e5", "e4"}, {"e5", "e8"}};
cpSplitOut = {"o1", "o2"};
cpSplitSizes = <|"e1" -> 2, "e2" -> 3, "e3" -> 4, "e4" -> 4, "e5" -> 3, "e6" -> 2, "e7" -> 3,
    "e8" -> 4, "o1" -> 3, "o2" -> 2|>;

cpRandomComplex[sd_, shapes_, seed_] := BlockRandom[SeedRandom[seed];
    RandomComplex[{-1 - I, 1 + I}, Lookup[sd, #]] & /@ shapes];

(* ----- B1: on the 4-tensor demo the "flops" path costs the exhaustive minimum, and the
   default path (Method -> "size") has the smallest possible largest intermediate. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"}, "paclet-paths-B1-4tensor-exhaustive",
    "cotengra docs/basics.ipynb (4-tensor demo); exhaustive search over orders",
    VerificationTest[
        Module[{tn},
            tn = TensorNetwork[ConstantArray[1., Lookup[cpDemoSizes, #]] & /@ cpDemoShapes, cpDemoShapes -> {"x", "y"}];
            {
                First @ cpPathCosts[cpDemoShapes, {"x", "y"}, cpDemoSizes, OptimalContractionPath[tn, Method -> "flops"]],
                Last @ cpPathCosts[cpDemoShapes, {"x", "y"}, cpDemoSizes, OptimalContractionPath[tn]]
            } === {
                cpBest[cpDemoShapes, {"x", "y"}, cpDemoSizes, "flops"],
                cpBest[cpDemoShapes, {"x", "y"}, cpDemoSizes, "size"]
            }
        ],
        True,
        TestID -> "paclet-paths-B1-4tensor-exhaustive"
    ]
];

(* ----- B2: chain of 3 (8,8) matrices, width and cost (quimb test_tensor_core.py:1095-1101)
   a-b-c where each is (8,8); shared bonds. Optimal path has length 2.
   The contracted scalar should equal Tr[a.b.c] for a closed chain or a.b.c for open. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork", "TensorNetworkContract"},
    "paclet-paths-B2-chain3",
    "quimb tests/test_tensor_core.py:1095-1101",
    VerificationTest[
        Module[{tn, path, contracted, expected, a, b, c},
            SeedRandom[103];
            a = RandomReal[{-1, 1}, {8, 8}];
            b = RandomReal[{-1, 1}, {8, 8}];
            c = RandomReal[{-1, 1}, {8, 8}];
            (* Chain: a[i,j], b[j,k], c[k,l] -> result[i,l] *)
            tn = TensorNetwork[{a, b, c}, {{"i", "j"}, {"j", "k"}, {"k", "l"}}];
            path = OptimalContractionPath[tn, Method -> "flops"];
            contracted = TensorNetworkContract[tn];
            expected = a . b . c;
            Length[path] === 2 && Dimensions[contracted] === {8, 8} &&
                ValidationClose[contracted, expected, 1.*^-10]
        ],
        True,
        TestID -> "paclet-paths-B2-chain3"
    ]
];

(* ----- B3: edgesort path on chain (cotengra tests/test_paths_basic.py:221-243)
   inputs=[(3,2),(2,1),(1,0)], all bond dim 2; deterministic optimal/greedy
   should find ((1,2),(0,1)) [opt_einsum] = paclet {{2,3},{1,2}}.
   We just check path has length 2 and contracts correctly. *)
WithCapability[{"GreedyContractionPath", "TensorNetwork", "TensorNetworkContract"},
    "paclet-paths-B3-edgesort-chain",
    "cotengra tests/test_paths_basic.py:221-243 (edgesort chain)",
    VerificationTest[
        Module[{tn, path, contracted, expected, t1, t2, t3},
            SeedRandom[107];
            (* indices labelled "0","1","2","3"; bond dim 2 each *)
            t1 = RandomReal[{-1, 1}, {2, 2}];
            t2 = RandomReal[{-1, 1}, {2, 2}];
            t3 = RandomReal[{-1, 1}, {2, 2}];
            tn = TensorNetwork[{t1, t2, t3}, {{"3", "2"}, {"2", "1"}, {"1", "0"}}];
            path = GreedyContractionPath[tn];
            contracted = TensorNetworkContract[tn];
            expected = t1 . t2 . t3;
            Length[path] === 2 && ValidationClose[contracted, expected, 1.*^-12]
        ],
        True,
        TestID -> "paclet-paths-B3-edgesort-chain"
    ]
];

(* ----- B4: a 2x3 lattice of complex random tensors with unequal bonds and open legs on
   two corners, output in reversed order: the "flops" path costs the exhaustive minimum,
   and the values along that path and by default equal the explicit index sum. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork", "TensorNetworkContract"},
    "paclet-paths-B4-lattice23",
    "cotengra tests/test_paths_basic.py:194-205 (lattice), shrunk to 2x3 for an exact reference",
    VerificationTest[
        Module[{shapes, sd, out, ts, tn, path, ref},
            shapes = {{"h11", "v1", "p11"}, {"h11", "h12", "v2"}, {"h12", "v3"},
                {"v1", "h21"}, {"h21", "h22", "v2"}, {"h22", "v3", "p23"}};
            sd = <|"h11" -> 2, "h12" -> 3, "h21" -> 4, "h22" -> 2, "v1" -> 3, "v2" -> 2, "v3" -> 4,
                "p11" -> 2, "p23" -> 3|>;
            out = {"p23", "p11"};
            ts = cpRandomComplex[sd, shapes, 109];
            tn = TensorNetwork[ts, shapes -> out];
            path = OptimalContractionPath[tn, Method -> "flops"];
            ref = cpOracle[ts, shapes, out];
            First[cpPathCosts[shapes, out, sd, path]] === cpBest[shapes, out, sd, "flops"] &&
                cpClose[TensorNetworkContract[tn, path], ref] &&
                cpClose[TensorNetworkContract[tn], ref]
        ],
        True,
        TestID -> "paclet-paths-B4-lattice23"
    ]
];

(* ----- B5: on the 5-tensor loop, contracting along the greedy, "flops" and "size" paths,
   by the named methods and by default all give the explicit index sum. *)
WithCapability[{"OptimalContractionPath", "GreedyContractionPath", "TensorNetwork", "TensorNetworkContract"},
    "paclet-paths-B5-paths-match-index-sum",
    "contraction value is independent of the order (explicit index sum)",
    VerificationTest[
        Module[{ts, tn, ref},
            ts = cpRandomComplex[cpFiveSizes, cpFiveShapes, 113];
            tn = TensorNetwork[ts, cpFiveShapes -> {"g"}];
            ref = cpOracle[ts, cpFiveShapes, {"g"}];
            AllTrue[
                {
                    TensorNetworkContract[tn, GreedyContractionPath[tn]],
                    TensorNetworkContract[tn, OptimalContractionPath[tn, Method -> "flops"]],
                    TensorNetworkContract[tn, OptimalContractionPath[tn, Method -> "size"]],
                    TensorNetworkContract[tn, "Greedy"],
                    TensorNetworkContract[tn, "flops"],
                    TensorNetworkContract[tn]
                },
                cpClose[#, ref] &
            ]
        ],
        True,
        TestID -> "paclet-paths-B5-paths-match-index-sum"
    ]
];

(* ----- B6: contract correctness end-to-end (cotengra tests/test_paths_basic.py:97-110
   "test_manual_cases"). Verify TensorNetworkContract == ground-truth einsum
   on a 5-tensor hypergraph including a hyper-index. *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-paths-B6-contract-correctness",
    "cotengra tests/test_paths_basic.py:97-110 (test_manual_cases)",
    VerificationTest[
        Module[{ts, shapes, tn, contracted, expected, sd},
            sd = <|"i" -> 2, "j" -> 3, "k" -> 4, "l" -> 5, "x" -> 2|>;
            shapes = {{"i", "j", "x"}, {"j", "k"}, {"k", "l", "x"}, {"l", "i"}};
            SeedRandom[127];
            ts = MapThread[RandomReal[{-1, 1}, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            contracted = TensorNetworkContract[tn];
            expected = Sum[
                ts[[1]][[i, j, x]] ts[[2]][[j, k]] ts[[3]][[k, l, x]] ts[[4]][[l, i]],
                {i, 2}, {j, 3}, {k, 4}, {l, 5}, {x, 2}];
            ValidationClose[contracted, expected, 1.*^-10]
        ],
        True,
        TestID -> "paclet-paths-B6-contract-correctness"
    ]
];

(* ----- B8: on cotengra's 12-tensor random regular network the "flops" path costs the
   exact optimum found here by dynamic programming over connected subsets, which is
   also within cotengra's HyperOptimizer cost. *)
WithCapability[{"TensorNetwork", "OptimalContractionPath"},
    "paclet-paths-B8-hyperoptimizer-comparison",
    "cotengra tests/test_optimizers.py:139-167 (fixture: external_oracles/fixtures/cotengra_hyperopt_bound.json)",
    VerificationTest[
        Module[{fixture, shapes, sd, out, tn, cost, best},
            fixture = Import[OracleFixturePath["cotengra_hyperopt_bound.json"], "RawJSON"];
            shapes = fixture["inputs"];
            sd = Association @ KeyValueMap[Rule, fixture["size_dict"]];
            out = Keys @ Select[Counts[Catenate[shapes]], # === 1 &];
            tn = TensorNetwork[ConstantArray[1., Lookup[sd, #]] & /@ shapes, shapes];
            cost = First @ cpPathCosts[shapes, out, sd, OptimalContractionPath[tn, Method -> "flops"]];
            best = cpSubsetBest[shapes, out, sd];
            cost === best && cost <= fixture["hyperopt_cost"]
        ],
        True,
        TestID -> "paclet-paths-B8-hyperoptimizer-comparison"
    ]
];

(* ----- B9: GreedyContractionPath follows the greedy rule for the default weight and for
   "MemoryWeight" 0.1, 0.5, 2 and 4: each path costs an amount the rule can produce.
   The weights 1 and 4 lead to disjoint costs on this network, so a weight that is
   ignored is seen. *)
WithCapability[{"GreedyContractionPath", "TensorNetwork"},
    "paclet-paths-B9-greedy-rule-and-memory-weight",
    "cotengra greedy (cotengrust optimize_greedy) rule, replayed here",
    VerificationTest[
        Module[{tn, costOf, allowed},
            tn = TensorNetwork[ConstantArray[1., Lookup[cpFiveSizes, #]] & /@ cpFiveShapes, cpFiveShapes -> {"g"}];
            costOf[path_] := First @ cpPathCosts[cpFiveShapes, {"g"}, cpFiveSizes, path];
            allowed[w_] := cpGreedyCosts[cpFiveShapes, {"g"}, cpFiveSizes, w];
            And[
                Intersection[allowed[1.], allowed[4.]] === {},
                MemberQ[allowed[1.], costOf[GreedyContractionPath[tn]]],
                AllTrue[{0.1, 0.5, 2., 4.},
                    MemberQ[allowed[#], costOf[GreedyContractionPath[tn, "MemoryWeight" -> #]]] &]
            ]
        ],
        True,
        TestID -> "paclet-paths-B9-greedy-rule-and-memory-weight"
    ]
];

(* ----- B10: "AllowOuterProducts" -> True: a rank-4 tensor with three vectors on its
   short legs and one long open leg is cheapest by first multiplying the vectors
   together (an outer product). The paclet must find the exhaustive minimum both with
   and without outer products, and the two minima differ. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-paths-B10-outer-products",
    "exhaustive search with and without outer products",
    VerificationTest[
        Module[{shapes, sd, tn, with, without},
            shapes = {{"a", "b", "c", "o"}, {"a"}, {"b"}, {"c"}};
            sd = <|"a" -> 3, "b" -> 3, "c" -> 3, "o" -> 20|>;
            tn = TensorNetwork[ConstantArray[1., Lookup[sd, #]] & /@ shapes, shapes -> {"o"}];
            with = cpBest[shapes, {"o"}, sd, "flops", True];
            without = cpBest[shapes, {"o"}, sd, "flops"];
            with < without &&
                First[cpPathCosts[shapes, {"o"}, sd, OptimalContractionPath[tn, Method -> "flops", "AllowOuterProducts" -> True]]] === with &&
                First[cpPathCosts[shapes, {"o"}, sd, OptimalContractionPath[tn, Method -> "flops"]]] === without
        ],
        True,
        TestID -> "paclet-paths-B10-outer-products"
    ]
];

(* ----- B11: every contraction engine gives the explicit index sum, on a 4-tensor loop
   with three open legs requested in a cyclically permuted order and on its closed
   version (a scalar). *)
WithCapability[{"TensorNetwork", "TensorNetworkContract"},
    "paclet-paths-B11-engines-match-index-sum",
    "explicit index sum; $TensorNetworkContractionMethods",
    VerificationTest[
        Module[{openShapes, closedShapes, sd, out, tsOpen, tsClosed, refOpen, refClosed, tnOpen, tnClosed},
            openShapes = {{"i", "j", "o1"}, {"j", "k", "o2", "l"}, {"k", "i", "m"}, {"l", "m", "o3"}};
            closedShapes = DeleteCases[openShapes, "o1" | "o2" | "o3", {2}];
            sd = <|"i" -> 2, "j" -> 3, "k" -> 4, "l" -> 2, "m" -> 3, "o1" -> 2, "o2" -> 3, "o3" -> 4|>;
            out = {"o3", "o1", "o2"};
            tsOpen = cpRandomComplex[sd, openShapes, 139];
            tsClosed = cpRandomComplex[sd, closedShapes, 140];
            refOpen = cpOracle[tsOpen, openShapes, out];
            refClosed = cpOracle[tsClosed, closedShapes, {}];
            tnOpen = TensorNetwork[tsOpen, openShapes -> out];
            tnClosed = TensorNetwork[tsClosed, closedShapes -> {}];
            AllTrue[{"ArrayDotTranspose", "ArrayDot", "Dot", "TensorContract", "TableSum"},
                cpClose[TensorNetworkContract[tnOpen, Method -> #], refOpen] &&
                    cpClose[TensorNetworkContract[tnClosed, Method -> #], refClosed] &]
        ],
        True,
        TestID -> "paclet-paths-B11-engines-match-index-sum"
    ]
];

(* ----- B-cost1: Pin down the paclet's per-step cost convention.
   Convention (audited 2026-05-08 against TensorNetworks/Cotengra/src/lib.rs:115-132):
     Per step (i,j) -> cost = product of all unique dims in (legs_i union legs_j)
   This matches cotengra's mul-count `_flops` (cotengra/core.py:1196-1227 with
   dtype=None). cotengra additionally scales by 2 for dtype="float" and 4 for
   dtype="complex"; paclet does not scale.

   Test: 3-tensor open chain a[i,j] b[j,k] c[k,l] with d_i=2, d_j=3, d_k=4, d_l=5.
   Output: rank-2 tensor with open legs {i, l}.
   Optimal path is L-to-R {{1,2},{1,2}}:
     Step 1 (a,b -> ab[i,k]): product of {i,j,k} dims = 2*3*4 = 24
     Step 2 (ab,c -> result[i,l]): product of {i,k,l} dims = 2*4*5 = 40
   Total flops = 24 + 40 = 64.
   (Greedy chooses R-to-L which gives a higher cost of 90; this test uses
   OptimalContractionPath since it's the cost the optimizer should find.) *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-paths-Bcost1-chain-optimal-flops",
    "cotengra core.py:1196-1227 + paclet Cotengra/src/lib.rs:115-132",
    VerificationTest[
        Module[{tn, ts, shapes, sd, path, cost},
            sd = <|"i" -> 2, "j" -> 3, "k" -> 4, "l" -> 5|>;
            shapes = {{"i", "j"}, {"j", "k"}, {"k", "l"}};
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            cost = pathCost[shapes, sd, path];
            cost === 64
        ],
        True,
        TestID -> "paclet-paths-Bcost1-chain-optimal-flops"
    ]
];

(* ----- B-cost2: optimal path on a closed triangle has known total cost.
   Triangle a[i,j] b[j,k] c[k,i] with d_i=2, d_j=3, d_k=4. Closed network
   (every leg appears twice) -> output is a scalar.
     Step 1 (b,c -> bc[j,i]): product of {j,k,i} dims = 3*4*2 = 24
     Step 2 (a,bc -> scalar): product of {i,j} dims = 2*3 = 6
   Total flops = 24 + 6 = 30. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-paths-Bcost2-triangle-cost",
    "Per-step cost convention on a closed triangle",
    VerificationTest[
        Module[{tn, ts, shapes, sd, path, cost},
            sd = <|"i" -> 2, "j" -> 3, "k" -> 4|>;
            shapes = {{"i", "j"}, {"j", "k"}, {"k", "i"}};
            ts = MapThread[ConstantArray[1.0, sd /@ #] &, {shapes}];
            tn = TensorNetwork[ts, shapes];
            path = OptimalContractionPath[tn, Method -> "flops"];
            cost = pathCost[shapes, sd, path];
            cost === 30
        ],
        True,
        TestID -> "paclet-paths-Bcost2-triangle-cost"
    ]
];

(* ----- B-cost3: the default OptimalContractionPath minimizes the largest intermediate
   ("size"), on a network where the flops-optimal path does not. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-paths-Bcost3-default-is-size-optimal",
    "exhaustive search over orders (largest intermediate)",
    VerificationTest[
        Module[{tn, sizeBest, flopsPathLargest},
            tn = TensorNetwork[ConstantArray[1., Lookup[cpSplitSizes, #]] & /@ cpSplitShapes, cpSplitShapes -> cpSplitOut];
            sizeBest = cpBest[cpSplitShapes, cpSplitOut, cpSplitSizes, "size"];
            flopsPathLargest = Last @ cpPathCosts[cpSplitShapes, cpSplitOut, cpSplitSizes, OptimalContractionPath[tn, Method -> "flops"]];
            flopsPathLargest > sizeBest &&
                Last[cpPathCosts[cpSplitShapes, cpSplitOut, cpSplitSizes, OptimalContractionPath[tn]]] === sizeBest
        ],
        True,
        TestID -> "paclet-paths-Bcost3-default-is-size-optimal"
    ]
];

(* ----- B12: on the same network, Method -> "flops" reaches the flops minimum and
   Method -> "size" the largest-intermediate minimum of the exhaustive search, and both
   paths contract complex random tensors to the explicit index sum. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork", "TensorNetworkContract"},
    "paclet-paths-B12-method-flops-vs-size",
    "exhaustive search over orders; explicit index sum",
    VerificationTest[
        Module[{ts, tn, pFlops, pSize, ref},
            ts = cpRandomComplex[cpSplitSizes, cpSplitShapes, 149];
            tn = TensorNetwork[ts, cpSplitShapes -> cpSplitOut];
            pFlops = OptimalContractionPath[tn, Method -> "flops"];
            pSize = OptimalContractionPath[tn, Method -> "size"];
            ref = cpOracle[ts, cpSplitShapes, cpSplitOut];
            First[cpPathCosts[cpSplitShapes, cpSplitOut, cpSplitSizes, pFlops]] === cpBest[cpSplitShapes, cpSplitOut, cpSplitSizes, "flops"] &&
                Last[cpPathCosts[cpSplitShapes, cpSplitOut, cpSplitSizes, pSize]] === cpBest[cpSplitShapes, cpSplitOut, cpSplitSizes, "size"] &&
                cpClose[TensorNetworkContract[tn, pFlops], ref] &&
                cpClose[TensorNetworkContract[tn, pSize], ref]
        ],
        True,
        TestID -> "paclet-paths-B12-method-flops-vs-size"
    ]
];

(* ----- B13: greedy paths drawn with "Temperature" and "RandomSeed" are valid orders that
   contract to the explicit index sum and cost no less than the exhaustive minimum. *)
WithCapability[{"GreedyContractionPath", "TensorNetwork", "TensorNetworkContract"},
    "paclet-paths-B13-tempered-greedy",
    "explicit index sum; exhaustive search over orders",
    VerificationTest[
        Module[{ts, tn, ref, best},
            ts = cpRandomComplex[cpFiveSizes, cpFiveShapes, 151];
            tn = TensorNetwork[ts, cpFiveShapes -> {"g"}];
            ref = cpOracle[ts, cpFiveShapes, {"g"}];
            best = cpBest[cpFiveShapes, {"g"}, cpFiveSizes, "flops"];
            AllTrue[Range[8],
                Function[seed, With[{path = GreedyContractionPath[tn, "Temperature" -> 0.5, "RandomSeed" -> seed]},
                    PathValidQ[path, Length[cpFiveShapes]] &&
                        First[cpPathCosts[cpFiveShapes, {"g"}, cpFiveSizes, path]] >= best &&
                        cpClose[TensorNetworkContract[tn, path], ref]]]]
        ],
        True,
        TestID -> "paclet-paths-B13-tempered-greedy"
    ]
];

(* ----- Bprice: the price the Automatic planner puts on a path (the private pathCost of
   Contraction.wl, which ranks candidate plans) equals the documented rule computed here:
   per step, the elements of both operands and of the result plus the flops over 70, and
   the largest result. Checked on several paths of the 5-tensor loop and of a network
   with a hyperedge, a leg only one tensor holds, and a hyperedge kept in the output. *)
WithCapability[{"TensorNetwork", "GreedyContractionPath", "OptimalContractionPath"},
    "paclet-paths-Bprice-plan-price",
    "Contraction.wl cheapestPlan price rule, recomputed",
    VerificationTest[
        Module[{priceOf, check, tn, hyperShapes, hyperSizes, hyperOut, tnHyper},
            priceOf[net_, path_] := With[{params = Wolfram`TensorNetworks`PackageScope`extractContractionParameters[net]},
                Wolfram`TensorNetworks`Contraction`PackagePrivate`pathCost[path,
                    Wolfram`TensorNetworks`Contraction`PackagePrivate`pathCostInput[params]]];
            check[net_, shapes_, out_, sd_, path_] := With[{got = priceOf[net, path], want = cpPrice[shapes, out, sd, path]},
                Abs[First[got] - First[want]] <= 1.*^-12 First[want] && Last[got] == Last[want]];
            tn = TensorNetwork[ConstantArray[1., Lookup[cpFiveSizes, #]] & /@ cpFiveShapes, cpFiveShapes -> {"g"}];
            hyperShapes = {{"a", "x", "s"}, {"x", "b"}, {"x", "c", "a"}, {"b", "c", "o"}};
            hyperSizes = <|"a" -> 3, "x" -> 2, "s" -> 4, "b" -> 5, "c" -> 2, "o" -> 3|>;
            hyperOut = {"o", "x"};
            tnHyper = TensorNetwork[ConstantArray[1., Lookup[hyperSizes, #]] & /@ hyperShapes, hyperShapes -> hyperOut];
            And[
                AllTrue[{GreedyContractionPath[tn], OptimalContractionPath[tn, Method -> "flops"],
                        {{1, 2}, {1, 2}, {1, 2}, {1, 2}}, {{4, 5}, {2, 3}, {1, 2}, {1, 2}}},
                    check[tn, cpFiveShapes, {"g"}, cpFiveSizes, #] &],
                AllTrue[{{{1, 2}, {1, 2}, {1, 2}}, {{3, 4}, {1, 2}, {1, 2}}, {{2, 4}, {1, 3}, {1, 2}}},
                    check[tnHyper, hyperShapes, hyperOut, hyperSizes, #] &]
            ]
        ],
        True,
        TestID -> "paclet-paths-Bprice-plan-price"
    ]
];
