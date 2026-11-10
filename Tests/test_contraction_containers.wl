(* Contraction containers: every engine, the "NetGraph" net and the "LeafContainer" leaves,
   each checked against an explicit sum over index assignments *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

SeedRandom[11];

randomTensor[d__] := RandomReal[{-1, 1}, {d}]


(* ------------------------------------------------------------------ *)
(* Oracle                                                              *)
(* ------------------------------------------------------------------ *)

(* Brute force: add each label assignment's product of entries to its output entry *)
oracle[tensors_, labels_, out_] := Module[{dims, all = Union @@ labels, acc = <||>},
    dims = Association @ Flatten @ MapThread[Thread[#2 -> Dimensions[#1]] &, {tensors, labels}];
    Scan[
        Function[assignment, With[{value = AssociationThread[all, assignment]},
            With[{
                key = Lookup[value, out],
                term = Times @@ MapThread[Extract[#1, Lookup[value, #2]] &, {tensors, labels}]
            },
                acc[key] = Lookup[acc, Key[key], 0] + term
            ]
        ]],
        Tuples[Range /@ Lookup[dims, all]]
    ];
    If[out === {}, Lookup[acc, Key[{}], 0], Array[Lookup[acc, Key[{##}], 0] &, Lookup[dims, out]]]
]

(* Largest entrywise distance; a shape mismatch is infinitely far *)
distance[x_, y_] := With[{a = N @ Normal[x], b = N @ Normal[y]},
    If[Dimensions[a] =!= Dimensions[b], Infinity, Max[Abs[Flatten[{a - b}]]]]
]

(* A case is {tensors, labels, free labels in output order}; the net is its graph form *)
caseNet[{tensors_, labels_, _}] := ToTensorNetworkGraph[TensorNetwork[tensors, labels]]
caseValue[{tensors_, labels_, out_}] := oracle[tensors, labels, out]

(* Nets compute in Real32, so they match to float precision *)
netTolerance = 10^-5

(* Every other route computes in machine reals *)
machineTolerance = 10^-10

chainCase = {{randomTensor[2, 3], randomTensor[3, 4], randomTensor[4, 2]}, {{1, 2}, {2, 3}, {3, 4}}, {1, 4}};
rank3Case = {{randomTensor[2, 3, 4], randomTensor[3, 4, 5]}, {{1, 2, 3}, {2, 3, 4}}, {1, 4}};
interleavedCase = {{randomTensor[2, 3, 4], randomTensor[2, 4]}, {{1, 2, 3}, {1, 3}}, {2}};
outerCase = {{randomTensor[2, 3], randomTensor[4, 5]}, {{1, 2}, {3, 4}}, {1, 2, 3, 4}};
pairCase = {{randomTensor[2, 3], randomTensor[3, 4]}, {{1, 2}, {2, 3}}, {1, 3}};
scalarCase = {{randomTensor[4], randomTensor[4]}, {{1}, {1}}, {}};
traceCase = {{randomTensor[3, 4], randomTensor[3, 4]}, {{1, 2}, {1, 2}}, {}};
singleCase = {{randomTensor[2, 3]}, {{1, 2}}, {1, 2}};

{chainNet, rank3Net, interleavedNet, outerNet, pairNet, scalarNet, traceNet, singleNet} =
    caseNet /@ {chainCase, rank3Case, interleavedCase, outerCase, pairCase, scalarCase, traceCase, singleCase};

symbolicMatrix = randomTensor[2, 2];
symbolicNet = ToTensorNetworkGraph[TensorNetwork[{{{x, 0}, {0, x}}, symbolicMatrix}, {{1, 2}, {2, 3}}]];
complexNet = ToTensorNetworkGraph[TensorNetwork[{{{1. + I, 0.}, {0., 1.}}, randomTensor[2, 2]}, {{1, 2}, {2, 3}}]];
conjugateNet = ToTensorNetworkGraph[TensorNetwork[{{{Conjugate[y], 0}, {0, Conjugate[y]}}, randomTensor[2, 2]}, {{1, 2}, {2, 3}}]];

$containers = {"List", "SparseArray", "NumericArray", "SymmetrizedArray"};

containerLeaves[expr_] := Cases[expr, _NumericArray | _SparseArray | _SymmetrizedArray, All]

(* A net's value: the distance from the case's explicit sum, or why there is none *)
netDistance[g_, case_] := If[Head[g] =!= NetGraph, {"NotANet", g}, distance[g[], caseValue[case]]]


(* ------------------------------------------------------------------ *)
(* Array engines                                                       *)
(* ------------------------------------------------------------------ *)

(* The engines below are checked one by one; the list itself must not shrink silently *)
VerificationTest[
    {$TensorNetworkContractionMethods, MemberQ[$TensorNetworkContractionMethods, "NetGraph"]},
    {{"ArrayDotTranspose", "ArrayDot", "Dot", "TensorContract", "TableSum"}, False},
    TestID -> "ContractionMethods_ArrayEnginesOnly"
]

VerificationTest[
    Table[
        {
            distance[ActivateTensors[TensorNetworkContraction[chainNet, path, Method -> method]], caseValue[chainCase]] < machineTolerance,
            distance[TensorNetworkContract[chainNet, path, Method -> method], caseValue[chainCase]] < machineTolerance
        },
        {method, $TensorNetworkContractionMethods},
        {path, {{{1, 2}, {1, 2}}, {{2, 3}, {1, 2}}}}
    ],
    ConstantArray[{True, True}, {Length[$TensorNetworkContractionMethods], 2}],
    TestID -> "ContractionMethods_EachEngineMatchesExplicitSum"
]


(* ------------------------------------------------------------------ *)
(* The trailing transpose keeps its head                               *)
(* ------------------------------------------------------------------ *)

(* This path ends in a transpose, the one place "TransposeFunction" is spliced in;
   Inactive holds, so a head not substituted lexically survives as a private symbol *)

transposePath = {{1, 2}, {1, 2}};

VerificationTest[
    Table[
        With[{inert = TensorNetworkContraction[chainNet, transposePath, Method -> method]},
            {Head[inert], distance[ActivateTensors[inert], caseValue[chainCase]] < machineTolerance}
        ],
        {method, $TensorNetworkContractionMethods}
    ],
    ConstantArray[{Inactive[Transpose], True}, Length[$TensorNetworkContractionMethods]],
    TestID -> "TransposeFunction_DefaultHeadActivatesToExplicitSum"
]

(* The custom head is the one spliced in: put Transpose back and the value is the contraction *)
VerificationTest[
    With[{inert = TensorNetworkContraction[chainNet, transposePath, "TransposeFunction" -> myTranspose]},
        {Head[inert], distance[ActivateTensors[inert /. myTranspose -> Transpose], caseValue[chainCase]] < machineTolerance}
    ],
    {Inactive[myTranspose], True},
    TestID -> "TransposeFunction_CustomHeadIsKept"
]


(* ------------------------------------------------------------------ *)
(* "NetGraph" against the explicit sum, across shapes and paths        *)
(* ------------------------------------------------------------------ *)

VerificationTest[
    netDistance[TensorNetworkContraction[chainNet, {{1, 2}, {1, 2}}, Method -> "NetGraph"], chainCase] < netTolerance,
    True,
    TestID -> "NetGraph_MatrixChain_Path1"
]

VerificationTest[
    netDistance[TensorNetworkContraction[chainNet, {{2, 3}, {1, 2}}, Method -> "NetGraph"], chainCase] < netTolerance,
    True,
    TestID -> "NetGraph_MatrixChain_Path2"
]

VerificationTest[
    netDistance[TensorNetworkContraction[rank3Net, {{1, 2}}, Method -> "NetGraph"], rank3Case] < netTolerance,
    True,
    TestID -> "NetGraph_Rank3TwoContractedIndices"
]

(* Contracted legs 1 and 3 leave the last level fixed: PermutationList needs the explicit rank *)
VerificationTest[
    netDistance[TensorNetworkContraction[interleavedNet, {{1, 2}}, Method -> "NetGraph"], interleavedCase] < netTolerance,
    True,
    TestID -> "NetGraph_InterleavedContractedIndices"
]

VerificationTest[
    netDistance[TensorNetworkContraction[outerNet, {{1, 2}}, Method -> "NetGraph"], outerCase] < netTolerance,
    True,
    TestID -> "NetGraph_DisconnectedOuterProduct"
]

VerificationTest[
    netDistance[TensorNetworkContraction[outerNet, OptimalContractionPath[outerNet], Method -> "NetGraph"], outerCase] < netTolerance,
    True,
    TestID -> "NetGraph_DisconnectedOuterProduct_OptimalPath"
]

(* An explicit output order {4, 3, 1}: the net ends in a TransposeLayer *)
VerificationTest[
    With[{case = {{randomTensor[2, 3, 4], randomTensor[3, 5]}, {{1, 2, 3}, {2, 4}}, {4, 3, 1}}},
        netDistance[
            TensorNetworkContraction[TensorNetwork[case[[1]], case[[2]], case[[3]]], {{1, 2}}, Method -> "NetGraph"],
            case
        ] < netTolerance
    ],
    True,
    TestID -> "NetGraph_ExplicitOutputOrder"
]

(* Rank-0 result: the pair lowering dots vectors instead of reshaping to matrices *)
VerificationTest[
    netDistance[TensorNetworkContraction[scalarNet, {{1, 2}}, Method -> "NetGraph"], scalarCase] < netTolerance,
    True,
    TestID -> "NetGraph_ScalarResult"
]

VerificationTest[
    netDistance[TensorNetworkContraction[traceNet, {{1, 2}}, Method -> "NetGraph"], traceCase] < netTolerance,
    True,
    TestID -> "NetGraph_FullyContractedPair"
]

(* One tensor: no pair step; the trailing step lifts the leaf *)
VerificationTest[
    netDistance[TensorNetworkContraction[singleNet, {}, Method -> "NetGraph"], singleCase] < netTolerance,
    True,
    TestID -> "NetGraph_SingleTensor"
]

(* Without a path, or with Automatic, the net is built on the optimal path *)
VerificationTest[
    {
        netDistance[TensorNetworkContraction[pairNet, Automatic, Method -> "NetGraph"], pairCase] < netTolerance,
        netDistance[TensorNetworkContraction[pairNet, Method -> "NetGraph"], pairCase] < netTolerance
    },
    {True, True},
    TestID -> "NetGraph_AutomaticAndOmittedPath"
]

(* TensorNetworkContract evaluates the net and returns the array *)
VerificationTest[
    With[{value = TensorNetworkContract[pairNet, {{1, 2}}, Method -> "NetGraph"]},
        {Head[value], distance[value, caseValue[pairCase]] < netTolerance}
    ],
    {List, True},
    TestID -> "NetGraph_ContractGivesTheArray"
]


(* ------------------------------------------------------------------ *)
(* Symbolic leaves become net input ports                              *)
(* ------------------------------------------------------------------ *)

VerificationTest[
    With[{g = TensorNetworkContraction[symbolicNet, {{1, 2}}, Method -> "NetGraph"]},
        {
            Keys @ Information[g, "InputPorts"],
            distance[g[<|"x" -> 0.37|>], 0.37 symbolicMatrix] < netTolerance
        }
    ],
    {{"x"}, True},
    TestID -> "NetGraphSymbolic_PortValue"
]


(* ------------------------------------------------------------------ *)
(* TensorNetworkToNetGraph                                             *)
(* ------------------------------------------------------------------ *)

VerificationTest[
    {
        netDistance[TensorNetworkToNetGraph[chainNet], chainCase] < netTolerance,
        netDistance[TensorNetworkToNetGraph[chainNet, {{2, 3}, {1, 2}}], chainCase] < netTolerance
    },
    {True, True},
    TestID -> "TensorNetworkToNetGraph_Value"
]


(* ------------------------------------------------------------------ *)
(* "LeafContainer" submethod                                           *)
(* ------------------------------------------------------------------ *)

(* Each leaf is held in the named container, and holds exactly the input tensor *)
VerificationTest[
    Table[
        With[{inert = TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"TensorContract", "LeafContainer" -> container}]},
            {
                DeleteDuplicates[Head /@ containerLeaves[inert]],
                Sort[N[Normal /@ containerLeaves[inert]]] === Sort[pairCase[[1]]]
            }
        ],
        {container, {"SparseArray", "NumericArray", "SymmetrizedArray"}}
    ],
    {{{SparseArray}, True}, {{NumericArray}, True}, {{SymmetrizedArray}, True}},
    TestID -> "LeafContainer_LeavesAreTheInputTensors"
]

VerificationTest[
    containerLeaves @ TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"TensorContract", "LeafContainer" -> "List"}],
    {},
    TestID -> "LeafContainer_ListLeavesAreLists"
]

(* Every engine and every container: the inert expression, with its leaves materialized,
   activates to the explicit sum *)
VerificationTest[
    Table[
        distance[
            ActivateTensors[
                TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {method, "LeafContainer" -> container}] /.
                    c : (_NumericArray | _SparseArray | _SymmetrizedArray) :> Normal[c]
            ],
            caseValue[pairCase]
        ] < machineTolerance,
        {method, $TensorNetworkContractionMethods},
        {container, $containers}
    ],
    ConstantArray[True, {Length[$TensorNetworkContractionMethods], Length[$containers]}],
    TestID -> "LeafContainer_InertActivatesToExplicitSum"
]

(* The path-free EinsteinSummation route converts leaves too *)
VerificationTest[
    With[{inert = TensorNetworkContraction[pairNet, Method -> {"TensorContract", "LeafContainer" -> "NumericArray"}]},
        {
            DeleteDuplicates[Head /@ containerLeaves[inert]],
            distance[ActivateTensors[inert /. c_NumericArray :> Normal[c]], caseValue[pairCase]] < machineTolerance
        }
    ],
    {{NumericArray}, True},
    TestID -> "LeafContainer_NoPathRoute"
]

(* An array for every engine and container: NumericArray has no ArrayDot rule, so leaves are materialized *)
VerificationTest[
    Table[
        With[{value = TensorNetworkContract[pairNet, {{1, 2}}, Method -> {method, "LeafContainer" -> container}]},
            {ArrayQ[value], distance[value, caseValue[pairCase]] < machineTolerance}
        ],
        {method, $TensorNetworkContractionMethods},
        {container, $containers}
    ],
    ConstantArray[{True, True}, {Length[$TensorNetworkContractionMethods], Length[$containers]}],
    TestID -> "LeafContainer_EagerContractionMatchesExplicitSum"
]

(* Sparse leaves contracted by ArrayDot stay sparse *)
VerificationTest[
    With[{value = TensorNetworkContract[chainNet, {{1, 2}, {1, 2}}, Method -> {"ArrayDot", "LeafContainer" -> "SparseArray"}]},
        {Head[value], distance[value, caseValue[chainCase]] < machineTolerance}
    ],
    {SparseArray, True},
    TestID -> "LeafContainer_SparseInSparseOut"
]

VerificationTest[
    netDistance[TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"NetGraph", "LeafContainer" -> "NumericArray"}], pairCase] < netTolerance,
    True,
    TestID -> "LeafContainer_CombinesWithNetGraph"
]


(* ------------------------------------------------------------------ *)
(* Clean failures                                                      *)
(* ------------------------------------------------------------------ *)

VerificationTest[
    TensorNetworkContraction[complexNet, {{1, 2}}, Method -> "NetGraph"],
    $Failed,
    {TensorNetworkContraction::netleaf},
    TestID -> "NetGraphFailure_ComplexTensor"
]

VerificationTest[
    TensorNetworkContraction[conjugateNet, {{1, 2}}, Method -> "NetGraph"],
    $Failed,
    {TensorNetworkContraction::netleaf},
    TestID -> "NetGraphFailure_UncompilableFunctionLayer"
]

VerificationTest[
    TensorNetworkContract[symbolicNet, {{1, 2}}, Method -> "NetGraph"],
    $Failed,
    {TensorNetworkContraction::netopen},
    TestID -> "NetGraphFailure_OpenNetHasNoValue"
]

VerificationTest[
    TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"ArrayDot", "LeafContainer" -> "Bogus"}],
    $Failed,
    {TensorNetworkContraction::leafname},
    TestID -> "LeafContainerFailure_UnknownTypeName"
]

(* A container name is not a dispatch into System`: Sow must never see a leaf *)
VerificationTest[
    Reap[{
        TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"ArrayDot", "LeafContainer" -> "Sow"}],
        TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"ArrayDot", "LeafContainer" -> "Quit"}]
    }],
    {{$Failed, $Failed}, {}},
    {TensorNetworkContraction::leafname, TensorNetworkContraction::leafname},
    TestID -> "LeafContainerFailure_NameIsNotADispatchIntoSystem"
]

(* NameQ accepts string patterns, so "Sp*" needs a literal membership check *)
VerificationTest[
    {
        TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"ArrayDot", "LeafContainer" -> "Sp*"}],
        TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"ArrayDot", "LeafContainer" -> "Print"}]
    },
    {$Failed, $Failed},
    {TensorNetworkContraction::leafname, TensorNetworkContraction::leafname},
    TestID -> "LeafContainerFailure_NamePatternRejected"
]

VerificationTest[
    TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"ArrayDot", "LeafContainer" -> "QuantityArray"}],
    $Failed,
    {TensorNetworkContraction::leafcont},
    TestID -> "LeafContainerFailure_ConstructorGivesNoContainer"
]

VerificationTest[
    TensorNetworkContraction[symbolicNet, {{1, 2}}, Method -> {"ArrayDot", "LeafContainer" -> "NumericArray"}],
    $Failed,
    {TensorNetworkContraction::leafcont},
    TestID -> "LeafContainerFailure_SymbolicTensor"
]


(* ------------------------------------------------------------------ *)
(* Materializing a leaf                                                *)
(* ------------------------------------------------------------------ *)

(* A fully contracted leaf is a scalar: materializing it must not leave an inert ArrayMaterialize *)
VerificationTest[
    {arrayContainerMaterialize[0.5 - 0.25 I], arrayContainerMaterialize[3]},
    {0.5 - 0.25 I, 3},
    TestID -> "ContainerRoute_MaterializeIsTotalOnScalars"
]

VerificationTest[
    arrayContainerMaterialize[NumericArray[{{1., 2.}, {3., 4.}}, "Real64"]],
    {{1., 2.}, {3., 4.}},
    TestID -> "ContainerRoute_MaterializeStillMaterializesContainers"
]


(* ============================================ *)
(* ActivateTensors on powers of TensorProduct   *)
(* ============================================ *)

(* EinsteinSummation["i->ii"] is the power t (x) t; activated at the top level it is the outer
   product, entry (i, j) = v[[i]] v[[j]] *)
VerificationTest[
    With[{v = {1, 2, 3}},
        ActivateTensors[EinsteinSummation["i->ii", {v}]] === Table[v[[i]] v[[j]], {i, 3}, {j, 3}]
    ],
    True,
    TestID -> "ActivateTensors_TopLevelPower"
]

(* A cube of a matrix, and a power under a contraction: TensorContract of m (x) m over the
   inner pair is m . m *)
VerificationTest[
    With[{m = {{1, 2}, {3, 4}}},
        {
            ActivateTensors[GeneralizedPower[TensorProduct, m, 3]] === Table[m[[a, b]] m[[c, d]] m[[e, f]], {a, 2}, {b, 2}, {c, 2}, {d, 2}, {e, 2}, {f, 2}],
            ActivateTensors[Inactive[TensorContract][GeneralizedPower[TensorProduct, m, 2], {{2, 3}}]] === Table[Sum[m[[i, k]] m[[k, j]], {k, 2}], {i, 2}, {j, 2}]
        }
    ],
    {True, True},
    TestID -> "ActivateTensors_PowerCubeAndContracted"
]

(* A symbolic identity inside a power is made explicit: delta (x) delta *)
VerificationTest[
    ActivateTensors[GeneralizedPower[TensorProduct, SymbolicIdentityArray[{2}], 2]] ===
        Table[KroneckerDelta[a, b] KroneckerDelta[c, d], {a, 2}, {b, 2}, {c, 2}, {d, 2}],
    True,
    TestID -> "ActivateTensors_PowerOfIdentity"
]
