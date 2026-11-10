(* Tests/external_validation/paclet_primitives/contraction_paths_exact.wl

OptimalContractionPath, GreedyContractionPath and the path conversions on small
networks whose optimum is known here exactly. References computed without the paclet:
exhaustive search over every order of pairwise contractions (cpxBest, no outer
products, like the paclet's search), the flops and largest intermediate of a path
walked step by step (cpxPathCosts), the greedy rule replayed with every tie-break
(cpxGreedyCosts), an explicit sum over every index assignment (cpxOracle), and the
opt_einsum meaning of a path (remove both positions, append the result) for the tree
a path describes.

Every network has unequal dimensions, so a path that is merely valid does not reach
the optimum by accident. Kept unchanged: T1 (the one path of two tensors), T6 (no
steps for one tensor), T8 (PathToTreePath rejects indices of the wrong length).

Sources:
- cotengra tests/test_paths_basic.py:97-110 (test_manual_cases), 221-243 (edgesort chain)
- cotengra docs/basics.ipynb (4-tensor demo)
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

(* ===================== Independent references ===================== *)

(* agreement to 1e-10 relative to the size of the reference, same dimensions *)
cpxClose[x_, y_] := TrueQ[Dimensions[x] === Dimensions[y] && Max[Abs[Flatten[{x - y}]]] <= 1.*^-10 Max[1, Max[Abs[Flatten[{y}]]]]];
(* explicit index sum *)
cpxSizes[ts_, shapes_] := Association @ Catenate @ MapThread[Thread[#2 -> Dimensions[#1]] &, {ts, shapes}];
cpxEntry[ts_, shapes_, val_] := Times @@ MapThread[Extract[#1, Lookup[val, #2]] &, {ts, shapes}];
cpxOracle[ts_, shapes_, out_] := Block[{sd = cpxSizes[ts, shapes], internal, tuples, labels, sumAt},
    internal = Complement[DeleteDuplicates[Catenate[shapes]], out];
    tuples = Tuples[Range /@ Lookup[sd, internal]];
    labels = Join[out, internal];
    sumAt[o_List] := Total[cpxEntry[ts, shapes, AssociationThread[labels, Join[o, #]]] & /@ tuples];
    If[out === {}, sumAt[{}], Array[sumAt[{##}] &, Lookup[sd, out]]]
];
cpxKept[a_, b_, rest_, out_] := Select[Union[a, b], Function[l, MemberQ[out, l] || AnyTrue[rest, MemberQ[#, l] &]]];
cpxPathCosts[shapes_, out_, sd_, path_] := Module[{state = Union /@ shapes, flops = 0, largest = 0, a, b, rest, k},
    Scan[Function[step,
        a = state[[step[[1]]]]; b = state[[step[[2]]]]; rest = Delete[state, List /@ step];
        k = cpxKept[a, b, rest, out];
        flops += Times @@ Lookup[sd, Union[a, b]];
        largest = Max[largest, Times @@ Lookup[sd, k]];
        state = Append[rest, k]], path];
    {flops, largest}
];
cpxBest[shapes_, out_, sd_, objective_, outerQ_ : False] := Module[{rec},
    rec[state_] := rec[state] = If[Length[state] == 1, 0,
        Min @ Map[
            Function[p, With[{a = state[[p[[1]]]], b = state[[p[[2]]]], rest = Delete[state, List /@ p]},
                With[{k = cpxKept[a, b, rest, out]},
                    If[objective === "flops",
                        Times @@ Lookup[sd, Union[a, b]] + rec[Sort[Append[rest, k]]],
                        Max[Times @@ Lookup[sd, k], rec[Sort[Append[rest, k]]]]]]]],
            Select[Subsets[Range[Length[state]], {2}], outerQ || IntersectingQ[state[[#[[1]]]], state[[#[[2]]]]] &]]];
    rec[Sort[Union /@ shapes]]
];
(* Rust scores log(sab/w - w(sa+sb)) as a signed log in single precision; a difference
   within rounding of zero can come out at either extreme, so it is marked ambiguous *)
cpxGreedyScore[sa_, sb_, sab_, w_] := With[{d = sab / w - w (sa + sb)},
    Which[Abs[d] <= 1.*^-5 (sab / w + w (sa + sb)), None, d > 0, Log[d], True, -Log[-d]]];
cpxGreedyCosts[shapes_, out_, sd_, w_] := Module[{rec, size},
    size[l_] := Times @@ Lookup[sd, l];
    rec[state_] := rec[state] = If[Length[state] == 1, {0},
        With[{cands = Map[
                Function[p, With[{a = state[[p[[1]]]], b = state[[p[[2]]]], rest = Delete[state, List /@ p]},
                    With[{k = cpxKept[a, b, rest, out]},
                        {cpxGreedyScore[size[a], size[b], size[k], w], size[Union[a, b]], Sort[Append[rest, k]]}]]],
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
cpxPrice[shapes_, out_, sd_, path_] := Module[{holders, state, price = 0, largest = 0, w, a, b, k, c},
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
cpxSubsetBest[shapes_, out_, sd_] := Module[{n = Length[shapes], legsets = Union /@ shapes, legsOf, best = <||>, all, cost},
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
cpxRandomNetwork[seed_, n_, extra_, hyper_, open_, maxTotal_ : 200000] := Module[{try = seed, net},
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

(* both optima of the exhaustive search reached by the paclet's "flops" and "size" paths *)
cpxBothOptimal[shapes_, out_, sd_] := With[
    {tn = TensorNetwork[ConstantArray[1., Lookup[sd, #]] & /@ shapes, shapes -> out]},
    First[cpxPathCosts[shapes, out, sd, OptimalContractionPath[tn, Method -> "flops"]]] === cpxBest[shapes, out, sd, "flops"] &&
        Last[cpxPathCosts[shapes, out, sd, OptimalContractionPath[tn, Method -> "size"]]] === cpxBest[shapes, out, sd, "size"]
];

(* the tree a path describes: each step removes both positions and appends their pair *)
cpxTreeOf[path_, n_] := First @ Fold[
    Function[{trees, step}, Append[Delete[trees, List /@ step], trees[[step]]]],
    List /@ Range[n],
    path
];

(* a tree with the children of every node sorted, to compare trees up to operand order *)
cpxSortedTree[{leaf_Integer}] := {leaf};
cpxSortedTree[node_List] := Sort[cpxSortedTree /@ node];

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

(* ----- T2: open chain of 5 matrices with bonds 7, 2, 6, 3, 5, 2, where the order
   matters (left to right costs 1014 flops, the optimum 106): both optimal paths reach
   the exhaustive optimum. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-paths-exact-T2-chain5-exhaustive",
    "matrix-chain ordering; exhaustive search over orders",
    VerificationTest[
        Module[{shapes, sd},
            shapes = Table[{"e" <> ToString[i - 1], "e" <> ToString[i]}, {i, 5}];
            sd = AssociationThread["e" <> ToString[#] & /@ Range[0, 5], {7, 2, 6, 3, 5, 2}];
            cpxBothOptimal[shapes, {"e0", "e5"}, sd]
        ],
        True,
        TestID -> "paclet-paths-exact-T2-chain5-exhaustive"
    ]
];

(* ----- T3: a center tensor with four spokes of dimensions 2, 5, 3, 4, each spoke a
   matrix with its own open leg, and an open leg on the center: both optima. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-paths-exact-T3-star-exhaustive",
    "star topology; exhaustive search over orders",
    VerificationTest[
        Module[{shapes, sd},
            shapes = {{"s1", "s2", "s3", "s4", "c"}, {"s1", "t1"}, {"s2", "t2"}, {"s3", "t3"}, {"s4", "t4"}};
            sd = <|"s1" -> 2, "s2" -> 5, "s3" -> 3, "s4" -> 4, "c" -> 2,
                "t1" -> 3, "t2" -> 2, "t3" -> 4, "t4" -> 2|>;
            cpxBothOptimal[shapes, {"c", "t1", "t2", "t3", "t4"}, sd]
        ],
        True,
        TestID -> "paclet-paths-exact-T3-star-exhaustive"
    ]
];

(* ----- T4: the edgesort chain (3,2),(2,1),(1,0) with bonds 2, 3, 4, 5: the greedy
   rule contracts right to left (cost 90) while the optimum is left to right (cost 64);
   the greedy path must cost what the rule gives and the "flops" path the optimum. *)
WithCapability[{"OptimalContractionPath", "GreedyContractionPath", "TensorNetwork"},
    "paclet-paths-exact-T4-edgesort-chain-greedy-and-optimal",
    "cotengra tests/test_paths_basic.py:221-243; greedy rule replayed; exhaustive search",
    VerificationTest[
        Module[{shapes, sd, out, tn, greedyCost},
            shapes = {{"e3", "e2"}, {"e2", "e1"}, {"e1", "e0"}};
            sd = <|"e0" -> 5, "e1" -> 4, "e2" -> 3, "e3" -> 2|>;
            out = {"e3", "e0"};
            tn = TensorNetwork[ConstantArray[1., Lookup[sd, #]] & /@ shapes, shapes -> out];
            greedyCost = First @ cpxPathCosts[shapes, out, sd, GreedyContractionPath[tn]];
            cpxGreedyCosts[shapes, out, sd, 1.] === {greedyCost} &&
                First[cpxPathCosts[shapes, out, sd, OptimalContractionPath[tn, Method -> "flops"]]] === cpxBest[shapes, out, sd, "flops"] &&
                greedyCost > cpxBest[shapes, out, sd, "flops"]
        ],
        True,
        TestID -> "paclet-paths-exact-T4-edgesort-chain-greedy-and-optimal"
    ]
];

(* ----- T5: closed triangle with an open leg on each corner and unequal bonds: both
   optima, and the value along the "flops" path equals the explicit index sum. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork", "TensorNetworkContract"},
    "paclet-paths-exact-T5-triangle",
    "cotengra tests/test_paths_basic.py:97-110 (3-cycle); exhaustive search; explicit index sum",
    VerificationTest[
        Module[{shapes, sd, out, ts, tn},
            shapes = {{"i", "j", "p"}, {"j", "k", "q"}, {"k", "i", "r"}};
            sd = <|"i" -> 2, "j" -> 5, "k" -> 3, "p" -> 4, "q" -> 2, "r" -> 3|>;
            out = {"q", "r", "p"};
            ts = BlockRandom[SeedRandom[503]; RandomComplex[{-1 - I, 1 + I}, Lookup[sd, #]] & /@ shapes];
            tn = TensorNetwork[ts, shapes -> out];
            cpxBothOptimal[shapes, out, sd] &&
                cpxClose[TensorNetworkContract[tn, OptimalContractionPath[tn, Method -> "flops"]], cpxOracle[ts, shapes, out]]
        ],
        True,
        TestID -> "paclet-paths-exact-T5-triangle"
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

(* ----- T7: the 4-tensor demo with complex random tensors: the value along the
   "flops" path and by default equals the explicit index sum. *)
WithCapability[{"OptimalContractionPath", "TensorNetworkContract", "TensorNetwork"},
    "paclet-paths-exact-T7-optimal-path-correct-result",
    "cotengra docs/basics.ipynb (4-tensor demo); explicit index sum",
    VerificationTest[
        Module[{shapes, sd, ts, tn, ref},
            sd = <|"a" -> 4, "b" -> 5, "c" -> 6, "d" -> 7, "e" -> 8, "x" -> 2, "y" -> 3|>;
            shapes = {{"a", "b", "x"}, {"b", "c", "d"}, {"c", "e", "y"}, {"e", "a", "d"}};
            ts = BlockRandom[SeedRandom[507]; RandomComplex[{-1 - I, 1 + I}, Lookup[sd, #]] & /@ shapes];
            tn = TensorNetwork[ts, shapes -> {"y", "x"}];
            ref = cpxOracle[ts, shapes, {"y", "x"}];
            cpxClose[TensorNetworkContract[tn, OptimalContractionPath[tn, Method -> "flops"]], ref] &&
                cpxClose[TensorNetworkContract[tn], ref]
        ],
        True,
        TestID -> "paclet-paths-exact-T7-optimal-path-correct-result"
    ]
];


(* ----- T8: PathToTreePath robustness: wrong-length indices error cleanly
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

(* ----- T9: on 40 random graph networks (hyperedges included), PathToTreePath of the
   greedy path is the tree the path describes, and TreePathToPath turns that tree back
   into a path describing the same tree. *)
WithCapability[{"RandomTensorNetwork", "GreedyContractionPath", "PathToTreePath", "TreePathToPath"},
    "paclet-paths-exact-T9-pathToTreePath-automatic",
    "opt_einsum path convention, replayed here",
    VerificationTest[
        AllTrue[Range[40],
            Function[seed,
                BlockRandom[SeedRandom[seed];
                    Module[{tn, path, n, tree},
                        tn = RandomTensorNetwork[{4, 5}, 3];
                        path = GreedyContractionPath[tn];
                        n = Length[path] + 1;
                        tree = PathToTreePath[path];
                        tree === cpxTreeOf[path, n] &&
                            cpxSortedTree[cpxTreeOf[TreePathToPath[tree], n]] === cpxSortedTree[tree]
                    ]
                ]
            ]
        ],
        True,
        TestID -> "paclet-paths-exact-T9-pathToTreePath-automatic"
    ]
];
