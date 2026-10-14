(* ::Package:: *)

Package["Wolfram`TensorNetworks`"]

PackageExport[TensorNetworkFindContractionPath]

PackageExport[$TensorNetworkContractionMethods]
PackageExport[TensorNetworkContraction]
PackageExport[TensorNetworkContract]

PackageExport[ContractionTree]

PackageScope[packedIfMachine]



Options[TensorNetworkFindContractionPath] = {"ReturnParameters" -> False, Method -> "Optimal"}

TensorNetworkFindContractionPath[net_, opts : OptionsPattern[]] := (
    Message[General::deprec, "TensorNetworkFindContractionPath", "GreedyContractionPath or OptimalContractionPath"];
    If[TrueQ[OptionValue["ReturnParameters"]],
        extractContractionParameters[net],
        Replace[Replace[OptionValue[Method], "Optimal" -> "size"], {
            method : "flops" | "max" | "size" | "write" | "combo" | "limit" :>
                OptimalContractionPath[net, Method -> method],
            _ :> GreedyContractionPath[net]
        }]
    ]
)

einsumArrayDot[{i_, j_} -> out_, a_, b_, inactiveQ : _ ? BooleanQ : False] := Block[{
	c = DeleteElements[DeleteDuplicates @ Join[i, j], Replace[out, Automatic :> SymmetricDifference[i, j]]],
	k, perm,
	al, br, x, y,
	aIndex = First /@ PositionIndex[i], bIndex = First /@ PositionIndex[j],
	inactive = If[inactiveQ, Function[f, Inactive[f][##] &], Identity]
},
	al = DeleteElements[i, c];
	br = DeleteElements[j, c];
	k = Length[c];
	If[ k == 0
		,
		x = inactive[TensorProduct][a, b]
		,
		x = inactive[ArrayDot][a, b, Thread[{Lookup[aIndex, c], Lookup[bIndex, c]}]];
	];
	If[ out === Automatic,
		{x, Join[al, br]}
		,
		perm = FindPermutation[Join[al, br], out];
		If[perm === Cycles[{}], x, inactive[Transpose][x, perm]]
	]
]

einsumArrayDotTranspose[{i_, j_} -> out_, a_, b_, inactiveQ : _ ? BooleanQ : False] := Block[{
	c = DeleteElements[DeleteDuplicates @ Join[i, j], Replace[out, Automatic :> SymmetricDifference[i, j]]],
	k, perm,
	al, br, x, y,
	inactive = If[inactiveQ, Function[f, Inactive[f][##] &], Identity]
},
	al = DeleteElements[i, c];
	br = DeleteElements[j, c];
	k = Length[c];
	If[ k == 0
		,
		x = inactive[TensorProduct][a, b]
		,
		perm = FindPermutation[i, Join[al, c]];
		x = If[perm === Cycles[{}], a, inactive[Transpose][a, perm]];
		perm = FindPermutation[j, Join[c, br]];
		y = If[perm === Cycles[{}], b, inactive[Transpose][b, perm]];
		x = inactive[ArrayDot][x, y, k];
	];
	If[ out === Automatic,
		{x, Join[al, br]}
		,
		perm = FindPermutation[Join[al, br], out];
		If[perm === Cycles[{}], x, inactive[Transpose][x, perm]]
	]
]

einsumTensorContract[{i_, j_} -> out_, a_, b_, inactiveQ : _ ? BooleanQ : False] := Block[{
	c = DeleteElements[DeleteDuplicates @ Join[i, j], Replace[out, Automatic :> SymmetricDifference[i, j]]],
	k, perm,
	al, br, x,
	aIndex = First /@ PositionIndex[i], bIndex = First /@ PositionIndex[j],
	inactive = If[inactiveQ, Function[f, Inactive[f][##] &], Identity]
},
	al = DeleteElements[i, c];
	br = DeleteElements[j, c];
	k = Length[c];
	If[ k == 0
		,
		x = inactive[TensorProduct][a, b]
		,
		x = inactive[TensorContract][
			inactive[TensorProduct][a, b],
			MapThread[{#1, #2 + Length[i]} &,
				{Lookup[aIndex, c], Lookup[bIndex, c]}
			]
		]
	];
	If[ out === Automatic,
		{x, Join[al, br]}
		,
		perm = FindPermutation[Join[al, br], out];
		If[perm === Cycles[{}], x, inactive[Transpose][x, perm]]
	]
]

einsumDot[{i_, j_} -> out_, a_, b_, inactiveQ : _ ? BooleanQ : False] := Block[{
	c = DeleteElements[DeleteDuplicates @ Join[i, j], Replace[out, Automatic :> SymmetricDifference[i, j]]],
	k, perm,
	al, br, x, y,
	inactive = If[inactiveQ, Function[f, Inactive[f][##] &], Identity],
	aIndex = PositionIndex[i], bIndex = PositionIndex[j],
	aDim = symbolicTensorDimensions[a], bDim = symbolicTensorDimensions[b],
	reshape
},
	reshape[t_, newShape_] := If[symbolicTensorDimensions[t] === newShape, t, inactive[ArrayReshape][t, newShape]];
	al = DeleteElements[i, c];
	br = DeleteElements[j, c];
	k = Length[c];
	If[ k == 0,
		x = inactive[TensorProduct][a, b]
		,
		perm = FindPermutation[i, Join[al, c]];
		x = If[perm === Cycles[{}], a, inactive[Transpose][a, perm]];
		perm = FindPermutation[j, Join[c, br]];
		y = If[perm === Cycles[{}], b, inactive[Transpose][b, perm]];
		If[ k == 1,
			x = inactive[Dot][x, y]
			,
			x = inactive[Dot][
				reshape[x, Catenate[MapAt[{Times @@ #} &, {2}] @ (Extract[aDim, Lookup[aIndex, #]] & /@ {al, c})]],
				reshape[y, Catenate[MapAt[{Times @@ #} &, {1}] @ (Extract[bDim, Lookup[bIndex, #]] & /@ {c, br})]]
			];
			x = reshape[x, Join[Extract[aDim, Lookup[aIndex, al]], Extract[bDim, Lookup[bIndex, br]]]]
		];
	];
	If[ out === Automatic,
		{x, Join[al, br]}
		,
		perm = FindPermutation[Join[al, br], out];
		If[perm === Cycles[{}], x, inactive[Transpose][x, perm]]
	]
]

einsumTableSum[{i_, j_} -> out_, a_, b_, inactiveQ : _ ? BooleanQ : False] := Block[{
	c = DeleteElements[DeleteDuplicates @ Join[i, j], Replace[out, Automatic :> SymmetricDifference[i, j]]],
	k, perm,
	al, br, x, y,
	inactive = If[inactiveQ, Function[f, Inactive[f][##] &], Identity],
	aIndex = PositionIndex[i], bIndex = PositionIndex[j],
	aDim = symbolicTensorDimensions[a], bDim = symbolicTensorDimensions[b]
},
	
	al = DeleteElements[i, c];
	br = DeleteElements[j, c];
	k = Length[c];
	
	(* a and b are inlined directly into Part[a, ...] / Part[b, ...]; the previous
	   inactive[With][{inactive[Set][...], ...}, body] wrapping broke when inactive=Identity
	   because Set fired immediately inside With's held binding list and produced With::lvws *)
	If[ k == 0
		,
		x = With[{
			p1 = Symbol["\[FormalI]" <> ToString[#]] & /@ Range[Length[al]],
			p2 = Symbol["\[FormalJ]" <> ToString[#]] & /@ Range[Length[br]]
		},
			inactive[Table][(inactive[Part][a, ##] & @@ p1) * (inactive[Part][b, ##] & @@ p2), ##] & @@ Join[
				MapIndexed[{Symbol["\[FormalI]" <> ToString[#2[[1]]]], #1} &, aDim],
				MapIndexed[{Symbol["\[FormalJ]" <> ToString[#2[[1]]]], #1} &, bDim]
			]
		]
		,
		x = With[{
			p1 = ReplacePart[i, Join[
				Thread[Lookup[aIndex, al] -> (Symbol["\[FormalI]" <> ToString[#]] & /@ Range[Length[al]])],
				Thread[Lookup[aIndex, c] -> (Symbol["\[FormalC]" <> ToString[#]] & /@ Range[Length[c]])]
			]],
			p2 = ReplacePart[j, Join[
				Thread[Lookup[bIndex, br] -> (Symbol["\[FormalJ]" <> ToString[#]] & /@ Range[Length[br]])],
				Thread[Lookup[bIndex, c] -> (Symbol["\[FormalC]" <> ToString[#]] & /@ Range[Length[c]])]
			]],
			cs = MapIndexed[{Symbol["\[FormalC]" <> ToString[#2[[1]]]], #1} &, Extract[aDim, Lookup[aIndex, c]]]
		},
			inactive[Table][
				inactive[Sum][(inactive[Part][a, ##] & @@ p1) * (inactive[Part][b, ##] & @@ p2), ##] & @@ cs,
				##
			] & @@ Join[
				MapIndexed[{Symbol["\[FormalI]" <> ToString[#2[[1]]]], #1} &, Extract[aDim, Lookup[aIndex, al]]],
				MapIndexed[{Symbol["\[FormalJ]" <> ToString[#2[[1]]]], #1} &, Extract[bDim, Lookup[bIndex, br]]]
			]
		]
	];
	If[ out === Automatic,
		{x, Join[al, br]}
		,
		perm = FindPermutation[Join[al, br], out];
		If[perm === Cycles[{}], x, inactive[Transpose][x, perm]]
	]
]


(* ---------------------------------------------------------------------------
   NetGraph container: leaves lift to layers, each pair to transpose/reshape/dot/reshape.
   Not in $TensorNetworkContractionMethods: a net is not an activatable array.
--------------------------------------------------------------------------- *)

$netGraphContractionMethod = "NetGraph"

TensorNetworkContraction::netleaf = "The tensor `1` cannot be lifted into a net layer: `2`."

TensorNetworkContraction::netpair = "A contraction step with result dimensions `1` cannot be lifted into net layers: `2`."

TensorNetworkContraction::netopen = "The contracted net has open input ports `1`, so it has no explicit array value; use TensorNetworkContraction to obtain the net itself."

TensorNetworkContraction::netpath = "No contraction path is available for the \"NetGraph\" method."

netGraphMethodQ[method_] := method === $netGraphContractionMethod

netGraphQ[x_] := MatchQ[x, _NetGraph]

(* Net failures unwind through a private Throw tag: Enclose misses Confirm inside called handlers *)
netFail[] := Throw[$Failed, netFailTag]

(* NetExtract: an integer for a rank-1 port, a type name for rank 0 *)
netTensorDimensions[net_] := Replace[NetExtract[net, "Output"], {d_Integer :> {d}, d : {___Integer} :> d, _ :> {}}]

netPermutationList[perm_Cycles, n_Integer] := PermutationList[perm, n]

netPermutationList[perm_List, n_Integer] := PermutationList[PermutationCycles[perm], n]

(* pass the length: PermutationList otherwise drops trailing fixed points *)
netIdentityPermutationQ[perm_List] := perm === Range[Length[perm]]

netLeafTensor[tensor_] := Block[{t, body, symbols, layer, reason, g},
	t = Chop @ FullSimplify @ N @ Normal @ tensor;
	reason = Which[
		tensorRank[t] == 0, "a rank-0 tensor has no net layer representation",
		! FreeQ[t, _Complex], "complex values are not supported by net array layers",
		True, None
	];
	If[ reason =!= None,
		Message[TensorNetworkContraction::netleaf, tensor, reason];
		netFail[]
	];
	symbols = Union @@ Reap[body = Replace[t, s_Symbol /; ! NumericQ[s] :> Slot @@ {Sow[ToString[s]]}, Infinity]][[2]];
	layer = If[ symbols === {},
		silentConstruct @ NetArrayLayer["Array" -> NumericArray[t]],
		silentConstruct @ FunctionLayer[Function[Evaluate[body]], Sequence @@ (# -> {} & /@ symbols)]
	];
	If[ layer === $Failed,
		Message[TensorNetworkContraction::netleaf, tensor,
			If[ symbols === {},
				"no net array layer accepts these values",
				"the tensor cannot be compiled into a FunctionLayer"
			]
		];
		netFail[]
	];
	g = silentConstruct @ NetGraph[<|"tensor" -> layer|>, {"tensor" -> NetPort["Output"]}];
	If[ ! netGraphQ[g],
		Message[TensorNetworkContraction::netleaf, tensor, "the lifted layer does not form a net"];
		netFail[]
	];
	g
]

toNetTensor[net_NetGraph] := net

toNetTensor[tensor_] := netLeafTensor[tensor]

netTranspose[net_NetGraph, perm_] := Block[{list, g},
	list = netPermutationList[perm, Length[netTensorDimensions[net]]];
	g = silentConstruct @ NetAppend[net, TransposeLayer[list]];
	If[ ! netGraphQ[g],
		Message[TensorNetworkContraction::netpair, list, "the permutation is not compatible with the net output"];
		netFail[],
		g
	]
]

netContractionGraph[neta_, netb_, perma_, permb_, reshapea_, reshapeb_, reshape_] := Block[{
	prea = NetChain[{If[netIdentityPermutationQ[perma], Nothing, TransposeLayer[perma]], ReshapeLayer[reshapea]}],
	preb = NetChain[{If[netIdentityPermutationQ[permb], Nothing, TransposeLayer[permb]], ReshapeLayer[reshapeb]}],
	g
},
	g = silentConstruct @ If[ reshape === {},
		NetGraph[
			<|"tensor1" -> neta, "tensor2" -> netb, "a" -> prea, "b" -> preb, "dot" -> DotLayer[]|>,
			{"tensor1" -> "a", "tensor2" -> "b", {"a", "b"} -> "dot" -> NetPort["Output"]}
		],
		NetGraph[
			<|"tensor1" -> neta, "tensor2" -> netb, "a" -> prea, "b" -> preb, "dot" -> DotLayer[], "post" -> ReshapeLayer[reshape]|>,
			{"tensor1" -> "a", "tensor2" -> "b", {"a", "b"} -> "dot" -> "post" -> NetPort["Output"]}
		]
	];
	If[ ! netGraphQ[g],
		Message[TensorNetworkContraction::netpair, reshape, "the transpose, reshape and dot layers are not compatible with the operand shapes"];
		netFail[],
		g
	]
]

netEvaluate[net_NetGraph] := Block[{ports = Information[net, "InputPorts"]},
	If[ Length[ports] > 0,
		Message[TensorNetworkContraction::netopen, Keys[ports]];
		netFail[],
		net[]
	]
]

(* inactiveQ unused: the net is already the lazy form *)
einsumNetGraph[{i_, j_} -> out_, a_, b_, inactiveQ : _ ? BooleanQ : False] := Block[{
	c = DeleteElements[DeleteDuplicates @ Join[i, j], Replace[out, Automatic :> SymmetricDifference[i, j]]],
	al, br, x, perm,
	neta, netb, adim, bdim, ac, bc, ai, bj, ad, bd, reshape, reshapea, reshapeb, perma, permb
},
	al = DeleteElements[i, c];
	br = DeleteElements[j, c];
	neta = toNetTensor[a];
	netb = toNetTensor[b];
	adim = netTensorDimensions[neta];
	bdim = netTensorDimensions[netb];
	ac = Catenate @ Lookup[PositionIndex[i], c, {}];
	bc = Catenate @ Lookup[PositionIndex[j], c, {}];
	ai = Complement[Range[Length[i]], ac];
	bj = Complement[Range[Length[j]], bc];
	ad = Times @@ adim[[ac]];
	bd = Times @@ bdim[[bc]];
	reshape = Join[adim[[ai]], bdim[[bj]]];
	(* fully contracted pair: vectors, so DotLayer gives the scalar (there is no ReshapeLayer[{}]) *)
	{reshapea, reshapeb} = If[ reshape === {},
		{{ad}, {bd}},
		{{Times @@ adim / ad, ad}, {bd, Times @@ bdim / bd}}
	];
	perma = netPermutationList[FindPermutation[Join[ai, ac]], Length[i]];
	permb = netPermutationList[FindPermutation[Join[bc, bj]], Length[j]];
	x = netContractionGraph[neta, netb, perma, permb, reshapea, reshapeb, reshape];
	If[ out === Automatic,
		{x, Join[al, br]}
		,
		perm = netPermutationList[FindPermutation[Join[al, br], out], Length[out]];
		If[netIdentityPermutationQ[perm], x, netTranspose[x, perm]]
	]
]


(* ---------------------------------------------------------------------------
   Leaf array containers: {method, "LeafContainer" -> type} converts every leaf
   through the Wolfram/Arrays route of Utilities.wl.
--------------------------------------------------------------------------- *)

TensorNetworkContraction::leafname = "`1` is not a known array container type name."

TensorNetworkContraction::leafcont = "The tensor `1` cannot be converted to the array container type `2`: `3`."

contractionMethodName[spec_] := Replace[spec, {{name_, ___} :> name, name_ :> name}]

contractionMethodOptions[spec_] := Replace[spec, {{_, subopts___} :> Flatten[{subopts}], _ :> {}}]

(* Allowlist, not NameQ/Symbol: a mistyped name ("Quit") would run a System function on the data *)

$leafContainerNames = {
	"List", "SparseArray", "NumericArray", "SymmetrizedArray", "StructuredArray",
	"QuantityArray", "TabularColumn", "Tabular", "Dataset", "ByteArray", "EventSeries"
}

leafContainerHead[container_String] := If[
	MemberQ[$leafContainerNames, container] && NameQ["System`" <> container],
	Symbol["System`" <> container],
	None
]

toArrayContainer[Automatic, tensor_] := tensor

toArrayContainer[container_String, tensor_] := Block[{head, data, res},
	head = leafContainerHead[container];
	If[ head === None,
		Message[TensorNetworkContraction::leafname, container];
		Return[$Failed]
	];
	If[ ! arrayContainerQ[tensor],
		Message[TensorNetworkContraction::leafcont, tensor, container, "the tensor is not a recognized array container"];
		Return[$Failed]
	];
	data = arrayContainerMaterialize[tensor];
	res = If[head === List, data, silentConstruct[head[data]]];
	Which[
		res === $Failed,
			Message[TensorNetworkContraction::leafcont, tensor, container, "the container constructor rejected the tensor"];
			$Failed,
		! arrayContainerQ[res],
			Message[TensorNetworkContraction::leafcont, tensor, container, "the result is not a recognized array container"];
			$Failed,
		Head[res] =!= head,
			Message[TensorNetworkContraction::leafcont, tensor, container, "the constructor gives no container of that type"];
			$Failed,
		arrayContainerDimensions[res] =!= arrayContainerDimensions[tensor],
			Message[TensorNetworkContraction::leafcont, tensor, container, "the conversion does not preserve the dimensions"];
			$Failed,
		True,
			res
	]
]

toArrayContainer[container_, tensor_] := (Message[TensorNetworkContraction::leafname, container]; $Failed)

convertLeafTensors[spec_, tensors_] := With[{
	container = Lookup[contractionMethodOptions[spec], "LeafContainer", Automatic]
},
	If[ container === Automatic,
		tensors,
		(* stop at the first failing leaf: one message per contraction *)
		Catch[
			Map[Replace[toArrayContainer[container, #], $Failed :> Throw[$Failed, leafFailTag]] &, tensors],
			leafFailTag
		]
	]
]

(* Evaluated: storage-only containers (NumericArray, ...) are materialized, compute-native ones kept *)

computableLeafTensors[tensors_] := Replace[
	tensors,
	t_ /; ! arrayComputeNativeQ[t] :> arrayContainerMaterialize[t],
	{1}
]

leafContainerAutomaticQ[spec_] := Lookup[contractionMethodOptions[spec], "LeafContainer", Automatic] === Automatic

(* Fill policy: machine-number SparseArrays at least $denseFill full go dense and packed
   (measured crossover about a fifth). Exact arrays stay sparse: they can't pack. *)

$denseFill = 0.2

computeRepresentation[t_SparseArray] /; t["Density"] >= $denseFill && Precision[t] === MachinePrecision := packedIfMachine[Normal[N[t]]]

computeRepresentation[t_List] /; ! Developer`PackedArrayQ[t] := packedIfMachine[t]

computeRepresentation[t_] := t

(* Pack machine arrays, mixed Real/Complex as Complex; never make an exact entry inexact.
   Plain packing first: it settles uniform arrays without a scan. *)
packedIfMachine[t_] := With[{packed = Developer`ToPackedArray[t]},
    If[ Developer`PackedArrayQ[packed] || ! ArrayQ[t, _, MachineNumberQ],
        packed,
        Developer`ToPackedArray[t, Complex]
    ]
]

(* One machine number makes every term machine: numericize exact numeric leaves once.
   Leaves with symbols stay exact (N breaks cancellations such as E^(I theta)). *)
machinePrecisionLeaves[tensors_] := If[
    Min[Precision /@ tensors] === MachinePrecision,
    Replace[tensors, t_ ? numericLeafQ :> N[t], {1}],
    tensors
]

numericLeafQ[t_] := NumericQ[t] || ArrayQ[t, _, NumericQ]

(* Exact leaf whose values are rational multiples of one value c: contract its integers, multiply
   c back in (linear in each leaf). Avoids rational normalization and radicals; exact on overflow. *)
integerScaledLeaves[tensors_List] := With[{scaled = integerScaledLeaf /@ tensors},
    {Times @@ scaled[[All, 1]], scaled[[All, 2]]}
]

integerScaledLeaf[t_SparseArray] /; t["Background"] === 0 && Precision[t] === Infinity := Replace[
    ratioScale[t["NonzeroValues"]],
    {
        {c_, q_} :> {c, SparseArray[t["NonzeroPositions"] -> q, Dimensions[t]]},
        None -> {1, t}
    }
]

integerScaledLeaf[t_List] /; Precision[t] === Infinity && ArrayQ[t, _, NumericQ] := Replace[
    ratioScale[Flatten[t]],
    {
        {c_, q_} :> {c, ArrayReshape[q, Dimensions[t]]},
        None -> {1, t}
    }
]

integerScaledLeaf[t_] := {1, t}

(* {c, q} with values == c q, q integers; None if not worth it *)
ratioScale[values_List] := With[{first = SelectFirst[values, # =!= 0 &, None]},
    If[ first === None || VectorQ[values, IntegerQ] || ! VectorQ[Take[values, UpTo[16]] / first, rationalQ],
        None,
        With[{ratios = values / first},
            If[ VectorQ[ratios, rationalQ],
                With[{l = LCM @@ Union[Denominator[ratios]]}, {first / l, l ratios}],
                None
            ]
        ]
    ]
]

rationalQ[x_] := MatchQ[x, _Integer | _Rational]


(* ---------------------------------------------------------------------------
   Executing a tree path. A shared label is summed once nothing else needs it, else kept
   as a batch index (hyperedges, shared outputs): no delta spiders. A leaf first settles
   its own labels: repeated -> diagonal, held by nothing else -> summed.
--------------------------------------------------------------------------- *)

TensorNetworkContraction::netbatch = "The \"NetGraph\" method cannot contract the indices `1`, which both operands carry and the rest of the network still needs; contract BinaryTensorNetwork of the network instead."

(* Node = {tensor, labels, holders}; a label stays while other holders or the output need it.
   Steps run in post-order (treeSteps), no recursion; intermediates in an association,
   dropped once consumed. *)

contractTreePath[treePath_, leaves_Association, output_List, settings_Association] := Module[{
    env = Join[settings, <|
        "Holders" -> Counts[Catenate[DeleteDuplicates /@ Values[leaves][[All, 2]]]],
        "Output" -> AssociationThread[output, True],
        "Dimension" -> labelDimensions[Values[leaves]]
    |>],
    steps = treeSteps[treePath, AssociationThread[List /@ Keys[leaves], Range[Length[leaves]]]],
    values = AssociationThread[Range[Length[leaves]], Values[leaves]],
    next = Length[leaves]
},
    Which[
        steps === $Failed,
            netFail[],
        steps === {},
            Most @ settleLeaf[leaves[First[treePath]], env],
        True,
            Scan[
                Function[operands,
                    next++;
                    values[next] = Fold[
                        contractStep[#1, #2, env] &,
                        If[# <= Length[leaves], settleLeaf[values[#], env], values[#]] & /@ operands
                    ];
                    KeyDropFrom[values, operands]
                ],
                steps
            ];
            Most @ values[next]
    ]
]

(* index dimensions, read once off the leaves *)
labelDimensions[leaves_List] := Association @ Catenate @ Map[
    With[{dims = tensorDimensions[First[#]]},
        If[Length[dims] == Length[Last[#]], Thread[Last[#] -> dims], {}]
    ] &,
    leaves
]

keptLabelQ[label_, holders_, env_] := holders[label] < env["Holders"][label] || Lookup[env["Output"], label, False]

contractStep[{a_, i_, ha_}, {b_, j_, hb_}, env_] := Block[{
    holders = Merge[{ha, hb}, Total], batch, result
},
    batch = Select[i, MemberQ[j, #] && keptLabelQ[#, holders, env] &];
    result = Which[
        batch =!= {},
            contractBatchPair[{a -> i, b -> j}, batch, env],
        (* rank-0 operand: Times keeps the shape; TensorProduct[{-2, -1}, 0] is 0 *)
        ! netGraphMethodQ[env["Method"]] && (i === {} || j === {}),
            {If[env["Inactive"], Inactive[Times][a, b], a b], Join[i, j]},
        True,
            contractTensorPair[{a -> i, b -> j}, env["PairOptions"]]
    ];
    {env["Represent"][First[result]], Last[result], KeyTake[holders, Last[result]]}
]

orderAxes[t_, from_, to_] := With[{perm = FindPermutation[from, to]},
    If[perm === Cycles[{}], t, Transpose[t, perm]]
]


(* --- a leaf's own labels --- *)

settleLeaf[{t_, labels_List}, env_] := With[{
    distinct = DeleteDuplicates[labels]
}, {
    summed = Select[distinct, env["Holders"][#] == 1 && ! Lookup[env["Output"], #, False] &]
},
    If[ Length[distinct] == Length[labels] && summed === {},
        {t, labels, AssociationThread[labels, 1]},
        With[{settled = If[env["InactiveLeaves"], settleLeafInactive, settleLeafEager][t, labels, summed, env]},
            {First[settled], Last[settled], AssociationThread[Last[settled], 1]}
        ]
    ]
]

(* repeated Transpose levels take a diagonal; Total sums levels out *)
settleLeafEager[t_, labels_, summed_, _] := With[{
    distinct = DeleteDuplicates[labels]
}, {
    diagonal = If[ Length[distinct] < Length[labels],
        diagonalOf[t, Lookup[First /@ PositionIndex[distinct], labels]],
        t
    ],
    kept = Select[distinct, ! MemberQ[summed, #] &]
},
    If[ summed === {},
        {diagonal, distinct},
        {Total[orderAxes[diagonal, distinct, Join[kept, summed]], {Length[kept] + 1, Length[distinct]}], kept}
    ]
]

(* SparseArray diagonal from stored entries: Transpose with repeated levels can crash the kernel,
   e.g. Transpose[SparseArray[{{1, 2} -> 3.}, {2, 2}], {1, 1}] *)
diagonalOf[t_SparseArray, levels_] := With[{groups = Values[PositionIndex[levels]]},
    SparseArray[
        Map[
            First[#][[First /@ groups]] -> Last[#] &,
            Select[Most[ArrayRules[t]], Function[rule, AllTrue[groups, Equal @@ First[rule][[#]] &]]]
        ],
        Dimensions[t][[First /@ groups]],
        t["Background"]
    ]
]

diagonalOf[t_, levels_] := Transpose[t, levels]

(* inert form: a settled label contracts with a delta (one leg more if kept) or a ones vector *)
settleLeafInactive[t_, labels_, summed_, env_] := Block[{
    rank = Length[labels], extras = {}, pairs = {}, open = {}, settledLabels = {}, base
},
    base = rank;
    KeyValueMap[
        Function[{label, slots}, With[{
            kept = ! MemberQ[summed, label],
            d = env["Dimension"][label],
            m = Length[slots]
        },
            Which[
                m == 1 && kept,
                    Null,
                m == 1,
                    AppendTo[extras, ConstantArray[1, d]];
                    AppendTo[pairs, {First[slots], base + 1}];
                    base += 1,
                (* a plain trace needs no delta *)
                m == 2 && ! kept,
                    AppendTo[pairs, slots],
                True,
                    AppendTo[extras, SymbolicDeltaProductArray[ConstantArray[d, m + Boole[kept]], {Range[m + Boole[kept]]}]];
                    pairs = Join[pairs, Transpose[{slots, base + Range[m]}]];
                    If[kept, AppendTo[settledLabels, label]];
                    base += m + Boole[kept]
            ]
        ]],
        PositionIndex[labels]
    ];
    open = Select[labels, Count[labels, #] == 1 && ! MemberQ[summed, #] &];
    {
        Inactive[TensorContract][If[extras === {}, t, Inactive[TensorProduct][t, Sequence @@ extras]], pairs],
        Join[open, settledLabels]
    }
]


(* --- a step with batch indices --- *)

contractBatchPair[{a_ -> i_, b_ -> j_}, batch_, env_] := Which[
    netGraphMethodQ[env["Method"]],
        Message[TensorNetworkContraction::netbatch, batch];
        netFail[],
    env["Inactive"],
        batchPairInactive[a, i, b, j, batch, env],
    True,
        batchPairEager[a, i, b, j, batch, env]
]

(* operands as [batch, own, summed] blocks: one matrix product per batch entry, batch axes first *)
batchPairEager[a_, i_, b_, j_, batch_, env_] := Block[{
    summed = Select[i, MemberQ[j, #] && ! MemberQ[batch, #] &],
    own = Select[i, ! MemberQ[j, #] &],
    other = Select[j, ! MemberQ[i, #] &],
    nb, na, ns, nf, x, y, product
},
    {nb, na, ns, nf} = Times @@ Lookup[env["Dimension"], #] & /@ {batch, own, summed, other};
    x = orderAxes[a, i, Join[batch, own, summed]];
    y = orderAxes[b, j, Join[batch, summed, other]];
    product = Which[
        SparseArrayQ[x] || SparseArrayQ[y],
            SparseArray[MapThread[Dot, {ArrayReshape[x, {nb, na, ns}], ArrayReshape[y, {nb, ns, nf}]}]],
        (* nothing summed: an outer product per batch entry; ArrayReshape, not Part, drops the axis *)
        ns == 1,
            batchOuter[ArrayReshape[x, {nb, na}], ArrayReshape[y, {nb, nf}], na, nf],
        True,
            Developer`ToPackedArray[MapThread[Dot, {ArrayReshape[x, {nb, na, ns}], ArrayReshape[y, {nb, ns, nf}]}]]
    ];
    {
        ArrayReshape[product, Lookup[env["Dimension"], Join[batch, own, other]]],
        Join[batch, own, other]
    }
]

(* Row-wise outer products of x {nb, na} and y {nb, nf} by broadcast Times;
   many short rows: expand both to the full shape first. *)
batchOuter[x_, y_, na_, nf_] /; na nf <= 16 && Length[x] >= 4096 := Which[
    na == 1 && nf == 1, Flatten[x] * Flatten[y],
    na == 1, Transpose[ConstantArray[Flatten[x], nf]] * y,
    nf == 1, x * Transpose[ConstantArray[Flatten[y], na]],
    True, Transpose[ConstantArray[x, nf], {3, 1, 2}] * Transpose[ConstantArray[y, na], {2, 1, 3}]
]

(* a side with no own labels just scales the other's rows *)
batchOuter[x_, y_, 1, _] := Flatten[x] * y

batchOuter[x_, y_, _, 1] := x * Flatten[y]

batchOuter[x_, y_, na_, _] := x * Transpose[ConstantArray[y, na], {2, 1, 3}]

(* inert form: a rank-3 delta per batch index, its open leg the result's batch axis *)
batchPairInactive[a_, i_, b_, j_, batch_, env_] := Block[{
    ra = Length[i], rb = Length[j],
    summed = Select[i, MemberQ[j, #] && ! MemberQ[batch, #] &],
    aSlot = First /@ PositionIndex[i],
    bSlot = First /@ PositionIndex[j]
},
    {
        Inactive[TensorContract][
            Inactive[TensorProduct][
                a, b,
                Sequence @@ (SymbolicDeltaProductArray[ConstantArray[env["Dimension"][#], 3], {{1, 2, 3}}] & /@ batch)
            ],
            Join[
                Catenate @ MapIndexed[
                    {{aSlot[#1], ra + rb + 3 First[#2] - 2}, {ra + bSlot[#1], ra + rb + 3 First[#2] - 1}} &,
                    batch
                ],
                {aSlot[#], ra + bSlot[#]} & /@ summed
            ]
        ],
        Join[Select[i, ! MemberQ[j, #] &], Select[j, ! MemberQ[i, #] &], batch]
    }
]


(* interchangeable array engines only; "NetGraph" returns a net, so it isn't listed *)

$TensorNetworkContractionMethods = {"ArrayDotTranspose", "ArrayDot", "Dot", "TensorContract", "TableSum"}

Options[contractTensorPair] = {Method -> "ArrayDot", "Inactive" -> True}

contractTensorPair[{tensor1_ -> indices1_, tensor2_ -> indices2_}, OptionsPattern[]] :=
	Switch[
		contractionMethodName[OptionValue[Method]],
		"ArrayDotTranspose", einsumArrayDotTranspose,
		"ArrayDot", einsumArrayDot,
		"Dot", einsumDot,
		"TensorContract", einsumTensorContract,
		"TableSum", einsumTableSum,
		"NetGraph", einsumNetGraph
	][{indices1, indices2} -> Automatic, tensor1, tensor2, TrueQ[OptionValue["Inactive"]]]


Options[TensorNetworkContraction] = Join[Options[contractTensorPair], {"TransposeFunction" -> Transpose}]

TensorNetworkContraction[net_Graph ? TensorNetworkGraphQ, args___] :=
    TensorNetworkContraction[TensorNetworkGraphData[net], args]

(* Network a path runs on: its own tensors, or the binarized one for a path over that
   many operands and for "NetGraph" (no batch layer). *)
contractionNetwork[net_, args_List] := Which[
    netGraphMethodQ[contractionMethodName[Lookup[Cases[args, _Rule | _RuleDelayed], Method, None]]],
        BinaryTensorNetwork[net],
    binarizedFramePathQ[net, First[args, None]],
        BinaryTensorNetwork[net],
    True,
        net
]

binarizedFramePathQ[net_, path_] := With[{count = pathOperandCount[path]},
    IntegerQ[count] && count =!= Length[net["Tensors"]] && count === Length[BinaryTensorNetwork[net]["Tensors"]]
]

pathOperandCount[path_ ? CanonicalPathQ] := Length[path] + 1

pathOperandCount[path_ ? TreePathQ] := Length[Cases[path, {Except[_List]}, {0, Infinity}]]

pathOperandCount[_] := None

TensorNetworkContraction[net_TensorNetwork ? TensorNetworkQ, args__] :=
    TensorNetworkContraction[TensorNetworkData[contractionNetwork[net, {args}]], args]
    
(* The args__ clause above takes every call with an explicit path or method,
   so this clause only ever fires for a bare net. *)
TensorNetworkContraction[net_TensorNetwork ? TensorNetworkQ] :=
    TensorNetworkContraction[TensorNetworkData[net]]

TensorNetworkContraction[data : KeyValuePattern["Vertices" -> vertices_], path_ ? CanonicalPathQ, opts : OptionsPattern[]] := 
    TensorNetworkContraction[data, PathToTreePath[path, vertices], opts]
    
TensorNetworkContraction[net_, "Greedy", opts : OptionsPattern[]] :=
    TensorNetworkContraction[net, GreedyContractionPath[net], opts]

TensorNetworkContraction[net_, method : "Optimal" | "flops" | "max" | "size" | "write" | "combo" | "limit", opts : OptionsPattern[]] :=
    TensorNetworkContraction[net, OptimalContractionPath[net, Method -> Replace[method, "Optimal" -> "size"]], opts]

TensorNetworkContraction[
    KeyValuePattern[{
		"Vertices" -> vertices_,
		"Tensors" -> tensors_,
		"ContractionIndices" -> contractions_,
        "FreeIndices" -> freeIndices_
	}],
    treePath_ ? TreePathQ,
    opts : OptionsPattern[]
] := Catch[Block[{
    method = contractionMethodName[OptionValue[Method]],
    contractOpts = FilterRules[{opts}, Options[contractTensorPair]],
    transposeFunction = OptionValue["TransposeFunction"],
    inactiveQ = TrueQ[OptionValue["Inactive"]],
    leafTensors, represent, scale = 1, tensorPath, perm, net
},
    leafTensors = convertLeafTensors[OptionValue[Method], tensors];
    If[! ListQ[leafTensors], netFail[]];
    If[! inactiveQ, leafTensors = computableLeafTensors[leafTensors]];
    represent = If[
        ! inactiveQ && ! netGraphMethodQ[method] && leafContainerAutomaticQ[OptionValue[Method]],
        computeRepresentation,
        Identity
    ];
    If[ represent =!= Identity,
        leafTensors = machinePrecisionLeaves[leafTensors];
        {scale, leafTensors} = integerScaledLeaves[leafTensors]
    ];
    tensorPath = contractTreePath[
        treePath,
        AssociationThread[vertices, MapThread[List, {represent /@ leafTensors, contractions}]],
        freeIndices,
        <|
            "PairOptions" -> contractOpts,
            "Method" -> method,
            "Inactive" -> inactiveQ,
            "InactiveLeaves" -> inactiveQ && ! netGraphMethodQ[method],
            "Represent" -> represent
        |>
    ];
    If[scale =!= 1, tensorPath[[1]] = scale tensorPath[[1]]];
    perm = FindPermutation[tensorPath[[2]], freeIndices];
    If[ netGraphMethodQ[method]
        ,
        (* net: trailing transpose as a TransposeLayer, always eager; a lone leaf is lifted here *)
        net = toNetTensor[tensorPath[[1]]];
        If[ perm =!= Cycles[{}],
            net = Replace[transposeFunction, Transpose -> netTranspose][net, perm]
        ];
        If[ ! netGraphQ[net],
            Message[TensorNetworkContraction::netpair, perm, "the \"TransposeFunction\" gives no net"];
            netFail[]
        ];
        If[TrueQ[OptionValue["Inactive"]], net, netEvaluate[net]]
        ,
        (* With, not Block: Inactive holds its argument, so the head must be substituted *)
        If[ perm === Cycles[{}],
            tensorPath[[1]],
            With[{transposeHead = transposeFunction},
                If[TrueQ[OptionValue["Inactive"]], Inactive, Identity][transposeHead][
                    tensorPath[[1]],
                    perm
                ]
            ]
        ]
    ]
], netFailTag]

TensorNetworkContraction[
    data : KeyValuePattern[{
		"Tensors" -> tensors_,
		"ContractionIndices" -> indices_,
        "FreeIndices" -> freeIndices_
	}],
	(* Except[_Rule]: an option in second position is not a path *)
	path : Except[_Rule | _RuleDelayed] : Automatic,
	opts : OptionsPattern[]
] := Which[
	netGraphMethodQ[contractionMethodName[OptionValue[Method]]],
		(* a net needs a path: use the optimal one *)
		With[{optimalPath = OptimalContractionPath[data]},
			If[ CanonicalPathQ[optimalPath],
				TensorNetworkContraction[data, optimalPath, opts],
				Message[TensorNetworkContraction::netpath]; $Failed
			]
		],
	(* Automatic: evaluated and plannable -> a planned path; otherwise EinsteinSummation,
	   which keeps the compact inert form but has no contraction order. *)
	! TrueQ[OptionValue["Inactive"]] && path === Automatic && greedyPlannableQ[data],
		With[{plan = automaticPlan[data, OptionValue[Method]]},
			If[ MatchQ[plan, {_Association, _ ? TreePathQ}],
				TensorNetworkContraction[First[plan], Last[plan], opts],
				einsteinSummationContraction[tensors, indices, freeIndices, OptionValue[Method], TrueQ[OptionValue["Inactive"]]]
			]
		],
	True,
		einsteinSummationContraction[tensors, indices, freeIndices, OptionValue[Method], TrueQ[OptionValue["Inactive"]]]
]

einsteinSummationContraction[tensors_, indices_, freeIndices_, methodSpec_, inactiveQ_] :=
	With[{leafTensors = convertLeafTensors[methodSpec, tensors]},
		If[ ListQ[leafTensors],
			If[ inactiveQ,
				EinsteinSummation[indices -> freeIndices, leafTensors],
				ActivateTensors @ EinsteinSummation[indices -> freeIndices, computableLeafTensors[leafTensors]]
			],
			$Failed
		]
	]

(* Automatic plan: {network (given or reduced), tree path}; not canonicalized (quadratic).
   Cached by shape, so a network applied to new values replans only when its shape changes;
   a reduced plan is kept as its leg groups and labels, reapplied to the new values. *)
automaticPlan[data_, method_] := With[{key = planKey[data, method]},
	Replace[Lookup[$planCache, Key[key], Missing[]], {
		{"Given", tree_} :> {data, tree},
		{"Reduced", groups_, labels_, tree_} :> {reducedForm[data, groups, labels], tree},
		_ :> With[{plan = freshPlan[data, method]}, If[ListQ[plan], rememberPlan[key, plan]]; plan]
	}]
]

freshPlan[data_, method_] := With[{parameters = extractContractionParameters[data]},
	If[ MatchQ[parameters, {_List, _List, _Association}],
		Replace[cheapestPlan[data, parameters, method], {
			{form_Association, raw_} :> {form, PathToTreePath[raw, form["Vertices"]]},
			_ -> $Failed
		}],
		$Failed
	]
]

$planCache = <||>

rememberPlan[key_, {form_, tree_}] := (
	$planCache[key] = If[KeyExistsQ[form, "Reduction"], {"Reduced", form["Reduction"], form["Hyperedges"], tree}, {"Given", tree}];
	If[Length[$planCache] > 64, $planCache = Rest[$planCache]]
)

reducedForm[data_, groups_, labels_] :=
	Append[tensorNetworkData[applyDiagonalReduction[data["Tensors"], groups], labels, data["FreeIndices"]], "Reduction" -> groups]

(* all a plan depends on: labels, output, method, and per leaf its shape, container, precision
   and nonzero pattern; the patterns as hashes *)
planKey[data_, method_] := {method, data["Hyperedges"], data["FreeIndices"], leafSignature /@ data["Tensors"]}

(* a SparseArray's pattern is its stored CSR structure, canonical, and ~100x faster to hash than its positions *)
leafSignature[t_SparseArray] := {SparseArray, Dimensions[t], Precision[t], numericLeafQ[t], t["Background"], Hash[{t["RowPointers"], t["ColumnIndices"]}]}

leafSignature[t_List] := {List, Dimensions[t], Precision[t], numericLeafQ[t], If[ArrayQ[t, _, NumericQ], Hash[Unitize[t]], None]}

leafSignature[t_] := {Head[t], Quiet[Dimensions[t]], Precision[t], numericLeafQ[t]}

(* Default: greedy over the given network. If that's expensive, also price half-weight greedy,
   the sweep and, on machine numbers, both over the diagonal-reduced network; take the cheapest
   with its largest intermediate within 4x. Price: elements moved (x2 past 2^20) + flops/70. *)
cheapestPlan[data_, parameters : {input_, _, sizes_}, method_] := With[{default = GreedyContractionPath @@ parameters},
	Which[
		! fullPathQ[default, input],
			$Failed,
		Length[input] < 8 || ! AllTrue[Values[sizes], IntegerQ] || ! plannedEngineQ[method],
			{data, default},
		True,
			With[{costInput = pathCostInput[parameters]},
				With[{defaultCost = pathCost[default, costInput]},
					(* plan more only when the contraction dwarfs the planning *)
					If[ First[defaultCost] <= planningThreshold[data["Tensors"]] Length[input],
						{data, default},
						(* Ordering, not MinimalBy (slow first load); ties keep the default *)
						With[{plans = Select[
							Join[
								{{data, default, defaultCost}},
								formPlans[data, parameters, costInput, method, False],
								reducedPlans[data, method]
							],
							Last[Last[#]] <= 4 Last[defaultCost] &
						]},
							Most @ plans[[First @ Ordering[plans[[All, 3, 1]], 1]]]
						]
					]
				]
			]
	]
]

(* {network, path, {price, largest}}: sweep, half-weight on machine numbers, default if asked *)
formPlans[form_, parameters : {input_, _, _}, costInput_, method_, includeDefault_] :=
	{form, #, pathCost[#, costInput]} & /@ Select[
		Join[
			If[includeDefault, {GreedyContractionPath @@ parameters}, {}],
			If[alternativePathQ[form["Tensors"], method], {GreedyContractionPath[Sequence @@ parameters, "MemoryWeight" -> 0.5]}, {}],
			{sweepPath[Length[input]]}
		],
		fullPathQ[#, input] &
	]

(* plans over the diagonal-reduced network; machine numbers only, since exact batch steps
   cost per entry in ways the price doesn't see *)
reducedPlans[data_, method_] := With[{
	reduction = If[
		ListQ[data["Hyperedges"]] && Min[Precision /@ data["Tensors"]] === MachinePrecision && AllTrue[data["Tensors"], numericLeafQ],
		diagonalReductionGroups[data["Tensors"], data["Hyperedges"], data["FreeIndices"]],
		None
	]
},
	If[ reduction === None,
		{},
		With[{form = reducedForm[data, First[reduction], Last[reduction]]},
			With[{parameters = If[AssociationQ[form], extractContractionParameters[form], $Failed]},
				If[ MatchQ[parameters, {_List, _List, _Association}] && AllTrue[Values[Last[parameters]], IntegerQ],
					formPlans[form, parameters, pathCostInput[parameters], method, True],
					{}
				]
			]
		]
	]
]

(* sweep in optimizer format: fold each next tensor into the running product *)
sweepPath[n_Integer] := Prepend[Table[{1, m}, {m, n - 1, 2, -1}], {1, 2}]

fullPathQ[path_, input_] := PathQ[path] && Count[path, {_, _}] + 1 === Length[input]

plannedEngineQ[method_] := contractionMethodName[method] === "ArrayDot" && leafContainerAutomaticQ[method]

planningThreshold[tensors_] := If[Min[Precision /@ tensors] === MachinePrecision, 2.^16, 2.^10]

alternativePathQ[tensors_, method_] :=
	contractionMethodName[method] === "ArrayDot" &&
		leafContainerAutomaticQ[method] &&
		Min[Precision /@ tensors] === MachinePrecision &&
		AllTrue[tensors, numericLeafQ] &&
		AllTrue[tensors, ! MatchQ[#, _SparseArray] || #["Density"] >= $denseFill &]

(* per leaf: label ids minus self-summed ones; label dims, output flags, holder counts *)
pathCostInput[{input_, output_, sizes_}] := Module[{
	ids = AssociationThread[Keys[sizes], Range[Length[sizes]]], leaves, labels, holders, kept, settled
},
	leaves = DeleteDuplicates /@ input;
	labels = Lookup[ids, Catenate[leaves]];
	holders = BinCounts[labels, {1, Length[sizes] + 1, 1}];
	kept = ConstantArray[0, Length[sizes]];
	kept[[Lookup[ids, output]]] = 1;
	settled = Unitize[UnitStep[holders[[labels]] - 2] + kept[[labels]]];
	{Pick[labels, settled, 1], Total /@ TakeList[settled, Length /@ leaves], N[Values[sizes]], kept, holders}
]

pathCost[path_, {labels_, lengths_, dims_, kept_, holders_}] := pathCostCompiled[
	labels, lengths, path[[All, 1]], Replace[path, {{_} -> 0, {_, j_} :> j}, {1}], dims, kept, holders
]

(* {price, largest} of an optimizer-format path; positions via a Fenwick tree,
   labels kept as the executor keeps them *)
pathCostCompiled = Compile[{
	{labels, _Integer, 1}, {lengths, _Integer, 1}, {first, _Integer, 1}, {second, _Integer, 1},
	{dims, _Real, 1}, {output, _Integer, 1}, {holders0, _Integer, 1}
},
	Module[{
		leafCount = Length[lengths], stepCount = Length[first], labelCount = Length[dims], nodes = 0,
		holders = holders0, start, count, size, buffer, used = Length[labels], tree, mark, touched, top = 1,
		touchedCount = 0, a = 0, b = 0, node = 0, keptCount = 0, sa = 0., sb = 0., sk = 1., su = 1.,
		cost = 0., largest = 0., l = 0, c = 0, k = 0, j = 0, pos = 0, bit = 0, cap = 0
	},
		nodes = leafCount + stepCount;
		cap = Length[labels] + 8 stepCount + labelCount;
		buffer = Table[0, {cap}];
		Do[buffer[[m]] = labels[[m]], {m, Length[labels]}];
		start = Table[0, {nodes}];
		count = Table[0, {nodes}];
		size = Table[1., {nodes}];
		k = 1;
		Do[
			start[[n]] = k;
			count[[n]] = lengths[[n]];
			Do[size[[n]] *= dims[[buffer[[m]]]], {m, k, k + lengths[[n]] - 1}];
			k += lengths[[n]],
			{n, leafCount}
		];
		tree = Table[0, {nodes}];
		Do[j = n; While[j <= nodes, tree[[j]] += 1; j += BitAnd[j, -j]], {n, leafCount}];
		While[2 top <= nodes, top *= 2];
		mark = Table[0, {labelCount}];
		touched = Table[0, {labelCount}];
		Do[
			(* both operands are found before either is removed *)
			pos = 0; k = first[[step]]; bit = top;
			While[bit > 0, If[pos + bit <= nodes && tree[[pos + bit]] < k, pos += bit; k -= tree[[pos]]]; bit = Quotient[bit, 2]];
			a = pos + 1;
			If[ second[[step]] > 0,
				pos = 0; k = second[[step]]; bit = top;
				While[bit > 0, If[pos + bit <= nodes && tree[[pos + bit]] < k, pos += bit; k -= tree[[pos]]]; bit = Quotient[bit, 2]];
				b = pos + 1,
				b = 0
			];
			node = leafCount + step;
			j = a; While[j <= nodes, tree[[j]] -= 1; j += BitAnd[j, -j]];
			If[b > 0, j = b; While[j <= nodes, tree[[j]] -= 1; j += BitAnd[j, -j]]];
			j = node; While[j <= nodes, tree[[j]] += 1; j += BitAnd[j, -j]];
			If[ b == 0,
				(* a step of one operand only moves it to the end *)
				start[[node]] = start[[a]]; count[[node]] = count[[a]]; size[[node]] = size[[a]],
				touchedCount = 0;
				Do[l = buffer[[m]]; If[mark[[l]] == 0, touchedCount++; touched[[touchedCount]] = l]; mark[[l]] += 1, {m, start[[a]], start[[a]] + count[[a]] - 1}];
				Do[l = buffer[[m]]; If[mark[[l]] == 0, touchedCount++; touched[[touchedCount]] = l]; mark[[l]] += 1, {m, start[[b]], start[[b]] + count[[b]] - 1}];
				If[used + touchedCount > cap, buffer = Join[buffer, Table[0, {cap + touchedCount}]]; cap = Length[buffer]];
				keptCount = 0; sk = 1.; su = 1.;
				Do[
					l = touched[[m]]; c = mark[[l]]; mark[[l]] = 0;
					su *= dims[[l]];
					If[ holders[[l]] > c || output[[l]] == 1,
						holders[[l]] += 1 - c; keptCount++; buffer[[used + keptCount]] = l; sk *= dims[[l]],
						holders[[l]] -= c
					],
					{m, touchedCount}
				];
				start[[node]] = used + 1; count[[node]] = keptCount; size[[node]] = sk; used += keptCount;
				sa = size[[a]]; sb = size[[b]];
				cost += sa If[sa > 1048576., 2., 1.] + sb If[sb > 1048576., 2., 1.] + sk If[sk > 1048576., 2., 1.] + su / 70.;
				largest = Max[largest, sk]
			],
			{step, stepCount}
		];
		{cost, largest}
	]
]

greedyPlannableQ[data_] :=
	AllTrue[{"Vertices", "Dimensions", "Indices", "Contractions"}, KeyExistsQ[data, #] &] &&
		AllTrue[data["Tensors"], arrayExplicitQ[#] || NumericQ[#] &] &&
		DuplicateFreeQ[data["FreeIndices"]]


Options[TensorNetworkContract] = Options[TensorNetworkContraction]

TensorNetworkContract[data_ ? AssociationQ, path : Automatic | _String | _ ? CanonicalPathQ, opts : OptionsPattern[]] :=
	TensorNetworkContraction[data, path, opts, "Inactive" -> False]

TensorNetworkContract[net_Graph ? TensorNetworkGraphQ, args___] := TensorNetworkContract[TensorNetworkGraphData[net], args]

TensorNetworkContract[net_TensorNetwork ? TensorNetworkQ, args___] := TensorNetworkContract[TensorNetworkData[contractionNetwork[net, {args}]], args]

TensorNetworkContract[net_, opts : OptionsPattern[]] := TensorNetworkContraction[net, opts, "Inactive" -> False]



contractionTree[IgnoringInactive[t : HoldPattern @ ArrayDot[x_, y_, k_]]] := Tree[Subscript[symbolicTensorDimensions[t], Underscript["\[CenterDot]", k]], {contractionTree[x], contractionTree[y]}]
contractionTree[IgnoringInactive[t : HoldPattern @ Dot[x_, y_]]] := Tree[Subscript[symbolicTensorDimensions[t], "\[CenterDot]"], {contractionTree[x], contractionTree[y]}]
contractionTree[IgnoringInactive[t : HoldPattern @ Transpose[x_, perm_]]] := Tree[DirectedEdge[symbolicTensorDimensions[x], symbolicTensorDimensions[t], perm], {contractionTree[x]}]
contractionTree[IgnoringInactive[t : HoldPattern @ ArrayReshape[x_, shape_]]] := Tree[symbolicTensorDimensions[x] -> shape, {contractionTree[x]}]
contractionTree[IgnoringInactive[t : HoldPattern @ TensorProduct[xs__]]] := Tree[Subscript[symbolicTensorDimensions[t], "\[CircleTimes]"], contractionTree /@ {xs}]
contractionTree[IgnoringInactive[t : HoldPattern @ TensorContract[x_, c_]]] := Tree[Subscript[symbolicTensorDimensions[t], c], {contractionTree[x]}]
contractionTree[x_] := symbolicTensorDimensions[x]

toSymbolicTensorAll[x_] := ArraySymbol["T", symbolicTensorDimensions[x]]

contractionTreeNamed[IgnoringInactive[t : HoldPattern @ ArrayDot[x_, y_, k_]]] := Tree[Inactive[ArrayDot][toSymbolicTensorAll[x], toSymbolicTensorAll[y], k], {contractionTreeNamed[x], contractionTreeNamed[y]}]
contractionTreeNamed[IgnoringInactive[t : HoldPattern @ Dot[x_, y_]]] := Tree[Inactive[Dot][toSymbolicTensorAll[x], toSymbolicTensorAll[y]], {contractionTreeNamed[x], contractionTreeNamed[y]}]
contractionTreeNamed[IgnoringInactive[t : HoldPattern @ Transpose[x_, perm_]]] := Tree[Transpose[toSymbolicTensorAll[x], perm], {contractionTreeNamed[x]}]
contractionTreeNamed[IgnoringInactive[t : HoldPattern @ ArrayReshape[x_, shape_]]] := Tree[Inactive[ArrayReshape][toSymbolicTensorAll[x], shape], {contractionTreeNamed[x]}]
contractionTreeNamed[IgnoringInactive[t : HoldPattern @ TensorProduct[xs__]]] := Tree[TensorProduct @@ toSymbolicTensorAll /@ {xs}, contractionTreeNamed /@ {xs}]
contractionTreeNamed[IgnoringInactive[t : HoldPattern @ TensorContract[x_, c_]]] := Tree[Inactive[TensorContract][toSymbolicTensorAll[x], c], {contractionTreeNamed[x]}]
contractionTreeNamed[x_] := toSymbolicTensorAll[x]

Options[ContractionTree] = Join[Options[Tree], {"Labels" -> Automatic}]

ContractionTree[expr_, opts : OptionsPattern[]] :=
	Tree[
		If[OptionValue["Labels"] === "Dimensions", contractionTree[expr], Tree[toSymbolicTensorAll[expr], {contractionTreeNamed[expr]}]],
		FilterRules[
			{opts, AspectRatio -> 1 / 2, TreeLayout -> Right, TreeElementLabelStyle -> {All -> FontSize -> 6}},
			Options[Tree]
		]
	]
