(* Tests/external_validation/paclet_fuzz/fuzz_contraction_paths.wl

   Seeded property sweeps for OptimalContractionPath and GreedyContractionPath on
   random connected networks (spanning tree plus extra bonds, optional indices shared
   by three tensors, open legs requested in random order, dimensions 2 to 4). Every
   check is against a reference computed here without the paclet:

   - optimal paths: the exhaustive minimum over all orders of pairwise contractions
     without outer products (fzpBest), for "flops" (sum over steps of the product of
     both operands' dimensions) and "size" (largest intermediate); dynamic programming
     over connected subsets (fzpSubsetBest) for 9 and 10 tensors;
   - greedy paths: the cotengra greedy rule replayed with every tie-break (fzpGreedyCosts),
     for the default weight and for "MemoryWeight" values;
   - values contracted along any of these paths, or along tempered greedy paths: an
     explicit sum over every index assignment (fzpOracle) on complex random tensors;
   - the Automatic planner's price of a path: its documented rule (fzpPrice).
*)

Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "..", "Helpers", "ValidationHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed, Print["[fuzz-paths] cannot find ValidationHelpers.wl"]; Abort[]];
    Get[found];
];
ClearValidationRecords[];

(* ===================== Independent references ===================== *)

(* agreement to 1e-10 relative to the size of the reference, same dimensions *)
fzpClose[x_, y_] := TrueQ[Dimensions[x] === Dimensions[y] && Max[Abs[Flatten[{x - y}]]] <= 1.*^-10 Max[1, Max[Abs[Flatten[{y}]]]]];
(* explicit index sum *)
fzpSizes[ts_, shapes_] := Association @ Catenate @ MapThread[Thread[#2 -> Dimensions[#1]] &, {ts, shapes}];
fzpEntry[ts_, shapes_, val_] := Times @@ MapThread[Extract[#1, Lookup[val, #2]] &, {ts, shapes}];
fzpOracle[ts_, shapes_, out_] := Block[{sd = fzpSizes[ts, shapes], internal, tuples, labels, sumAt},
    internal = Complement[DeleteDuplicates[Catenate[shapes]], out];
    tuples = Tuples[Range /@ Lookup[sd, internal]];
    labels = Join[out, internal];
    sumAt[o_List] := Total[fzpEntry[ts, shapes, AssociationThread[labels, Join[o, #]]] & /@ tuples];
    If[out === {}, sumAt[{}], Array[sumAt[{##}] &, Lookup[sd, out]]]
];
fzpKept[a_, b_, rest_, out_] := Select[Union[a, b], Function[l, MemberQ[out, l] || AnyTrue[rest, MemberQ[#, l] &]]];
fzpPathCosts[shapes_, out_, sd_, path_] := Module[{state = Union /@ shapes, flops = 0, largest = 0, a, b, rest, k},
    Scan[Function[step,
        a = state[[step[[1]]]]; b = state[[step[[2]]]]; rest = Delete[state, List /@ step];
        k = fzpKept[a, b, rest, out];
        flops += Times @@ Lookup[sd, Union[a, b]];
        largest = Max[largest, Times @@ Lookup[sd, k]];
        state = Append[rest, k]], path];
    {flops, largest}
];
fzpBest[shapes_, out_, sd_, objective_, outerQ_ : False] := Module[{rec},
    rec[state_] := rec[state] = If[Length[state] == 1, 0,
        Min @ Map[
            Function[p, With[{a = state[[p[[1]]]], b = state[[p[[2]]]], rest = Delete[state, List /@ p]},
                With[{k = fzpKept[a, b, rest, out]},
                    If[objective === "flops",
                        Times @@ Lookup[sd, Union[a, b]] + rec[Sort[Append[rest, k]]],
                        Max[Times @@ Lookup[sd, k], rec[Sort[Append[rest, k]]]]]]]],
            Select[Subsets[Range[Length[state]], {2}], outerQ || IntersectingQ[state[[#[[1]]]], state[[#[[2]]]]] &]]];
    rec[Sort[Union /@ shapes]]
];
(* Rust scores log(sab/w - w(sa+sb)) as a signed log in single precision; a difference
   within rounding of zero can come out at either extreme, so it is marked ambiguous *)
fzpGreedyScore[sa_, sb_, sab_, w_] := With[{d = sab / w - w (sa + sb)},
    Which[Abs[d] <= 1.*^-5 (sab / w + w (sa + sb)), None, d > 0, Log[d], True, -Log[-d]]];
fzpGreedyCosts[shapes_, out_, sd_, w_] := Module[{rec, size},
    size[l_] := Times @@ Lookup[sd, l];
    rec[state_] := rec[state] = If[Length[state] == 1, {0},
        With[{cands = Map[
                Function[p, With[{a = state[[p[[1]]]], b = state[[p[[2]]]], rest = Delete[state, List /@ p]},
                    With[{k = fzpKept[a, b, rest, out]},
                        {fzpGreedyScore[size[a], size[b], size[k], w], size[Union[a, b]], Sort[Append[rest, k]]}]]],
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
fzpPrice[shapes_, out_, sd_, path_] := Module[{holders, state, price = 0, largest = 0, w, a, b, k, c},
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
fzpSubsetBest[shapes_, out_, sd_] := Module[{n = Length[shapes], legsets = Union /@ shapes, legsOf, best = <||>, all, cost},
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
fzpRandomNetwork[seed_, n_, extra_, hyper_, open_, maxTotal_ : 200000] := Module[{try = seed, net},
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

(* {shapes, out, sizes} for seed and size class; tensors of ones for path questions *)
fzpNet[seed_, n_, extra_, hyper_] := fzpRandomNetwork[seed, n, extra, hyper, 2];
fzpOnes[{shapes_, out_, sd_}] := TensorNetwork[ConstantArray[1., Lookup[sd, #]] & /@ shapes, shapes -> out];
fzpComplex[{shapes_, out_, sd_}, seed_] := BlockRandom[SeedRandom[seed];
    RandomComplex[{-1 - I, 1 + I}, Lookup[sd, #]] & /@ shapes];

fzpOptimalQ[net : {shapes_, out_, sd_}] := With[{tn = fzpOnes[net]},
    First[fzpPathCosts[shapes, out, sd, OptimalContractionPath[tn, Method -> "flops"]]] === fzpBest[shapes, out, sd, "flops"] &&
        Last[fzpPathCosts[shapes, out, sd, OptimalContractionPath[tn, Method -> "size"]]] === fzpBest[shapes, out, sd, "size"]
];

fzpGreedyQ[net : {shapes_, out_, sd_}, w_] := MemberQ[
    fzpGreedyCosts[shapes, out, sd, w],
    First @ fzpPathCosts[shapes, out, sd,
        If[w === 1., GreedyContractionPath[fzpOnes[net]], GreedyContractionPath[fzpOnes[net], "MemoryWeight" -> w]]]
];

(* ----- F-PATHS-1: 24 networks of 4 to 7 tensors with plain bonds: the "flops" and
   "size" paths reach the exhaustive optima. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-fuzz-paths-1-optimal-exhaustive",
    "exhaustive search over orders; 24 seeded networks, 4-7 tensors",
    VerificationTest[
        AllTrue[Flatten[Table[{seed, n}, {n, 4, 7}, {seed, 6}], 1],
            fzpOptimalQ[fzpNet[100 First[#] + Last[#], Last[#], 2, 0]] &],
        True,
        TestID -> "paclet-fuzz-paths-1-optimal-exhaustive"
    ]
];

(* ----- F-PATHS-2: 12 networks of 5 or 6 tensors that also carry an index shared by
   three tensors: both optima, and the greedy path follows the greedy rule. *)
WithCapability[{"OptimalContractionPath", "GreedyContractionPath", "TensorNetwork"},
    "paclet-fuzz-paths-2-hyperedge-optimal-and-greedy",
    "exhaustive search over orders; greedy rule replayed; 12 seeded networks",
    VerificationTest[
        AllTrue[Flatten[Table[{seed, n}, {n, 5, 6}, {seed, 6}], 1],
            With[{net = fzpNet[200 First[#] + Last[#], Last[#], 1, 1]},
                fzpOptimalQ[net] && fzpGreedyQ[net, 1.]] &],
        True,
        TestID -> "paclet-fuzz-paths-2-hyperedge-optimal-and-greedy"
    ]
];

(* ----- F-PATHS-3: "MemoryWeight" 0.3 and 2.5 on 16 networks of 5 to 7 tensors: every
   greedy path costs an amount the greedy rule with that weight can produce. On at
   least a quarter of the cases the weight's costs share nothing with the default
   weight's, so a weight that is ignored is seen. *)
WithCapability[{"GreedyContractionPath", "TensorNetwork"},
    "paclet-fuzz-paths-3-memory-weight",
    "greedy rule replayed with weights 0.3 and 2.5; 16 seeded networks",
    VerificationTest[
        Module[{cases, separating},
            cases = Flatten[Table[{fzpNet[300 seed + n, n, 2, 0], w}, {n, {5, 7}}, {seed, 4}, {w, {0.3, 2.5}}], 2];
            separating = Count[cases,
                {{shapes_, out_, sd_}, w_} /; Intersection[fzpGreedyCosts[shapes, out, sd, w], fzpGreedyCosts[shapes, out, sd, 1.]] === {}];
            AllTrue[cases, fzpGreedyQ @@ # &] && separating >= Length[cases] / 4
        ],
        True,
        TestID -> "paclet-fuzz-paths-3-memory-weight"
    ]
];

(* ----- F-PATHS-4: on 12 networks of 4 to 6 tensors (half with a shared index on three
   tensors) with complex random tensors, contracting along the greedy, "flops", "size"
   and two tempered greedy paths, and by default, gives the explicit index sum. *)
WithCapability[{"OptimalContractionPath", "GreedyContractionPath", "TensorNetwork", "TensorNetworkContract"},
    "paclet-fuzz-paths-4-values-along-paths",
    "explicit index sum; 12 seeded networks",
    VerificationTest[
        AllTrue[Flatten[Table[{seed, n, h}, {n, 4, 6}, {seed, 2}, {h, 0, 1}], 2],
            Function[spec, Module[{net, ts, tn, ref},
                net = fzpRandomNetwork[400 spec[[1]] + 10 spec[[2]] + spec[[3]], spec[[2]], 1, spec[[3]], 3, 60000];
                ts = fzpComplex[net, spec[[1]]];
                tn = TensorNetwork[ts, net[[1]] -> net[[2]]];
                ref = fzpOracle[ts, net[[1]], net[[2]]];
                AllTrue[
                    {
                        TensorNetworkContract[tn, GreedyContractionPath[tn]],
                        TensorNetworkContract[tn, OptimalContractionPath[tn, Method -> "flops"]],
                        TensorNetworkContract[tn, OptimalContractionPath[tn, Method -> "size"]],
                        TensorNetworkContract[tn, GreedyContractionPath[tn, "Temperature" -> 1., "RandomSeed" -> 1]],
                        TensorNetworkContract[tn, GreedyContractionPath[tn, "Temperature" -> 1., "RandomSeed" -> 2]],
                        TensorNetworkContract[tn]
                    },
                    fzpClose[#, ref] &]]]],
        True,
        TestID -> "paclet-fuzz-paths-4-values-along-paths"
    ]
];

(* ----- F-PATHS-5: 4 networks of 9 and 10 tensors: the "flops" path reaches the optimum
   found by dynamic programming over connected subsets. *)
WithCapability[{"OptimalContractionPath", "TensorNetwork"},
    "paclet-fuzz-paths-5-larger-optimal",
    "dynamic programming over connected subsets; 4 seeded networks",
    VerificationTest[
        AllTrue[Flatten[Table[{seed, n}, {n, 9, 10}, {seed, 2}], 1],
            With[{net = fzpRandomNetwork[500 First[#] + Last[#], Last[#], 3, 0, 2, Infinity]},
                First[fzpPathCosts[net[[1]], net[[2]], net[[3]], OptimalContractionPath[fzpOnes[net], Method -> "flops"]]] ===
                    fzpSubsetBest @@ net] &],
        True,
        TestID -> "paclet-fuzz-paths-5-larger-optimal"
    ]
];

(* ----- F-PATHS-6: the Automatic planner's price (private pathCost of Contraction.wl)
   of the greedy path and of 3 random valid paths, on 10 networks with and without
   shared indices, equals the documented price rule recomputed here. *)
WithCapability[{"GreedyContractionPath", "TensorNetwork"},
    "paclet-fuzz-paths-6-plan-price",
    "Contraction.wl price rule, recomputed; 10 seeded networks",
    VerificationTest[
        AllTrue[Flatten[Table[{seed, h}, {seed, 5}, {h, 0, 1}], 1],
            Function[spec, Module[{net, tn, input, paths},
                net = fzpRandomNetwork[600 spec[[1]] + spec[[2]], 6, 2, spec[[2]], 2, Infinity];
                tn = fzpOnes[net];
                input = Wolfram`TensorNetworks`Contraction`PackagePrivate`pathCostInput[
                    Wolfram`TensorNetworks`PackageScope`extractContractionParameters[tn]];
                paths = Prepend[
                    BlockRandom[SeedRandom[spec[[1]]]; Table[Table[RandomSample[Range[k], 2], {k, 6, 2, -1}], 3]],
                    GreedyContractionPath[tn]];
                AllTrue[paths, Function[path,
                    With[{got = Wolfram`TensorNetworks`Contraction`PackagePrivate`pathCost[path, input],
                            want = fzpPrice[net[[1]], net[[2]], net[[3]], path]},
                        Abs[First[got] - First[want]] <= 1.*^-12 First[want] && Last[got] == Last[want]]]]]]],
        True,
        TestID -> "paclet-fuzz-paths-6-plan-price"
    ]
];
