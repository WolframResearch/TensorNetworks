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

leafContainerAutomaticQ[spec_] := Lookup[contractionMethodOptions[spec], "LeafContainer", Automatic] === Automatic

(* With no container asked for, an evaluated contraction is free to choose how
   each array is stored, and it chooses by fill: a SparseArray at least
   $denseFill full computes faster as a dense array, so leaves are converted
   before the first step and every intermediate after its own.  The conversion
   is Normal followed by packedIfMachine below, so machine-number arrays pack and
   exact ones stay exact; a packer that coerces would turn 1/2 into 0.5.  The
   policy belongs here rather than in Wolfram/Arrays, whose contract is that a
   container survives an operation: only the contraction knows that the array
   is an intermediate nobody asked to keep.

   The threshold is measured, not chosen.  Below about a fifth, densifying a
   leaf costs more than it saves (a PEPS of 10%-filled leaves contracts 50%
   slower when they are densified); above it the dense form wins, and on
   intermediates by far: never densifying a 30%-filled MPS took 2.5 s against
   0.04 s, a 60%-filled PEPS 14 s against 0.27 s, and a 14-qubit QFT circuit,
   93% filled, 0.27 s against 0.08 s.  Thresholds from 0.1 to 0.35 were within
   noise of each other everywhere else. *)

$denseFill = 0.2

computeRepresentation[t_SparseArray] /; t["Density"] >= $denseFill := packedIfMachine[Normal[t]]

computeRepresentation[t_List] /; ! Developer`PackedArrayQ[t] := packedIfMachine[t]

computeRepresentation[t_] := t

(* An array of machine numbers is stored packed.  The non-coercing packer
   refuses one that mixes Real and Complex entries - the numeric diagonal of a
   phase gate, {1., 1., 1., 0.98 + 0.2 I}, is one - and every product built from
   such an array then stayed unpacked too: 74 of the 105 steps of a 14-qubit QFT
   circuit ran on unpacked lists.  Promoting a machine Real to a machine Complex
   loses nothing, unlike making an exact value inexact, so such an array packs
   as Complex.  An array with an exact entry packs only as it already would on
   its own - an integer array does - and is never made inexact here.  Plain
   packing is tried first because it settles the common case, a uniform array,
   without scanning the elements: 0.8 ms rather than 16 ms over the 216 leaves
   of a phase-oracle circuit. *)
packedIfMachine[t_] := With[{packed = Developer`ToPackedArray[t]},
    If[ Developer`PackedArrayQ[packed] || ! ArrayQ[t, _, MachineNumberQ],
        packed,
        Developer`ToPackedArray[t, Complex]
    ]
]

(* A network holding a machine number anywhere contracts to machine numbers:
   every term of every output entry is a product of one entry of EVERY tensor,
   so each term carries a machine factor.  Its exact tensors are therefore
   converted to machine numbers once, before the first step, rather than being
   numericized again at every multiplication - and rather than having two exact
   phases multiplied symbolically whenever two exact gates meet.  With the
   packing above this took a 14-qubit QFT circuit of exact gates acting on a
   machine-number state from 0.20 s to 0.02 s.  A network with no machine number
   anywhere is left exact, and so is one carrying any number of precision other
   than machine precision. *)
machinePrecisionLeaves[tensors_] := If[Min[Precision /@ tensors] === MachinePrecision, N[tensors], tensors]


(* ---------------------------------------------------------------------------
   Executing a tree path

   A tree path fixes WHICH tensors meet at each step; what a step sums is read
   off the index labels.  A label the two operands share is summed when nothing
   outside them still needs it - no tensor elsewhere in the network, no output
   index - and kept, once, when something does.  The kept case is a BATCH index:
   an index on three or more tensors, or an output index two tensors share,
   rides along every step that still needs it and is summed by the last one.
   That is how a hyperedge is contracted without binarizing it: no delta spider
   is built, so none can grow with the number of tensors on the index.

   A network whose every shared label is a plain bond between two tensors never
   has a kept shared label, and each of its steps goes to the method's pair
   handler exactly as it always has.

   Before any step a leaf settles the labels that are its alone: a label it
   carries twice is a diagonal, and a label no other tensor and no output
   carries is summed out - a trace when it is both.
--------------------------------------------------------------------------- *)

TensorNetworkContraction::netbatch = "The \"NetGraph\" method cannot contract the indices `1`, which both operands carry and the rest of the network still needs; contract BinaryTensorNetwork of the network instead."

(* Every node of the fold is {tensor, labels, holders}: the array, the label of
   each of its axes, and how many leaves under the node carry each label.  A
   label stays on a node while that count is short of the number of leaves in
   the whole network carrying it, or while the output names it. *)

contractTreePath[treePath_, leaves_Association, output_List, settings_Association] := Most @ contractTreeNode[
    treePath,
    Join[settings, <|
        "Leaves" -> leaves,
        "Holders" -> Counts[Catenate[DeleteDuplicates /@ Values[leaves][[All, 2]]]],
        "Output" -> AssociationThread[output, True],
        "Dimension" -> labelDimensions[Values[leaves]]
    |>]
]

(* The dimension of an index is a constant of the network, so it is read off the
   leaves once rather than off intermediates, which may be inert expressions.  A
   leaf of unknown shape names no dimension. *)
labelDimensions[leaves_List] := Association @ Catenate @ Map[
    With[{dims = tensorDimensions[First[#]]},
        If[Length[dims] == Length[Last[#]], Thread[Last[#] -> dims], {}]
    ] &,
    leaves
]

contractTreeNode[{v_}, env_] /; KeyExistsQ[env["Leaves"], v] := settleLeaf[env["Leaves"][v], env]

contractTreeNode[{node_List}, env_] := contractTreeNode[node, env]

contractTreeNode[nodes : {_, __}, env_] := Fold[
    contractStep[#1, #2, env] &,
    contractTreeNode[First[nodes], env],
    contractTreeNode[#, env] & /@ Rest[nodes]
]

keptLabelQ[label_, holders_, env_] := holders[label] < env["Holders"][label] || Lookup[env["Output"], label, False]

contractStep[{a_, i_, ha_}, {b_, j_, hb_}, env_] := Block[{
    holders = Merge[{ha, hb}, Total], batch, result
},
    batch = Select[i, MemberQ[j, #] && keptLabelQ[#, holders, env] &];
    result = Which[
        batch =!= {},
            contractBatchPair[{a -> i, b -> j}, batch, env],
        (* A step with a rank-0 operand is a product with a scalar, and Times
           keeps the other operand's shape where the handlers' TensorProduct does
           not: TensorProduct[{-2, -1}, 0] is the scalar 0, so a network holding
           an exact zero lost its shape, evaluated or activated. *)
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

(* A Transpose whose level list repeats an entry takes the diagonal of the
   levels it merges, and Total over a range of levels sums them out. *)
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

(* A SparseArray takes its diagonal from its stored entries instead: Transpose
   with a repeated level crashes the kernel on a SparseArray whose nonzeros all
   lie off that diagonal, as Transpose[SparseArray[{{1, 2} -> 3.}, {2, 2}],
   {1, 1}] does.  An entry survives when its position agrees across every group
   of merged levels, and the background stays the background. *)
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

(* The inert form contracts every slot of a settled label into one extra
   operand: a delta over its slots - with one more leg left open when the label
   is kept - or, for a single slot to sum, a vector of ones. *)
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
                (* A plain trace contracts its two slots with each other and
                   needs no delta at all, which also keeps a delta - and the
                   unpacking of every packed array beside one - out of the
                   commonest case. *)
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

(* Both operands are laid out as [batch, own, summed] blocks and the pair is one
   matrix product per batch entry.  With nothing summed each product is an outer
   product, which is the elementwise case: a diagonal gate meeting the state it
   acts on.  The batch axes lead the result. *)
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
        (* Nothing summed: one outer product per batch entry, which is the step
           every diagonal gate takes.  The singleton summed axis is dropped by
           ArrayReshape, not by Part: x[[All, All, 1]] copies element by element
           and took 7 ms on a million entries, ArrayReshape 0.17 ms, which alone
           halved a 20-qubit phase oracle, 1.49 s to 0.74 s. *)
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

(* The outer products of the rows of x ({nb, na}) and y ({nb, nf}), all at
   once.  Times threads x over the leading two levels of the {nb, na, nf}
   replica of y and broadcasts each entry over a row, which beats a Dot per
   batch entry by up to twenty times.  But Times on packed arrays of different
   ranks pays per row, so when the rows are short and many - diagonal gates
   merged over most of the wires - both operands are brought to the full shape
   first and multiplied elementwise, which took the same oracle from 0.74 s to
   0.57 s. *)
batchOuter[x_, y_, na_, nf_] /; na nf <= 16 && Length[x] >= 4096 := Which[
    na == 1 && nf == 1, Flatten[x] * Flatten[y],
    na == 1, Transpose[ConstantArray[Flatten[x], nf]] * y,
    nf == 1, x * Transpose[ConstantArray[Flatten[y], na]],
    True, Transpose[ConstantArray[x, nf], {3, 1, 2}] * Transpose[ConstantArray[y, na], {2, 1, 3}]
]

batchOuter[x_, y_, na_, _] := x * Transpose[ConstantArray[y, na], {2, 1, 3}]

(* The inert form ties each batch index through a rank-3 delta: one leg to each
   operand's slot and one left open, which is the batch axis of the result. *)
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

(* The network a contraction of net runs on.  A path names operands by position,
   so it belongs to the network it was planned for, and a network is planned
   over its own tensors, hyperedges included.  A path whose operand count is
   that of BinaryTensorNetwork[net] instead was planned over the binarized
   network - the only frame a hyperedge network had before hyperedges were
   contracted natively - and runs there, so such a path keeps working.  The
   "NetGraph" method has no batch layer and always runs on the binarized
   network. *)
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
    leafTensors, represent, tensorPath, perm, net
},
    leafTensors = convertLeafTensors[OptionValue[Method], tensors];
    If[! ListQ[leafTensors], netFail[]];
    If[! inactiveQ, leafTensors = computableLeafTensors[leafTensors]];
    represent = If[
        ! inactiveQ && ! netGraphMethodQ[method] && leafContainerAutomaticQ[OptionValue[Method]],
        computeRepresentation,
        Identity
    ];
    If[represent =!= Identity, leafTensors = machinePrecisionLeaves[leafTensors]];
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
] := Which[
	netGraphMethodQ[contractionMethodName[OptionValue[Method]]],
		(* A net is built along a contraction path: the path-free EinsteinSummation
		   route has no net form, so the default optimal path is used. *)
		With[{optimalPath = OptimalContractionPath[data]},
			If[ CanonicalPathQ[optimalPath],
				TensorNetworkContraction[data, optimalPath, opts],
				Message[TensorNetworkContraction::netpath]; $Failed
			]
		],
	(* Automatic lets the contraction choose its order.  Evaluated, it follows the
	   greedy path: EinsteinSummation hands the product of every leaf to a single
	   TensorContract and so has no order at all, 3.3 s on a 216-tensor circuit
	   whose greedy path contracts in 0.2 s.  Left inert, Automatic keeps the one
	   EinsteinSummation expression, the compact symbolic form of the network.
	   The greedy path is taken only where it applies - explicit leaves, an output
	   naming each index once, the optimizer available - and EinsteinSummation
	   is the route everywhere else, as it always was. *)
	! TrueQ[OptionValue["Inactive"]] && path === Automatic && greedyPlannableQ[data],
		With[{treePath = greedyTreePath[data]},
			If[ TreePathQ[treePath],
				TensorNetworkContraction[data, treePath, opts],
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

(* The optimizer's own path goes straight to a tree.  A canonical path is the
   same tree with its steps renumbered, and renumbering is quadratic in the
   number of tensors - a third of the planning time on a 216-tensor circuit - so
   a path that is only ever executed is not canonicalized. *)
greedyTreePath[data_] := With[{parameters = extractContractionParameters[data]},
	If[ MatchQ[parameters, {_List, _List, _Association}],
		With[{raw = GreedyContractionPath @@ parameters},
			If[ PathQ[raw] && Count[raw, {_, _}] + 1 === Length[data["Vertices"]],
				PathToTreePath[raw, data["Vertices"]],
				$Failed
			]
		],
		$Failed
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
