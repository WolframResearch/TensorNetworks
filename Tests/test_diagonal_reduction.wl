(* Diagonal reduction: a tensor zero wherever two legs differ drops one, merging their labels *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];


(* ------------------------------------------------------------------ *)
(* The reduction                                                       *)
(* ------------------------------------------------------------------ *)

(* CZ between Hadamards (legs out1, out2, in1, in2) reduces to its diagonal on the two wires *)
cz = ArrayReshape[DiagonalMatrix[{1, 1, 1, -1}], {2, 2, 2, 2}];
hadamard = {{1, 1}, {1, -1}};
czTensors = {{1, 0}, {1, 0}, hadamard, hadamard, cz, hadamard};
czLabels = {{a}, {b}, {c, a}, {d, b}, {e, f, c, d}, {g, e}};
czReduced = diagonalReduction[czTensors, czLabels, {g, f}];

VerificationTest[
    {czReduced[[2]], czReduced[[1, 5]]},
    {{{a}, {b}, {e, a}, {f, b}, {e, f}, {g, e}}, {{1, 1}, {1, -1}}},
    TestID -> "DiagonalReduction_CZ_Labels"
]

VerificationTest[
    Normal[TensorNetworkContract[TensorNetwork[czReduced[[1]], czReduced[[2]], {g, f}]]],
    Normal[TensorNetworkContract[TensorNetwork[czTensors, czLabels, {g, f}]]],
    TestID -> "DiagonalReduction_CZ_SameValue"
]

VerificationTest[
    With[{sparse = diagonalReduction[SparseArray /@ czTensors, czLabels, {g, f}], machine = diagonalReduction[N[czTensors], czLabels, {g, f}]},
        {Normal[sparse[[1, 5]]], sparse[[2]] === czReduced[[2]], machine[[1, 5]], machine[[2]] === czReduced[[2]]}
    ],
    {{{1, 1}, {1, -1}}, True, {{1., 1.}, {1., -1.}}, True},
    TestID -> "DiagonalReduction_SparseAndMachineAgree"
]

VerificationTest[
    diagonalReduction[{DiagonalMatrix[{1, 2}]}, {{x, y}}, {x, y}],
    None,
    TestID -> "DiagonalReduction_OutputPairRefused"
]

VerificationTest[
    diagonalReduction[{DiagonalMatrix[{1, 2}], {3, 4}}, {{x, y}, {x}}, {y}],
    {{{1, 2}, {3, 4}}, {{y}, {y}}},
    TestID -> "DiagonalReduction_OutputLabelNamesTheClass"
]

VerificationTest[
    diagonalReduction[{{{0.3, 0.5}, {0.7, 0.2}}}, {{x, y}}, {}],
    None,
    TestID -> "DiagonalReduction_FullTensorUntouched"
]

VerificationTest[
    diagonalReduction[{Normal[SymbolicDeltaProductArray[{2, 2, 2}, {{1, 2, 3}}]], {1, 2}, {3, 4}, {5, 6}}, {{p, q, s}, {p}, {q}, {s}}, {}],
    {{{1, 1}, {1, 2}, {3, 4}, {5, 6}}, {{p}, {p}, {p}, {p}}},
    TestID -> "DiagonalReduction_ThreeLegDelta"
]

(* Phase gates on a wire whose ends are both output: all but one gate reduce *)
phase[t_] := DiagonalMatrix[{1, Exp[I t]}];

VerificationTest[
    With[{reduced = diagonalReduction[{phase[1], phase[2], phase[3]}, {{b, a}, {c, b}, {d, c}}, {d, a}]},
        {reduced[[2]], Normal[TensorNetworkContract[TensorNetwork[reduced[[1]], reduced[[2]], {d, a}]]]}
    ],
    {{{a}, {a}, {d, a}}, DiagonalMatrix[{1, Exp[6 I]}]},
    TestID -> "DiagonalReduction_OperatorWireKeepsOneGate"
]

(* 3000 gates on one wire, new label first: union-find must not recurse once per gate *)
longWire = Table[N @ phase[k / 3000], {k, 3000}];

VerificationTest[
    With[{reduced = diagonalReduction[longWire, Table[{k + 1, k}, {k, 3000}], {3001, 1}]},
        {Count[reduced[[1]], _ ? VectorQ], Length[Union @@ reduced[[2]]]}
    ],
    {2999, 2},
    TestID -> "DiagonalReduction_LongOperatorWire"
]

VerificationTest[
    With[{reduced = diagonalReduction[Prepend[longWire, {1., 1.}], Prepend[Table[{k + 1, k}, {k, 3000}], {1}], {3001}]},
        {
            Union @@ reduced[[2]],
            Max @ Abs[Normal[TensorNetworkContract[TensorNetwork[reduced[[1]], reduced[[2]], {3001}]]] - {1, Exp[I 3001 / 2.]}] < 10^-9
        }
    ],
    {{3001}, True},
    TestID -> "DiagonalReduction_LongStateWire"
]

(* Legs 1, 3, 4, 5 share a row-weighted column sum, but only 1 = 5 and 3 = 4 *)
collision = SparseArray[
    {{1, 2, 1, 1, 1, 2}, {1, 1, 2, 2, 1, 1}, {1, 2, 2, 2, 1, 2}, {2, 2, 2, 2, 2, 2}, {2, 2, 1, 1, 2, 2}} -> {2, 3, 5, 7, 11},
    ConstantArray[2, 6]
];

VerificationTest[
    With[{reduced = diagonalReduction[{collision}, {{u1, u2, u3, u4, u5, u6}}, {}]},
        {Dimensions[First[reduced[[1]]]], Sort /@ Values[PositionIndex[First[reduced[[2]]]]] === {{1}, {2}, {3}}}
    ],
    {{2, 2, 2}, True},
    TestID -> "DiagonalReduction_WeightedSumCollision"
]

(* Random sparse integer networks with planted equal legs: reduction keeps the value *)
plantedNetwork[seed_] := BlockRandom[SeedRandom[seed]; Module[{names, dims, labels, tensors, out},
    names = Symbol["dr" <> ToString[#]] & /@ Range[6];
    dims = AssociationThread[names, RandomChoice[{2, 3}, 6]];
    labels = Table[RandomSample[names, RandomInteger[{1, 4}]], RandomInteger[{3, 6}]];
    tensors = Function[tensorLabels, Module[{pos = Transpose[RandomInteger[{1, #}, 6] & /@ Lookup[dims, tensorLabels]], legs},
        Do[
            With[{pair = RandomSample[Range[Length[tensorLabels]], 2]},
                If[dims[tensorLabels[[pair[[1]]]]] == dims[tensorLabels[[pair[[2]]]]], pos[[All, pair[[2]]]] = pos[[All, pair[[1]]]]]
            ],
            {If[Length[tensorLabels] > 1, RandomInteger[{0, 2}], 0]}
        ];
        SparseArray[DeleteDuplicates[pos] -> RandomInteger[{1, 5}, Length[DeleteDuplicates[pos]]], Lookup[dims, tensorLabels]]
    ]] /@ labels;
    out = RandomSample[Union @@ labels, RandomInteger[{0, 2}]];
    {tensors, labels, out}
]];

VerificationTest[
    Select[Range[150], Function[seed, Module[{tensors, labels, out, reduced},
        {tensors, labels, out} = plantedNetwork[seed];
        reduced = diagonalReduction[tensors, labels, out];
        reduced =!= None && Normal[TensorNetworkContract[TensorNetwork[reduced[[1]], reduced[[2]], out]]] =!=
            Normal[TensorNetworkContract[TensorNetwork[tensors, labels, out], GreedyContractionPath[TensorNetwork[tensors, labels, out]]]]
    ]]],
    {},
    TestID -> "DiagonalReduction_RandomPlantedDiagonals"
]

VerificationTest[
    Count[Range[150], _ ? (diagonalReduction @@ plantedNetwork[#] =!= None &)] > 50,
    True,
    TestID -> "DiagonalReduction_RandomPlantedDiagonalsReduce"
]


(* ------------------------------------------------------------------ *)
(* Automatic plans                                                     *)
(* ------------------------------------------------------------------ *)

(* Grover for the all-ones item, diagonals as 2n-leg gates or on the wire labels;
   H X CZ X H is minus the textbook diffusion, hence the (-1)^r *)
grover[n_, r_, onWireLabels_, numeric_] := Module[{v = ConstantArray[0, n], w, tensors = {}, labels = {}, layer, diagonal},
    w[q_] := Subscript[gw, q, v[[q]]];
    layer[m_] := Do[With[{old = w[q]}, v[[q]]++; AppendTo[tensors, numeric[m]]; AppendTo[labels, {w[q], old}]], {q, n}];
    diagonal[] := With[{d = ReplacePart[ConstantArray[1, 2^n], -1 -> -1]},
        If[ onWireLabels,
            AppendTo[tensors, numeric @ ArrayReshape[d, ConstantArray[2, n]]];
            AppendTo[labels, w /@ Range[n]],
            With[{old = w /@ Range[n]},
                v += 1;
                AppendTo[tensors, numeric @ ArrayReshape[DiagonalMatrix[d], ConstantArray[2, 2 n]]];
                AppendTo[labels, Join[w /@ Range[n], old]]
            ]
        ]
    ];
    Do[AppendTo[tensors, numeric[{1, 0}]]; AppendTo[labels, {w[q]}], {q, n}];
    layer[{{1, 1}, {1, -1}} / Sqrt[2]];
    Do[
        diagonal[];
        layer[{{1, 1}, {1, -1}} / Sqrt[2]]; layer[{{0, 1}, {1, 0}}];
        diagonal[];
        layer[{{0, 1}, {1, 0}}]; layer[{{1, 1}, {1, -1}} / Sqrt[2]],
        {r}
    ];
    TensorNetwork[tensors, labels, w /@ Range[n]]
]

markedAmplitude[n_, r_] := (-1)^r Sin[(2 r + 1) ArcSin[2^(-n / 2)]]

(* A bad plan runs out of memory, so each contraction is bounded to $Failed *)
boundedAmplitude[net_, n_] := TimeConstrained[
    MemoryConstrained[Normal[TensorNetworkContract[net]][[Sequence @@ ConstantArray[2, n]]], 2 10^9, $Failed],
    60,
    $Failed
]

(* On wire labels greedy builds products over every wire; the sweep keeps one 2^n state *)
VerificationTest[
    Abs[boundedAmplitude[grover[8, 12, True, Identity], 8] - markedAmplitude[8, 12]] < 10^-12,
    True,
    TestID -> "AutomaticPlan_GroverOnWireLabels_Exact"
]

(* Machine-number 2n-leg diagonals reduce to the wire-label network *)
VerificationTest[
    Abs[boundedAmplitude[grover[8, 3, False, N], 8] - markedAmplitude[8, 3]] < 10^-12,
    True,
    TestID -> "AutomaticPlan_GroverReduced_Machine"
]

(* Exact ones are not reduced, but swept *)
VerificationTest[
    Abs[boundedAmplitude[grover[8, 12, False, Identity], 8] - markedAmplitude[8, 12]] < 10^-12,
    True,
    TestID -> "AutomaticPlan_GroverSwept_Exact"
]

(* Exact Grover along the greedy path: fast only with leaves as scaled integer arrays *)
VerificationTest[
    With[{net = grover[8, 12, False, Identity]},
        Abs[
            TimeConstrained[
                MemoryConstrained[Normal[TensorNetworkContract[net, GreedyContractionPath[net]]][[Sequence @@ ConstantArray[2, 8]]], 2 10^9, $Failed],
                60,
                $Failed
            ] - markedAmplitude[8, 12]
        ] < 10^-12
    ],
    True,
    TestID -> "ExactLeaves_GroverGreedyPath"
]

(* Plans are cached by shape: new diagonal values reuse the reduced plan; a new initial state, or
   a diagonal gate made dense, replans. Each must match the explicit greedy path, which bypasses
   the cache - a reduction reused on the dense gate would take only its diagonal *)
VerificationTest[
    With[{net = grover[8, 3, False, N]},
        TensorNetworkContract[net];
        With[{
            reweighted = TensorNetwork[
                BlockRandom[SeedRandom[7]; If[ArrayDepth[#] == 16, # RandomReal[{0.5, 1.5}, Dimensions[#]], #] & /@ net["Tensors"]],
                net["Hyperedges"], net["Output"]],
            restated = TensorNetwork[Replace[net["Tensors"], {1., 0.} -> {0.6, 0.8}, {1}], net["Hyperedges"], net["Output"]],
            densified = TensorNetwork[
                ReplacePart[net["Tensors"], First[Position[ArrayDepth /@ net["Tensors"], 16]] -> BlockRandom[SeedRandom[8]; RandomReal[{-1, 1}, ConstantArray[2, 16]]]],
                net["Hyperedges"], net["Output"]]
        },
            Max[Abs[Flatten[Normal[TensorNetworkContract[#]] - Normal[TensorNetworkContract[#, GreedyContractionPath[#]]]]]] < 10^-10 & /@
                {reweighted, restated, densified}
        ]
    ],
    {True, True, True},
    TestID -> "AutomaticPlan_CachedByShape"
]
