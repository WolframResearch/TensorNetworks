(* Tests/test_hyperedge_contraction.wl

   Contraction of networks whose indices are not all plain bonds: an index on
   three or more tensors (a hyperedge), an output index two or more tensors
   share, a label repeated within one tensor, and a label the output leaves out.
   Such an index is kept, once, on every step that still needs it, so a
   hyperedge is contracted without binarizing it into a delta spider.

   Every value here is checked against an answer computed independently of the
   paclet: an oracle that sums the network over every assignment of every label,
   or the closed form a small case has. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];


(* ------------------------------------------------------------------ *)
(* Oracle                                                              *)
(* ------------------------------------------------------------------ *)

(* The network summed term by term: every assignment of every label contributes
   the product of the tensor entries it selects to the output entry it selects. *)
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

(* Networks the plain-bond case never produces: labels on any number of tensors,
   an output drawn from any of them, now and then a label repeated within a
   tensor, and rank-0 tensors.  Entries are integers, so every route has to
   agree with the oracle exactly. *)
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

(* The seeds whose result disagrees with the oracle, so a failure names them. *)

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

(* The shape a quantum circuit of diagonal gates takes: a state on three wires
   and each gate given as its diagonal on the wires it acts on, so every wire is
   an output index shared by the state and every gate on it.  This failed with
   TensorNetwork::output while hyperedges were binarized. *)

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

(* The output in another order is the same array transposed. *)
VerificationTest[
    Max @ Abs @ Flatten[
        TensorNetworkContract[TensorNetwork[diagonalCircuit["Tensors"], diagonalCircuit["Hyperedges"], {w3, w1, w2}]] -
            Transpose[diagonalCircuitValue, {2, 3, 1}]
    ] < 10^-12,
    True,
    TestID -> "Hyperedge_DiagonalCircuit_PermutedOutput"
]

(* A path of a hyperedge network is over the network's own tensors. *)
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

(* An output index exactly two tensors share is binary by count but not a bond:
   it is an elementwise product, and used to be summed. *)
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

(* A label of the network that an explicit output leaves out is summed. *)
VerificationTest[
    TensorNetworkContract[TensorNetwork[{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{i, j}, {j, k}}, {i}]],
    Total[{{1, 2}, {3, 4}} . {{5, 6}, {7, 8}}, {2}],
    TestID -> "OmittedLabel_IsSummed"
]

(* A step that sums nothing, over a batch of 4096 with short rows - diagonal
   gates merged over most of a circuit's wires - multiplies its operands
   brought to the full shape, with a branch for each of the two sides having
   labels of its own or none.  Each is checked against the row-by-row outer
   products. *)
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

(* TensorProduct[{1, 2}, 0] is the scalar 0, so a step that multiplied by an
   exact zero through TensorProduct lost the shape of the result. *)

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

(* A network with no index at all still has a path, any order. *)
VerificationTest[
    {GreedyContractionPath[TensorNetwork[{2, 3, 5}, {{}, {}, {}}, {}]], TensorNetworkContract[TensorNetwork[{2, 3, 5}, {{}, {}, {}}, {}]]},
    {{{1, 2}, {1, 2}}, 30},
    TestID -> "ScalarsOnly_PathAndValue"
]


(* ------------------------------------------------------------------ *)
(* Representation by fill                                              *)
(* ------------------------------------------------------------------ *)

filled = SparseArray[{{1, 2}, {3, 4}}];

(* A SparseArray at least a fifth full computes faster dense, so an evaluated
   contraction with no container asked for densifies it - into a packed array
   when its values are machine numbers ... *)
VerificationTest[
    Developer`PackedArrayQ @ TensorNetworkContract[TensorNetwork[{N[filled], N[filled]}, {{i, j}, {j, k}}]],
    True,
    TestID -> "Fill_DensifiesFilledSparse"
]

(* ... and never by coercing exact values: the coercing packers turn 1/2 into 0.5. *)
VerificationTest[
    TensorNetworkContract[TensorNetwork[{filled / 2, filled}, {{i, j}, {j, k}}]],
    {{1/2, 2/2}, {3/2, 4/2}} . {{1, 2}, {3, 4}},
    TestID -> "Fill_KeepsExactValuesExact"
]

(* A container asked for is a container kept. *)
VerificationTest[
    Head @ TensorNetworkContract[
        TensorNetwork[{N[filled], N[filled]}, {{i, j}, {j, k}}],
        GreedyContractionPath[TensorNetwork[{N[filled], N[filled]}, {{i, j}, {j, k}}]],
        Method -> {"ArrayDot", "LeafContainer" -> "SparseArray"}
    ],
    SparseArray,
    TestID -> "Fill_ExplicitContainerKept"
]

(* A network holding a machine number anywhere contracts to machine numbers, so
   its exact tensors are converted once, up front; the numeric diagonal of an
   exact phase gate mixes Real and Complex entries and still packs, as Complex. *)

phaseGate = {{1, 1}, {1, Exp[I Pi / 8]}};
machineState = BlockRandom[SeedRandom[6]; RandomComplex[{-1 - I, 1 + I}, {2, 2}]];

VerificationTest[
    With[{result = TensorNetworkContract[TensorNetwork[{machineState, phaseGate}, {{p, q}, {p, q}}, {p, q}]]},
        {Developer`PackedArrayQ[result], Max[Abs[Flatten[result - machineState N[phaseGate]]]] < 10^-14}
    ],
    {True, True},
    TestID -> "Precision_MixedNetworkComputesPacked"
]

(* With no machine number anywhere the same network stays exact. *)
VerificationTest[
    TensorNetworkContract[TensorNetwork[{{{2, 3}, {5, 7}}, phaseGate}, {{p, q}, {p, q}}, {p, q}]],
    {{2, 3}, {5, 7 Exp[I Pi / 8]}},
    TestID -> "Precision_ExactNetworkStaysExact"
]


(* Transpose with a repeated level crashes the kernel on a SparseArray whose
   nonzeros all lie off that diagonal; a sparse leaf's diagonal is taken from its
   stored entries instead.  The leaf is 2% full, so it stays sparse and reaches
   that path rather than being densified first. *)
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

(* The spider of an output index carries one more leg, under the index's own
   name, so the binarized network still has the output it declares. *)
VerificationTest[
    With[{binary = BinaryTensorNetwork[diagonalCircuit]},
        {TensorNetworkQ[binary], BinaryTensorNetworkQ[binary],
            Max @ Abs @ Flatten[TensorNetworkContract[binary] - diagonalCircuitValue] < 10^-12}
    ],
    {True, True, True},
    TestID -> "BinaryTensorNetwork_FreeHyperedgeIsValid"
]

(* A path planned over the binarized network - the frame a hyperedge network's
   path had before - is recognized by its operand count and still runs. *)
hyperNetwork = BlockRandom[SeedRandom[8];
    TensorNetwork[RandomInteger[{-3, 3}, {3, 3}] & /@ Range[4], {{a, b}, {a, c}, {a, d}, {b, c}}]];

(* ------------------------------------------------------------------ *)
(* Canonical paths                                                     *)
(* ------------------------------------------------------------------ *)

(* Canonicalizing renumbers each step's operands by their positions in the
   shrinking operand list.  It used to renumber every position after each step,
   which is quadratic; it now counts live operands in a Fenwick tree.  The path
   must be the same one, step for step, so the former renumbering is kept here
   as the reference. *)
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


(* The two routes may store the result differently - the binarized one carries
   a sparse spider - so the values are compared, not the containers. *)
VerificationTest[
    Normal[TensorNetworkContract[hyperNetwork, GreedyContractionPath[BinaryTensorNetwork[hyperNetwork]]]] ===
        Normal[TensorNetworkContract[hyperNetwork]],
    True,
    TestID -> "BinarizedFramePath_StillRuns"
]
