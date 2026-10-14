(* Hyperedges, shared outputs, repeated and omitted labels, against an oracle or closed forms *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];


(* ------------------------------------------------------------------ *)
(* Oracle                                                              *)
(* ------------------------------------------------------------------ *)

(* Brute force: add each label assignment's product of entries to its output entry *)
oracle[tensors_, labels_, out_, dims_] := Module[{all = Union @@ labels, acc = <||>},
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

(* Random hyperedge networks with integer entries, so every route must match the oracle exactly *)
randomNetwork[seed_] := BlockRandom[SeedRandom[seed]; Module[{labelCount, labelNames, dims, labels, out},
    labelCount = RandomInteger[{1, 5}];
    labelNames = Symbol["hx" <> ToString[#]] & /@ Range[labelCount];
    dims = AssociationThread[labelNames, RandomInteger[{1, 3}, labelCount]];
    labels = Table[RandomSample[labelNames, RandomInteger[{0, Min[3, labelCount]}]], RandomInteger[{1, 5}]];
    If[RandomReal[] < .2 && labels[[1]] =!= {}, labels[[1]] = Append[labels[[1]], First[labels[[1]]]]];
    out = RandomSample[Union @@ labels, RandomInteger[{0, Length[Union @@ labels]}]];
    {
        If[# === {}, RandomInteger[{-3, 3}], RandomInteger[{-3, 3}, Lookup[dims, #]]] & /@ labels,
        labels, out, dims
    }
]]

oracleDisagreements[route_, seeds_] := Select[
    seeds,
    Function[seed, Module[{tensors, labels, out, dims},
        {tensors, labels, out, dims} = randomNetwork[seed];
        ! TrueQ[
            Quiet @ Check[Normal[route[TensorNetwork[tensors, labels, out]]], $Failed] ===
                oracle[tensors, labels, out, dims]
        ]
    ]]
]


(* ------------------------------------------------------------------ *)
(* Random networks against the oracle                                  *)
(* ------------------------------------------------------------------ *)

(* Each test gives the seeds that disagree with the oracle *)

VerificationTest[
    oracleDisagreements[TensorNetworkContract, Range[120]],
    {},
    TestID -> "Hyperedge_Oracle_Automatic"
]

VerificationTest[
    oracleDisagreements[TensorNetworkContract[#, GreedyContractionPath[#]] &, Range[120]],
    {},
    TestID -> "Hyperedge_Oracle_GreedyPath"
]

VerificationTest[
    oracleDisagreements[ActivateTensors[TensorNetworkContraction[#, GreedyContractionPath[#], Method -> "ArrayDot"]] &, Range[80]],
    {},
    TestID -> "Hyperedge_Oracle_InertArrayDot"
]

VerificationTest[
    oracleDisagreements[ActivateTensors[TensorNetworkContraction[#, GreedyContractionPath[#], Method -> "TensorContract"]] &, Range[80]],
    {},
    TestID -> "Hyperedge_Oracle_InertTensorContract"
]

(* Phase oracle whose batch deltas are too large to densify: ActivateTensors must contract them *)
phaseOracle = BlockRandom[SeedRandom[3]; Module[{wires = Array[Subscript[w, #] &, 5], gates},
    gates = Table[With[{s = Sort @ RandomSample[Range[5], RandomInteger[{1, 4}]]},
        {ArrayReshape[ReplacePart[ConstantArray[1, 2^Length[s]], -1 -> -1], ConstantArray[2, Length[s]]], wires[[s]]}], 12];
    TensorNetwork[
        Prepend[gates[[All, 1]], ArrayReshape[Normalize[RandomComplex[{-1 - I, 1 + I}, 32]], ConstantArray[2, 5]]],
        Prepend[gates[[All, 2]], wires],
        wires
    ]
]];

VerificationTest[
    TimeConstrained[
        Max @ Abs @ Flatten[ActivateTensors[TensorNetworkContraction[phaseOracle, GreedyContractionPath[phaseOracle]]] - TensorNetworkContract[phaseOracle]] < 10^-12,
        10
    ],
    True,
    TestID -> "ActivateTensors_BatchDeltas_ContractedNotExpanded"
]

(* What ArrayContract leaves symbolic comes back dense: two deltas give an explicit array *)
VerificationTest[
    ActivateTensors[Inactive[TensorContract][
        Inactive[TensorProduct][SymbolicDeltaProductArray[{2, 2, 2}, {{1, 2, 3}}], SymbolicDeltaProductArray[{2, 2, 2}, {{1, 2, 3}}]],
        {{3, 4}}
    ]],
    Normal @ SymbolicDeltaProductArray[{2, 2, 2, 2}, {{1, 2, 3, 4}}],
    TestID -> "ActivateTensors_DeltasOnly_Dense"
]

VerificationTest[
    oracleDisagreements[TensorNetworkContract[#, GreedyContractionPath[#], Method -> "Dot"] &, Range[80]],
    {},
    TestID -> "Hyperedge_Oracle_EagerDot"
]

VerificationTest[
    oracleDisagreements[
        TensorNetworkContract[TensorNetwork[If[ArrayQ[#], SparseArray[#], #] & /@ #["Tensors"], #["Hyperedges"], #["Output"]]] &,
        Range[80]
    ],
    {},
    TestID -> "Hyperedge_Oracle_SparseLeaves"
]


(* ------------------------------------------------------------------ *)
(* Closed forms                                                        *)
(* ------------------------------------------------------------------ *)

(* Diagonal-gate circuit: each wire is an output index shared by the state and its gates *)

{psi, g12, g23, g13} = BlockRandom[SeedRandom[5];
    {RandomReal[1, {2, 2, 2}], RandomReal[1, {2, 2}], RandomReal[1, {2, 2}], RandomReal[1, {2, 2}]}];

diagonalCircuit = TensorNetwork[{psi, g12, g23, g13}, {{w1, w2, w3}, {w1, w2}, {w2, w3}, {w1, w3}}, {w1, w2, w3}];

diagonalCircuitValue = Table[psi[[a, b, c]] g12[[a, b]] g23[[b, c]] g13[[a, c]], {a, 2}, {b, 2}, {c, 2}];

VerificationTest[
    Max @ Abs @ Flatten[TensorNetworkContract[diagonalCircuit] - diagonalCircuitValue] < 10^-12,
    True,
    TestID -> "Hyperedge_DiagonalCircuit_Automatic"
]

VerificationTest[
    Max @ Abs @ Flatten[TensorNetworkContract[diagonalCircuit, GreedyContractionPath[diagonalCircuit]] - diagonalCircuitValue] < 10^-12,
    True,
    TestID -> "Hyperedge_DiagonalCircuit_GreedyPath"
]

VerificationTest[
    Max @ Abs @ Flatten[
        TensorNetworkContract[TensorNetwork[diagonalCircuit["Tensors"], diagonalCircuit["Hyperedges"], {w3, w1, w2}]] -
            Transpose[diagonalCircuitValue, {2, 3, 1}]
    ] < 10^-12,
    True,
    TestID -> "Hyperedge_DiagonalCircuit_PermutedOutput"
]

(* Three steps for four tensors: no spiders added *)
VerificationTest[
    Length[GreedyContractionPath[diagonalCircuit]],
    3,
    TestID -> "Hyperedge_PathIsOverOwnTensors"
]

VerificationTest[
    TensorNetworkContract[TensorNetwork[{{1, 2, 3}, {4, 5, 6}, {7, 8, 9}}, {{i}, {i}, {i}}]],
    1 * 4 * 7 + 2 * 5 * 8 + 3 * 6 * 9,
    TestID -> "Hyperedge_SummedOverThreeTensors"
]

(* An output index on exactly two tensors is an elementwise product, not a bond *)
VerificationTest[
    TensorNetworkContract[TensorNetwork[{{1, 2, 3}, {4, 5, 6}}, {{i}, {i}}, {i}]],
    {4, 10, 18},
    TestID -> "SharedOutputLabel_IsElementwise"
]

VerificationTest[
    TensorNetworkContract[TensorNetwork[{{{1, 2}, {3, 4}}}, {{i, i}}, {}]],
    5,
    TestID -> "RepeatedLabel_SummedIsTrace"
]

VerificationTest[
    TensorNetworkContract[TensorNetwork[{{{1, 2}, {3, 4}}}, {{i, i}}, {i}]],
    {1, 4},
    TestID -> "RepeatedLabel_KeptIsDiagonal"
]

VerificationTest[
    TensorNetworkContract[TensorNetwork[{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{i, j}, {j, k}}, {i}]],
    Total[{{1, 2}, {3, 4}} . {{5, 6}, {7, 8}}, {2}],
    TestID -> "OmittedLabel_IsSummed"
]

(* Large sum-free batch step, each side with or without own labels, vs row-wise outer products *)
largeBatchCases = Catenate @ Table[
    BlockRandom[SeedRandom[7]; With[{
        batch = Array[Subscript[b, #] &, 12],
        own = Array[Subscript[o, #] &, ownCount],
        other = Array[Subscript[f, #] &, otherCount],
        x = RandomInteger[{-9, 9}, ConstantArray[2, 12 + ownCount]],
        y = RandomInteger[{-9, 9}, ConstantArray[2, 12 + otherCount]]
    },
        {
            TensorNetwork[{x, y}, {Join[batch, own], Join[batch, other]}, Join[batch, own, other]],
            ArrayReshape[
                MapThread[Outer[Times, #1, #2] &, {ArrayReshape[x, {4096, 2^ownCount}], ArrayReshape[y, {4096, 2^otherCount}]}],
                ConstantArray[2, 12 + ownCount + otherCount]
            ]
        }
    ]],
    {ownCount, 0, 1}, {otherCount, 0, 1}
];

VerificationTest[
    TensorNetworkContract[First[#]] === Last[#] & /@ largeBatchCases,
    {True, True, True, True},
    TestID -> "LargeBatch_ShortRows_FullShapeProduct"
]


(* ------------------------------------------------------------------ *)
(* Scalars                                                             *)
(* ------------------------------------------------------------------ *)

(* TensorProduct[{1, 2}, 0] is the scalar 0, so an exact zero factor must not drop the shape *)

zeroScalarNetwork = TensorNetwork[{0, {1, 2}}, {{}, {i}}, {i}];

VerificationTest[
    TensorNetworkContract[zeroScalarNetwork],
    {0, 0},
    TestID -> "ExactZeroScalar_KeepsShape"
]

VerificationTest[
    ActivateTensors[TensorNetworkContraction[zeroScalarNetwork, GreedyContractionPath[zeroScalarNetwork]]],
    {0, 0},
    TestID -> "ExactZeroScalar_KeepsShapeInert"
]

VerificationTest[
    {GreedyContractionPath[TensorNetwork[{2, 3, 5}, {{}, {}, {}}, {}]], TensorNetworkContract[TensorNetwork[{2, 3, 5}, {{}, {}, {}}, {}]]},
    {{{1, 2}, {1, 2}}, 30},
    TestID -> "ScalarsOnly_PathAndValue"
]


(* ------------------------------------------------------------------ *)
(* Representation by fill                                              *)
(* ------------------------------------------------------------------ *)

filled = SparseArray[{{1, 2}, {3, 4}}];

(* A machine-number SparseArray at least a fifth full is densified to a packed array *)
VerificationTest[
    Developer`PackedArrayQ @ TensorNetworkContract[TensorNetwork[{N[filled], N[filled]}, {{i, j}, {j, k}}]],
    True,
    TestID -> "Fill_DensifiesFilledSparse"
]

(* An exact one stays sparse and exact: it cannot pack, so densifying only loses zeros *)
VerificationTest[
    With[{result = TensorNetworkContract[TensorNetwork[{filled / 2, filled}, {{i, j}, {j, k}}]]},
        {Head[result], Normal[result]}
    ],
    {SparseArray, {{1/2, 2/2}, {3/2, 4/2}} . {{1, 2}, {3, 4}}},
    TestID -> "Fill_KeepsExactValuesExact"
]

VerificationTest[
    Head @ TensorNetworkContract[
        TensorNetwork[{N[filled], N[filled]}, {{i, j}, {j, k}}],
        GreedyContractionPath[TensorNetwork[{N[filled], N[filled]}, {{i, j}, {j, k}}]],
        Method -> {"ArrayDot", "LeafContainer" -> "SparseArray"}
    ],
    SparseArray,
    TestID -> "Fill_ExplicitContainerKept"
]

(* Any machine number converts exact leaves up front; mixed Real and Complex packs as Complex *)

phaseGate = {{1, 1}, {1, Exp[I Pi / 8]}};
machineState = BlockRandom[SeedRandom[6]; RandomComplex[{-1 - I, 1 + I}, {2, 2}]];

VerificationTest[
    With[{result = TensorNetworkContract[TensorNetwork[{machineState, phaseGate}, {{p, q}, {p, q}}, {p, q}]]},
        {Developer`PackedArrayQ[result], Max[Abs[Flatten[result - machineState N[phaseGate]]]] < 10^-14}
    ],
    {True, True},
    TestID -> "Precision_MixedNetworkComputesPacked"
]

VerificationTest[
    TensorNetworkContract[TensorNetwork[{{{2, 3}, {5, 7}}, phaseGate}, {{p, q}, {p, q}}, {p, q}]],
    {{2, 3}, {5, 7 Exp[I Pi / 8]}},
    TestID -> "Precision_ExactNetworkStaysExact"
]

(* A symbolic leaf stays exact beside machine numbers: E^(1. I theta) would not cancel exactly *)
VerificationTest[
    TensorNetworkContract[TensorNetwork[{{0.5, 0.25}, {1, Exp[I theta]}}, {{p}, {p}}, {p}]],
    {0.5, 0.25 Exp[I theta]},
    TestID -> "Precision_SymbolicLeafKeepsItsForm"
]


(* Transpose with a repeated level crashes the kernel on a SparseArray with all nonzeros
   off the diagonal; this leaf, 2% full, stays sparse and so reaches that case *)
offDiagonal = SparseArray[{{1, 2} -> 3., {2, 1} -> 4.}, {10, 10}];

VerificationTest[
    {
        TensorNetworkContract[TensorNetwork[{offDiagonal}, {{i, i}}, {}]] == 0,
        Normal[TensorNetworkContract[TensorNetwork[{offDiagonal}, {{i, i}}, {i}]]] == ConstantArray[0, 10],
        Normal[TensorNetworkContract[TensorNetwork[{offDiagonal + SparseArray[{{3, 3} -> 5.}, {10, 10}]}, {{i, i}}, {i}]]] ==
            Normal[Diagonal[offDiagonal + SparseArray[{{3, 3} -> 5.}, {10, 10}]]]
    },
    {True, True, True},
    TestID -> "SparseDiagonal_OffDiagonalEntriesOnly"
]


(* ------------------------------------------------------------------ *)
(* The binarized network                                               *)
(* ------------------------------------------------------------------ *)

(* An output index's spider keeps an extra leg under the index's name, so the output survives *)
VerificationTest[
    With[{binary = BinaryTensorNetwork[diagonalCircuit]},
        {TensorNetworkQ[binary], BinaryTensorNetworkQ[binary],
            Max @ Abs @ Flatten[TensorNetworkContract[binary] - diagonalCircuitValue] < 10^-12}
    ],
    {True, True, True},
    TestID -> "BinaryTensorNetwork_FreeHyperedgeIsValid"
]

(* A path planned over the binarized network is recognized by its operand count and still runs *)
hyperNetwork = BlockRandom[SeedRandom[8];
    TensorNetwork[RandomInteger[{-3, 3}, {3, 3}] & /@ Range[4], {{a, b}, {a, c}, {a, d}, {b, c}}]];

(* ------------------------------------------------------------------ *)
(* Canonical paths                                                     *)
(* ------------------------------------------------------------------ *)

(* Quadratic reference: renumber the shrinking operand list after every step *)
referenceSteps[treePath_, indices_] := Block[{len, index, path = {}},
    len = Length[indices];
    index = AssociationThread[List /@ indices, Range[len]];
    Scan[
        Block[{pos = Lookup[index, #], min, max, k},
            {min, max} = MinMax[pos];
            k = Length[pos];
            AppendTo[path, pos];
            index = Map[Which[# < min, #, # > max, # - k, True, # - 1] &, index];
            KeyDropFrom[index, #];
            AppendTo[index, # -> --len]
        ] &,
        treePath,
        {0, -3}
    ];
    path
]

randomBinaryTree[n_, seed_] := BlockRandom[SeedRandom[seed];
    Nest[
        Function[pool, With[{p = RandomSample[Range[Length[pool]], 2]}, Append[Delete[pool, List /@ p], pool[[p]]]]],
        List /@ Range[n],
        n - 1
    ][[1]]
]

VerificationTest[
    Select[
        Tuples[{{2, 3, 7, 40, 216}, Range[4]}],
        TreePathToPath[randomBinaryTree @@ #, Range[First[#]]] =!= referenceSteps[randomBinaryTree @@ #, Range[First[#]]] &
    ],
    {},
    TestID -> "CanonicalPath_SameStepsAsBefore"
]

VerificationTest[
    With[{tree = randomBinaryTree[300, 9]}, PathToTreePath[TreePathToPath[tree, Range[300]], Range[300]] === tree],
    True,
    TestID -> "CanonicalPath_RoundTripsThroughTree"
]

(* One-at-a-time path: a tree as deep as the network, past $RecursionLimit if walked recursively *)
deepTree = Fold[{#2, #1} &, {1}, List /@ Range[2, 3000]];

VerificationTest[
    {TreePathQ[deepTree], TreePathToPath[deepTree, Range[3000]] === Prepend[Table[{1, m}, {m, 2999, 2, -1}], {2, 1}]},
    {True, True},
    TestID -> "TreePath_DeepTreeCheckedAndCanonicalized"
]

(* Rotations along a sweep multiply to the rotation by the summed angle *)
VerificationTest[
    With[{angles = Range[1500] / 10.^4},
        Max @ Abs @ Flatten[
            Normal[TensorNetworkContract[
                TensorNetwork[RotationMatrix /@ angles, Table[{k, k + 1}, {k, 1500}], {1, 1501}],
                Prepend[Table[{1, m}, {m, 1499, 2, -1}], {1, 2}]
            ]] - RotationMatrix[Total[angles]]
        ] < 10^-10
    ],
    True,
    TestID -> "Contraction_DeepSweepPath"
]

(* An index on 1000 vectors and the output: greedy takes them one at a time into one product *)
VerificationTest[
    With[{vectors = Table[{1., Exp[I k / 1000.]}, {k, 1000}]},
        Max @ Abs[Normal[TensorNetworkContract[TensorNetwork[vectors, ConstantArray[{i}, 1000], {i}]]] - {1, Exp[I 1001 / 2.]}] < 10^-9
    ],
    True,
    TestID -> "Contraction_IndexOnAThousandTensors"
]


(* Compare values, not containers: the binarized route carries a sparse spider *)
VerificationTest[
    Normal[TensorNetworkContract[hyperNetwork, GreedyContractionPath[BinaryTensorNetwork[hyperNetwork]]]] ===
        Normal[TensorNetworkContract[hyperNetwork]],
    True,
    TestID -> "BinarizedFramePath_StillRuns"
]


(* ------------------------------------------------------------------ *)
(* Path choice                                                         *)
(* ------------------------------------------------------------------ *)

(* Brickwork circuit on which Automatic picks the half-weight greedy path; same value *)
brickwork = BlockRandom[SeedRandom[1]; Module[{v = ConstantArray[0, 16], w, tensors, edges},
    w[q_] := Subscript[x, q, v[[q]]];
    tensors = {ArrayReshape[Normalize[RandomComplex[{-1 - I, 1 + I}, 2^16]], ConstantArray[2, 16]]};
    edges = {Table[w[q], {q, 16}]};
    Do[
        With[{old = {w[q], w[q + 1]}},
            v[[q]]++; v[[q + 1]]++;
            AppendTo[tensors, ArrayReshape[Orthogonalize[RandomComplex[{-1 - I, 1 + I}, {4, 4}]], {2, 2, 2, 2}]];
            AppendTo[edges, Join[{w[q], w[q + 1]}, old]]
        ],
        {layer, 8}, {q, 1 + Mod[layer, 2], 15, 2}
    ];
    TensorNetwork[tensors, edges, Table[w[q], {q, 16}]]
]];

VerificationTest[
    Max @ Abs @ Flatten[TensorNetworkContract[brickwork] - TensorNetworkContract[brickwork, GreedyContractionPath[brickwork]]] < 10^-10,
    True,
    TestID -> "Automatic_HalfWeightPath_SameValue"
]


(* ------------------------------------------------------------------ *)
(* Exact leaves as scaled integer arrays                               *)
(* ------------------------------------------------------------------ *)

(* Random networks, each tensor times an exact factor, vs the oracle; each side goes to
   30 digits separately, since N cannot certify their symbolic difference is zero *)
scaledNetwork[seed_] := BlockRandom[SeedRandom[seed + 1000]; Module[{tensors, labels, out, dims},
    {tensors, labels, out, dims} = randomNetwork[seed];
    {RandomChoice[{1/Sqrt[2], 2/3, Sqrt[3]/5, 1 + Sqrt[2], 1, -7/4}] # & /@ tensors, labels, out, dims}
]];

scaledDisagreements[route_, seeds_] := Select[
    seeds,
    Function[seed, Module[{tensors, labels, out, dims, value},
        {tensors, labels, out, dims} = scaledNetwork[seed];
        value = Quiet @ Check[Normal[route[TensorNetwork[tensors, labels, out]]], $Failed];
        ! TrueQ[value =!= $Failed && Max[Abs[Flatten[{N[value, 30] - N[oracle[tensors, labels, out, dims], 30]}]]] < 10^-25]
    ]]
]

VerificationTest[
    scaledDisagreements[TensorNetworkContract, Range[120]],
    {},
    TestID -> "ExactLeaves_ScaledOracle_Automatic"
]

VerificationTest[
    scaledDisagreements[TensorNetworkContract[#, GreedyContractionPath[#]] &, Range[120]],
    {},
    TestID -> "ExactLeaves_ScaledOracle_GreedyPath"
]

VerificationTest[
    scaledDisagreements[
        TensorNetworkContract[TensorNetwork[If[ArrayQ[#], SparseArray[#], #] & /@ #["Tensors"], #["Hyperedges"], #["Output"]]] &,
        Range[80]
    ],
    {},
    TestID -> "ExactLeaves_ScaledOracle_SparseLeaves"
]

(* Leaves with irrational ratios (E^(I Pi/4)) or a symbol are left unscaled; same value *)
VerificationTest[
    {
        Normal[TensorNetworkContract[TensorNetwork[
            {{1, 1} / Sqrt[2], DiagonalMatrix[{1, Exp[I Pi / 4]}], {{1, 1}, {1, -1}} / Sqrt[2]},
            {{a}, {b, a}, {c, b}},
            {c}
        ]]] - {{1, 1}, {1, -1}} . DiagonalMatrix[{1, Exp[I Pi / 4]}] . {1, 1} / 2 // Simplify,
        Normal[TensorNetworkContract[TensorNetwork[{{{p, q}, {r, s}}, {{1, 1}, {1, -1}} / Sqrt[2]}, {{a, b}, {b, c}}, {a, c}]]] -
            {{p, q}, {r, s}} . {{1, 1}, {1, -1}} / Sqrt[2] // Simplify
    },
    {{0, 0}, {{0, 0}, {0, 0}}},
    TestID -> "ExactLeaves_UnscaledLeavesKept"
]

(* Fully contracted: the factors multiply the scalar *)
VerificationTest[
    TensorNetworkContract[TensorNetwork[{{1, 0}, {{1, 1}, {1, -1}} / Sqrt[2], {{1, 1}, {1, -1}} / Sqrt[2], {1, 0}}, {{a}, {a, b}, {b, c}, {c}}, {}]],
    1,
    TestID -> "ExactLeaves_ScalarResult"
]
