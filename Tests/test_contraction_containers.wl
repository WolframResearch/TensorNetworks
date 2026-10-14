Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

SeedRandom[11];

randomTensor[d__] := RandomReal[{-1, 1}, {d}]

makeNet[tensors_, indices_] := ToTensorNetworkGraph[TensorNetwork[tensors, indices]]

(* Nets compute in Real32, so parity is to float precision *)
netTolerance = 10^-6

(* Container routes match the plain route to machine precision: conversion reorders arithmetic *)
containerTolerance = 10^-10

netParity[net_, path_] := Block[{ref, g},
    ref = N @ Normal @ TensorNetworkContract[net, path, Method -> "ArrayDot"];
    g = TensorNetworkContraction[net, path, Method -> "NetGraph"];
    If[ Head[g] =!= NetGraph,
        {"NotANet", g},
        If[ Dimensions[g[]] =!= Dimensions[ref],
            {"ShapeMismatch", Dimensions[g[]], Dimensions[ref]},
            Max @ Abs @ Flatten[g[] - ref]
        ]
    ]
]

containerHeads[expr_] :=
    DeleteDuplicates[Head /@ Cases[expr, _NumericArray | _SparseArray | _SymmetrizedArray, All, Heads -> True]]

(* Leaves back to lists, so only the expression structure is compared *)
materializeLeaves[expr_] :=
    expr /. {c_NumericArray :> Normal[c], c_SparseArray :> Normal[c], c_SymmetrizedArray :> Normal[c]}


chainNet = makeNet[{randomTensor[2, 3], randomTensor[3, 4], randomTensor[4, 2]}, {{1, 2}, {2, 3}, {3, 4}}];
rank3Net = makeNet[{randomTensor[2, 3, 4], randomTensor[3, 4, 5]}, {{1, 2, 3}, {2, 3, 4}}];
interleavedNet = makeNet[{randomTensor[2, 3, 4], randomTensor[2, 4]}, {{1, 2, 3}, {1, 3}}];
outerNet = makeNet[{randomTensor[2, 3], randomTensor[4, 5]}, {{1, 2}, {3, 4}}];
symbolicNet = makeNet[{{{x, 0}, {0, x}}, randomTensor[2, 2]}, {{1, 2}, {2, 3}}];
complexNet = makeNet[{{{1. + I, 0.}, {0., 1.}}, randomTensor[2, 2]}, {{1, 2}, {2, 3}}];
conjugateNet = makeNet[{{{Conjugate[y], 0}, {0, Conjugate[y]}}, randomTensor[2, 2]}, {{1, 2}, {2, 3}}];
pairNet = makeNet[{randomTensor[2, 3], randomTensor[3, 4]}, {{1, 2}, {2, 3}}];
scalarNet = makeNet[{randomTensor[4], randomTensor[4]}, {{1}, {1}}];
traceNet = makeNet[{randomTensor[3, 4], randomTensor[3, 4]}, {{1, 2}, {1, 2}}];
singleNet = makeNet[{randomTensor[2, 3]}, {{1, 2}}];


(* ------------------------------------------------------------------ *)
(* "NetGraph" method registration                                      *)
(* ------------------------------------------------------------------ *)

(* The methods list is interchangeable array engines; "NetGraph" gives a net, so is not listed *)

VerificationTest[
    {$TensorNetworkContractionMethods, MemberQ[$TensorNetworkContractionMethods, "NetGraph"]},
    {{"ArrayDotTranspose", "ArrayDot", "Dot", "TensorContract", "TableSum"}, False},
    TestID -> "ContractionMethods_ArrayEnginesOnly"
]

VerificationTest[
    Equal @@ (
        ActivateTensors[TensorNetworkContraction[chainNet, {{1, 2}, {1, 2}}, Method -> #]] & /@
            $TensorNetworkContractionMethods
    ),
    True,
    TestID -> "ContractionMethods_EnginesAgree"
]

VerificationTest[
    Head @ TensorNetworkContraction[chainNet, {{1, 2}, {1, 2}}, Method -> "NetGraph"],
    NetGraph,
    TestID -> "NetGraphMethod_ProducesNet"
]


(* ------------------------------------------------------------------ *)
(* The trailing transpose keeps its head                               *)
(* ------------------------------------------------------------------ *)

(* This path ends in a transpose, the one place "TransposeFunction" is spliced in;
   Inactive holds, so a head not substituted lexically survives as a private symbol *)

transposePath = {{1, 2}, {1, 2}};

VerificationTest[
    Head /@ (TensorNetworkContraction[chainNet, transposePath, Method -> #] & /@ $TensorNetworkContractionMethods),
    ConstantArray[Inactive[Transpose], Length[$TensorNetworkContractionMethods]],
    TestID -> "TransposeFunction_DefaultHeadIsTranspose"
]

VerificationTest[
    (
        ActivateTensors[TensorNetworkContraction[chainNet, transposePath, Method -> #]] ==
            TensorNetworkContract[chainNet, transposePath, Method -> #]
    ) & /@ $TensorNetworkContractionMethods,
    ConstantArray[True, Length[$TensorNetworkContractionMethods]],
    TestID -> "TransposeFunction_ActivatesToContractedValue"
]

VerificationTest[
    Head @ TensorNetworkContraction[chainNet, transposePath, "TransposeFunction" -> myTranspose],
    Inactive[myTranspose],
    TestID -> "TransposeFunction_CustomHeadIsKept"
]

(* An unsubstituted transpose head would collapse the tree to a rank-0 leaf *)
VerificationTest[
    With[{tree = ContractionTree[TensorNetworkContraction[chainNet, transposePath]]},
        {TreeSize[tree] > 2, MatchQ[TreeData[tree], ArraySymbol["T", {_Integer, _Integer}]]}
    ],
    {True, True},
    TestID -> "TransposeFunction_ContractionTreeKeepsTransposeNode"
]


(* ------------------------------------------------------------------ *)
(* Parity with "ArrayDot" across network shapes and paths              *)
(* ------------------------------------------------------------------ *)

VerificationTest[
    netParity[chainNet, {{1, 2}, {1, 2}}] < netTolerance,
    True,
    TestID -> "NetGraphParity_MatrixChain_Path1"
]

VerificationTest[
    netParity[chainNet, {{2, 3}, {1, 2}}] < netTolerance,
    True,
    TestID -> "NetGraphParity_MatrixChain_Path2"
]

VerificationTest[
    netParity[rank3Net, {{1, 2}}] < netTolerance,
    True,
    TestID -> "NetGraphParity_Rank3TwoContractedIndices"
]

(* Contracted legs 1 and 3 leave the last level fixed: PermutationList needs the explicit rank *)
VerificationTest[
    netParity[interleavedNet, {{1, 2}}] < netTolerance,
    True,
    TestID -> "NetGraphParity_InterleavedContractedIndices"
]

VerificationTest[
    netParity[outerNet, {{1, 2}}] < netTolerance,
    True,
    TestID -> "NetGraphParity_DisconnectedOuterProduct"
]

VerificationTest[
    netParity[outerNet, OptimalContractionPath[outerNet]] < netTolerance,
    True,
    TestID -> "NetGraphParity_DisconnectedOuterProduct_OptimalPath"
]

VerificationTest[
    Max @ Abs @ Flatten[
        TensorNetworkContraction[chainNet, {{1, 2}, {1, 2}}, Method -> "NetGraph"][] -
        TensorNetworkContraction[chainNet, {{2, 3}, {1, 2}}, Method -> "NetGraph"][]
    ] < netTolerance,
    True,
    TestID -> "NetGraphParity_TwoPathsAgree"
]

(* Rank-0 result: the pair lowering dots vectors instead of reshaping to matrices *)
VerificationTest[
    Block[{g = TensorNetworkContraction[scalarNet, {{1, 2}}, Method -> "NetGraph"]},
        Head[g] === NetGraph && Abs[g[] - TensorNetworkContract[scalarNet, {{1, 2}}]] < netTolerance
    ],
    True,
    TestID -> "NetGraphParity_ScalarResult"
]

VerificationTest[
    Block[{g = TensorNetworkContraction[traceNet, {{1, 2}}, Method -> "NetGraph"]},
        Head[g] === NetGraph && Abs[g[] - TensorNetworkContract[traceNet, {{1, 2}}]] < netTolerance
    ],
    True,
    TestID -> "NetGraphParity_FullyContractedPair"
]

(* One tensor: no pair step; the trailing step lifts the leaf *)
VerificationTest[
    netParity[singleNet, {}] < netTolerance,
    True,
    TestID -> "NetGraphParity_SingleTensor"
]

(* Reordered free indices: the net gets an appended TransposeLayer *)
VerificationTest[
    NetExtract[TensorNetworkContraction[rank3Net, {{1, 2}}, Method -> "NetGraph"], "Output"],
    Dimensions[N @ Normal @ TensorNetworkContract[rank3Net, {{1, 2}}]],
    TestID -> "NetGraphParity_OutputPortDimensions"
]


(* ------------------------------------------------------------------ *)
(* "Inactive" for the net container                                    *)
(* ------------------------------------------------------------------ *)

VerificationTest[
    Head @ TensorNetworkContract[pairNet, {{1, 2}}, Method -> "NetGraph"],
    List,
    TestID -> "NetGraphInactive_ContractMaterializes"
]

VerificationTest[
    Max @ Abs @ Flatten[
        TensorNetworkContract[pairNet, {{1, 2}}, Method -> "NetGraph"] -
        N @ Normal @ TensorNetworkContract[pairNet, {{1, 2}}]
    ] < netTolerance,
    True,
    TestID -> "NetGraphInactive_ContractValue"
]

VerificationTest[
    Head @ TensorNetworkContraction[pairNet, Automatic, Method -> "NetGraph"],
    NetGraph,
    TestID -> "NetGraphPath_AutomaticUsesOptimalPath"
]

VerificationTest[
    Head @ TensorNetworkContraction[pairNet, Method -> "NetGraph"],
    NetGraph,
    TestID -> "NetGraphPath_OmittedUsesOptimalPath"
]


(* ------------------------------------------------------------------ *)
(* Symbolic leaves become net input ports                              *)
(* ------------------------------------------------------------------ *)

VerificationTest[
    Keys @ Information[TensorNetworkContraction[symbolicNet, {{1, 2}}, Method -> "NetGraph"], "InputPorts"],
    {"x"},
    TestID -> "NetGraphSymbolic_InputPort"
]

VerificationTest[
    Max @ Abs @ Flatten[
        TensorNetworkContraction[symbolicNet, {{1, 2}}, Method -> "NetGraph"][<|"x" -> 0.37|>] -
        N @ Normal[TensorNetworkContract[symbolicNet, {{1, 2}}] /. x -> 0.37]
    ] < netTolerance,
    True,
    TestID -> "NetGraphSymbolic_Parity"
]


(* ------------------------------------------------------------------ *)
(* TensorNetworkToNetGraph keeps working                               *)
(* ------------------------------------------------------------------ *)

VerificationTest[
    Head @ TensorNetworkToNetGraph[chainNet],
    NetGraph,
    TestID -> "TensorNetworkToNetGraph_OnePathArgument"
]

VerificationTest[
    Head @ TensorNetworkToNetGraph[chainNet, {{1, 2}, {1, 2}}],
    NetGraph,
    TestID -> "TensorNetworkToNetGraph_ExplicitPath"
]

VerificationTest[
    Max @ Abs @ Flatten[
        TensorNetworkToNetGraph[chainNet][] -
        N @ Normal @ TensorNetworkContract[chainNet, OptimalContractionPath[chainNet]]
    ] < netTolerance,
    True,
    TestID -> "TensorNetworkToNetGraph_Value"
]

VerificationTest[
    TensorNetworkToNetGraph[chainNet, {{1, 2}, {1, 2}}][] ===
        TensorNetworkContraction[chainNet, {{1, 2}, {1, 2}}, Method -> "NetGraph"][],
    True,
    TestID -> "TensorNetworkToNetGraph_SameAsNetGraphMethod"
]


(* ------------------------------------------------------------------ *)
(* "LeafContainer" submethod                                           *)
(* ------------------------------------------------------------------ *)

VerificationTest[
    Table[
        materializeLeaves @ TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {method, "LeafContainer" -> container}] ===
            TensorNetworkContraction[pairNet, {{1, 2}}, Method -> method],
        {method, {"ArrayDot", "ArrayDotTranspose", "Dot", "TensorContract", "TableSum"}},
        {container, {"List", "SparseArray", "NumericArray", "SymmetrizedArray"}}
    ],
    ConstantArray[True, {5, 4}],
    TestID -> "LeafContainer_StructurePreserved"
]

VerificationTest[
    Table[
        containerHeads @ TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"TensorContract", "LeafContainer" -> container}],
        {container, {"SparseArray", "NumericArray", "SymmetrizedArray"}}
    ],
    {{SparseArray}, {NumericArray}, {SymmetrizedArray}},
    TestID -> "LeafContainer_LeafHeads"
]

VerificationTest[
    containerHeads @ TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"TensorContract", "LeafContainer" -> "List"}],
    {},
    TestID -> "LeafContainer_ListLeavesAreLists"
]

(* The path-free EinsteinSummation route converts leaves too *)
VerificationTest[
    containerHeads @ TensorNetworkContraction[pairNet, Method -> {"TensorContract", "LeafContainer" -> "NumericArray"}],
    {NumericArray},
    TestID -> "LeafContainer_NoPathRoute"
]

(* Compute-native containers activate to the same value, to a tolerance: containers reorder arithmetic *)
VerificationTest[
    Table[
        Max @ Abs @ Flatten[
            Normal @ TensorNetworkContract[pairNet, {{1, 2}}, Method -> {"ArrayDot", "LeafContainer" -> container}] -
            Normal @ TensorNetworkContract[pairNet, {{1, 2}}, Method -> "ArrayDot"]
        ] < containerTolerance,
        {container, {"List", "SparseArray"}}
    ],
    {True, True},
    TestID -> "LeafContainer_ActivatedValue"
]

(* An array for every container: NumericArray has no ArrayDot rule, so leaves are materialized *)
VerificationTest[
    Table[
        With[{value = TensorNetworkContract[pairNet, {{1, 2}}, Method -> {method, "LeafContainer" -> container}]},
            {
                ArrayQ[value],
                Max @ Abs @ Flatten[value - TensorNetworkContract[pairNet, {{1, 2}}, Method -> method]] < containerTolerance
            }
        ],
        {method, $TensorNetworkContractionMethods},
        {container, {"List", "SparseArray", "NumericArray", "SymmetrizedArray"}}
    ],
    ConstantArray[{True, True}, {Length[$TensorNetworkContractionMethods], 4}],
    TestID -> "LeafContainer_EagerContractionGivesAnArray"
]

VerificationTest[
    Head @ TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"NetGraph", "LeafContainer" -> "NumericArray"}],
    NetGraph,
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




(* A fully contracted leaf is a scalar: materializing it must not leave an inert ArrayMaterialize *)
VerificationTest[
    arrayContainerMaterialize[0.5 - 0.25 I],
    0.5 - 0.25 I,
    TestID -> "ContainerRoute_MaterializeIsTotalOnScalars"
]

VerificationTest[
    arrayContainerMaterialize[3],
    3,
    TestID -> "ContainerRoute_MaterializeIsTotalOnIntegers"
]

VerificationTest[
    arrayContainerMaterialize[NumericArray[{{1., 2.}, {3., 4.}}, "Real64"]],
    {{1., 2.}, {3., 4.}},
    TestID -> "ContainerRoute_MaterializeStillMaterializesContainers"
]
