(* ::Package:: *)

Package["Wolfram`TensorNetworks`"]

PackageExport[TensorNetworkFindContractionPath]

PackageExport[$TensorNetworkContractionMethods]
PackageExport[TensorNetworkContraction]
PackageExport[TensorNetworkContract]

PackageExport[ContractionTree]



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
   NetGraph container

   Every method selects WHICH array container the contraction produces; the
   "NetGraph" method produces a net.  Each leaf tensor is lifted to a layer and
   each contracted pair becomes a transpose / reshape / dot / reshape block, so
   the object threaded through the FixedPoint fold of TensorNetworkContraction
   is itself a NetGraph.  TensorNetworkToNetGraph is a thin wrapper over this
   path.

   This method is NOT a member of $TensorNetworkContractionMethods: that list is
   the set of interchangeable array engines, and a net is not an activatable
   array expression.  It is a Method value all the same, named here.
--------------------------------------------------------------------------- *)

$netGraphContractionMethod = "NetGraph"

TensorNetworkContraction::netleaf = "The tensor `1` cannot be lifted into a net layer: `2`."

TensorNetworkContraction::netpair = "A contraction step with result dimensions `1` cannot be lifted into net layers: `2`."

TensorNetworkContraction::netopen = "The contracted net has open input ports `1`, so it has no explicit array value; use TensorNetworkContraction to obtain the net itself."

TensorNetworkContraction::netpath = "No contraction path is available for the \"NetGraph\" method."

netGraphMethodQ[method_] := method === $netGraphContractionMethod

netGraphQ[x_] := MatchQ[x, _NetGraph]

(* Failures raised while lowering to net layers unwind the whole contraction.
   Enclose / Confirm cannot carry them: Enclose only catches Confirm calls that
   occur inside its own argument, not ones raised by the handler functions the
   contraction fold calls, so a private Throw tag is used instead.  Every net
   failure is announced by one of the messages above before it unwinds. *)
netFail[] := Throw[$Failed, netFailTag]

(* NetExtract gives a bare integer for a rank-1 port and a type name such as
   "Real" for a rank-0 one. *)
netTensorDimensions[net_] := Replace[NetExtract[net, "Output"], {d_Integer :> {d}, d : {___Integer} :> d, _ :> {}}]

netPermutationList[perm_Cycles, n_Integer] := PermutationList[perm, n]

netPermutationList[perm_List, n_Integer] := PermutationList[PermutationCycles[perm], n]

(* PermutationList without the explicit length truncates at the largest moved
   point, so a permutation that fixes trailing levels comes back shorter than
   the rank; the length is always passed here so that a TransposeLayer can never
   be built from a partially specified permutation. *)
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

(* inactiveQ is part of the shared handler signature but has no meaning here: a
   net has no inert head to wrap, so the pair lowering is always eager and the
   net itself is the lazy form. *)
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
	(* A fully contracted pair gives a rank-0 result: the operands become vectors
	   so that DotLayer produces the scalar directly, since ReshapeLayer[{}] is
	   not a layer.  Every other case keeps the matrix form. *)
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
   Leaf array containers

   A method spec is either a method name or {name, subopts...}.  The submethod
   "LeafContainer" -> type leaves the structural result exactly as the named
   method produces it and converts every leaf tensor to the requested array
   container type; the conversion goes through the Wolfram/Arrays route of
   Utilities.wl, so any container that paclet admits later works here unchanged.
--------------------------------------------------------------------------- *)

TensorNetworkContraction::leafname = "`1` is not a known array container type name."

TensorNetworkContraction::leafcont = "The tensor `1` cannot be converted to the array container type `2`: `3`."

contractionMethodName[spec_] := Replace[spec, {{name_, ___} :> name, name_ :> name}]

contractionMethodOptions[spec_] := Replace[spec, {{_, subopts___} :> Flatten[{subopts}], _ :> {}}]

(* THE NAME IS NOT A DISPATCH INTO System`.  Resolving an arbitrary string
   through NameQ / Symbol and APPLYING the result to every leaf tensor makes a
   mistyped container name run a kernel function on the data - "Print" prints
   the tensors, "Quit" ends the session - and silentConstruct is Quiet@Check,
   which suppresses the messages but not the side effects.  NameQ also accepts
   string patterns, so "Sp*" would reach Symbol["System`Sp*"].  The name is
   therefore checked against this list first; it is the set of array-container
   heads Wolfram/Arrays admits, and a head admitted there later is added here. *)

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
		(* The first leaf that cannot be converted stops the conversion, so one
		   failed contraction reports one reason rather than one per leaf. *)
		Catch[
			Map[Replace[toArrayContainer[container, #], $Failed :> Throw[$Failed, leafFailTag]] &, tensors],
			leafFailTag
		]
	]
]

(* With "Inactive" -> False the contraction is EVALUATED, so the leaf container
   is a compute substrate rather than a storage format.  ArrayDot, Dot and
   TensorContract have no rule for a storage-only container: handed a
   NumericArray they leave their own head unevaluated, and TensorNetworkContract
   - the eager entry point, whose callers Confirm an array - would return a
   contraction expression with no message and no $Failed.  Storage-only leaves
   are therefore materialized back before the engine runs; a compute-native
   container (a plain List, a SparseArray, a QuantityArray) is kept, which is
   the whole reason to ask for one on this path. *)

computableLeafTensors[tensors_] := Replace[
	tensors,
	t_ /; ! arrayComputeNativeQ[t] :> arrayContainerMaterialize[t],
	{1}
]


(* $TensorNetworkContractionMethods is the list of INTERCHANGEABLE ARRAY
   ENGINES, and that is the invariant its documentation and every example that
   loops over it rely on: each entry lowers a contraction to a different array
   expression, and ActivateTensors of any two of them gives the same array.
   "NetGraph" is a valid Method value but is NOT one of them - it returns a net,
   not an activatable array expression - so it is listed separately and named in
   the Method documentation instead.  Adding it to the engine list would turn
   "compare all the engines" into a type mismatch. *)

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

TensorNetworkContraction[net_TensorNetwork ? TensorNetworkQ, args__] :=
    TensorNetworkContraction[TensorNetworkData[BinaryTensorNetwork[net]], args]
    
TensorNetworkContraction[net_TensorNetwork ? TensorNetworkQ, _ : Automatic : Automatic] :=
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
    leafTensors, tensorPath, perm, net
},
    leafTensors = convertLeafTensors[OptionValue[Method], tensors];
    If[! ListQ[leafTensors], netFail[]];
    If[! TrueQ[OptionValue["Inactive"]], leafTensors = computableLeafTensors[leafTensors]];
    tensorPath = FixedPoint[
        ReplaceAll[{"Pair"[t1_, i1_], "Pair"[t2_, i2_]} :> "Pair" @@ contractTensorPair[{t1 -> i1, t2 -> i2}, contractOpts]],
        Replace[treePath, MapThread[{#1} -> "Pair"[#2, #3] &, {vertices, leafTensors, contractions}], {-2}]
    ];
    perm = FindPermutation[tensorPath[[2]], freeIndices];
    If[ netGraphMethodQ[method]
        ,
        (* The accumulated object is a net, and a net has no inert head to wrap:
           the trailing transpose is a TransposeLayer appended to it and is
           therefore always applied eagerly, with the default "TransposeFunction"
           standing for that net-level transpose.  A network of a single tensor
           never reaches a pair handler, so the leaf is lifted here.  "Inactive"
           then selects the net itself (True) or its value (False). *)
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
        (* The trailing transpose head must be SUBSTITUTED lexically, not looked
           up: Inactive holds its argument, so a Block-local transposeFunction
           inside Inactive[...] would survive into the returned expression as the
           bare private symbol instead of Transpose (or the caller's
           "TransposeFunction"), and the result would activate to an unevaluated
           head wrapped around the un-transposed array.  Block is fine for every
           other local here; only what goes inside Inactive needs the With. *)
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
	(* Except[_Rule] keeps an option given as the second argument out of the path
	   slot, where it would otherwise be swallowed as an (ignored) path. *)
	path : Except[_Rule | _RuleDelayed] : Automatic,
	opts : OptionsPattern[]
] := If[ netGraphMethodQ[contractionMethodName[OptionValue[Method]]]
	,
	(* A net is built along a contraction path: the path-free EinsteinSummation
	   route has no net form, so the default optimal path is used. *)
	With[{optimalPath = OptimalContractionPath[data]},
		If[ CanonicalPathQ[optimalPath],
			TensorNetworkContraction[data, optimalPath, opts],
			Message[TensorNetworkContraction::netpath]; $Failed
		]
	]
	,
	With[{leafTensors = convertLeafTensors[OptionValue[Method], tensors]},
		If[ ListQ[leafTensors],
			If[ TrueQ[OptionValue["Inactive"]],
				EinsteinSummation[indices -> freeIndices, leafTensors],
				ActivateTensors @ EinsteinSummation[indices -> freeIndices, computableLeafTensors[leafTensors]]
			],
			$Failed
		]
	]
]


Options[TensorNetworkContract] = Options[TensorNetworkContraction]

TensorNetworkContract[data_ ? AssociationQ, path : Automatic | _String | _ ? CanonicalPathQ, opts : OptionsPattern[]] :=
	TensorNetworkContraction[data, path, opts, "Inactive" -> False]

TensorNetworkContract[net_Graph ? TensorNetworkGraphQ, args___] := TensorNetworkContract[TensorNetworkGraphData[net], args]

TensorNetworkContract[net_TensorNetwork ? TensorNetworkQ, args___] := TensorNetworkContract[TensorNetworkData[BinaryTensorNetwork[net]], args]

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
