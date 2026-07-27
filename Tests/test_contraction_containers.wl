(* Setup *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* Pin RNG seed so the parity numbers are reproducible across runs. *)
SeedRandom[11];

randomTensor[d__] := RandomReal[{-1, 1}, {d}]

makeNet[tensors_, indices_] := ToTensorNetworkGraph[TensorNetwork[tensors, indices]]

(* Nets carry Real32 weights, so parity with the Real64 array contraction is
   float-precision, not exact. *)
netTolerance = 10^-6

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

(* The leaf containers are materialized back so that only the structure of the
   contraction expression is compared with the one the plain method gives. *)
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

(* $TensorNetworkContractionMethods is the list of INTERCHANGEABLE ARRAY
   ENGINES: every entry has to activate to the same array, which is what the
   reference page example and any user code that loops over the list rely on.
   "NetGraph" returns a net, so it is a Method value but not a member. *)

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

(* This path leaves the free indices in the wrong order, so the result carries a
   trailing transpose - the one place the "TransposeFunction" option is spliced
   into the returned inactive expression.  Inactive HOLDS its argument, so a head
   that is looked up rather than substituted lexically survives as a private
   symbol, and the expression then activates to that unevaluated head wrapped
   around the UN-transposed array, with no message and no $Failed.  The whole
   engine list is checked, since the splice happens once for all of them. *)

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

(* A caller-supplied "TransposeFunction" reaches the result rather than being
   silently discarded. *)
VerificationTest[
    Head @ TensorNetworkContraction[chainNet, transposePath, "TransposeFunction" -> myTranspose],
    Inactive[myTranspose],
    TestID -> "TransposeFunction_CustomHeadIsKept"
]

(* The trailing transpose is a node of the contraction tree; a head that failed
   to substitute matches no node rule, falls through to the leaf rule and
   collapses the whole tree to a rank-0 leaf. *)
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

(* The contracted indices sit at positions 1 and 3 of the first tensor, so the
   pre-dot permutation fixes the trailing level; a PermutationList without the
   explicit rank would come back too short here. *)
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

(* A fully contracted network has a rank-0 result, where the pair lowering has
   to dot vectors instead of reshaping to matrices. *)
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

(* A single-tensor network never reaches a pair handler: the leaf is lifted by
   the trailing step. *)
VerificationTest[
    netParity[singleNet, {}] < netTolerance,
    True,
    TestID -> "NetGraphParity_SingleTensor"
]

(* Free indices in a different order than the contraction leaves them exercise
   the trailing transpose, which for a net is an appended TransposeLayer. *)
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

(* The path-free EinsteinSummation route converts its leaves too. *)
VerificationTest[
    containerHeads @ TensorNetworkContraction[pairNet, Method -> {"TensorContract", "LeafContainer" -> "NumericArray"}],
    {NumericArray},
    TestID -> "LeafContainer_NoPathRoute"
]

(* Compute-native containers still activate to the same value. *)
VerificationTest[
    Table[
        Max @ Abs @ Flatten[
            Normal @ TensorNetworkContract[pairNet, {{1, 2}}, Method -> {"ArrayDot", "LeafContainer" -> container}] -
            Normal @ TensorNetworkContract[pairNet, {{1, 2}}, Method -> "ArrayDot"]
        ] == 0,
        {container, {"List", "SparseArray"}}
    ],
    {True, True},
    TestID -> "LeafContainer_ActivatedValue"
]

(* TensorNetworkContract is the EAGER entry point and must return an array for
   every engine and every leaf container.  A storage-only container such as
   NumericArray has no ArrayDot, Dot or TensorContract rule, so without
   materializing the leaves back the contraction expression comes out
   unevaluated - head ArrayDot, ArrayQ False - with no message and no $Failed,
   and a caller that Confirms an array propagates a symbolic expression. *)
VerificationTest[
    Table[
        With[{value = TensorNetworkContract[pairNet, {{1, 2}}, Method -> {method, "LeafContainer" -> container}]},
            {
                ArrayQ[value],
                Max @ Abs @ Flatten[value - TensorNetworkContract[pairNet, {{1, 2}}, Method -> method]] == 0
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

(* THE NAME IS NOT A DISPATCH INTO System`.  "Sow", "Print" and "Quit" resolve
   through NameQ / Symbol exactly as a container name does, and applying one to
   every leaf tensor has a side effect that silentConstruct - Quiet@Check -
   suppresses the messages of but not the effect.  "Sow" makes that observable:
   a Reap around the contraction collects nothing, so no leaf was ever handed to
   the resolved symbol. *)
VerificationTest[
    Reap[{
        TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"ArrayDot", "LeafContainer" -> "Sow"}],
        TensorNetworkContraction[pairNet, {{1, 2}}, Method -> {"ArrayDot", "LeafContainer" -> "Quit"}]
    }],
    {{$Failed, $Failed}, {}},
    {TensorNetworkContraction::leafname, TensorNetworkContraction::leafname},
    TestID -> "LeafContainerFailure_NameIsNotADispatchIntoSystem"
]

(* NameQ also accepts string PATTERNS, so a name with a metacharacter would
   reach Symbol["System`Sp*"]; a literal-membership check is what stops it. *)
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




(* A fully contracted leaf is a scalar, and the materialization route is called
   on it.  ArrayMaterialize answers for containers and is left unevaluated by
   anything else, so an unguarded call leaves an inert ArrayMaterialize[...] in
   the value, which then poisons every expression built from it - QuantumFramework
   state preparation returned Re[Sqrt[ArrayMaterialize[...] Conjugate[...]]]
   instead of a fidelity of 1. *)
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
