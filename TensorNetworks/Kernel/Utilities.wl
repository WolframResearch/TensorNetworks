Package["Wolfram`TensorNetworks`"]

PackageScope[tensorToVector]
PackageScope[toTensor]
PackageScope[tensorDimensions]
PackageScope[tensorRank]

PackageScope[toSymbolicTensor]
PackageScope[symbolicTensorDimensions]
PackageScope[symbolicTensorRank]

PackageScope[silentConstruct]
PackageScope[arrayContainerQ]
PackageScope[arrayContainerDimensions]
PackageScope[arrayContainerMaterialize]
PackageScope[arrayComputeNativeQ]
PackageScope[arraysAvailableQ]
PackageScope[$arraysAvailable]



tensorToVector[t_ ? TensorQ] := Flatten[t]

tensorToVector[t_] := {t}


toTensor[t_ ? TensorQ] := t

toTensor[t_] := {t}


(* Array containers that TensorDimensions does not know (NumericArray and the
   wrapper containers) fall back to the container route below, which prefers
   Wolfram/Arrays when that paclet is present. *)
tensorDimensions[t_] := Replace[TensorDimensions[t], Except[_List] :> If[arrayContainerQ[t], arrayContainerDimensions[t], {}]]


tensorRank[t_] := Length @ tensorDimensions[t]


(* Constructors of nets and of array containers report low-level errors
   (FunctionLayer::compilerr, NumericArray::nonnum, ...) that name none of the
   objects the caller of this paclet passed in.  Construction goes through
   silentConstruct so that every failure surfaces as a paclet-level message
   naming the offending tensor and the reason instead. *)
SetAttributes[silentConstruct, HoldFirst]

silentConstruct[expr_] := Quiet @ Check[expr, $Failed]


(* Array-container routing.

   Wolfram/Arrays is an OPTIONAL runtime dependency: TensorNetworks declares no
   paclet dependencies at all (see PacletInfo.wl, whose only extensions are
   Kernel, Cargo, Build, Binaries, FrontEnd and Documentation), and Wolfram/Arrays
   is not published, so a hard dependency would make this paclet unloadable
   wherever that paclet is missing.  Each route is therefore probed at run time:
   with Wolfram/Arrays present every container it admits works here with no
   change, and without it the narrow local fallback covers the explicit heads
   this paclet already handles. *)

(* ONLY THE POSITIVE ANSWER IS CACHED.  TensorNetworks is the lower-level paclet
   and is typically touched first, so a container query can easily run before
   Wolfram/Arrays is loaded; memoizing that negative would disable the whole
   optional-dependency route for the rest of the session, even after the paclet
   is present, and arrayContainerQ would then keep misclassifying genuine Arrays
   containers as unrecognized.  A False is therefore re-probed, which costs one
   PacletFind per query until the paclet appears and nothing after that. *)

$arraysAvailable = False

arraysAvailableQ[] := TrueQ[$arraysAvailable] || (
	$arraysAvailable = TrueQ @ And[
		PacletFind["Wolfram/Arrays"] =!= {},
		(* An absent or unloadable optional dependency is not an error here, so
		   the probe stays silent and answers False. *)
		Quiet @ Check[Needs["Wolfram`Arrays`"]; True, False]
	]
)

arraysSymbol[name_String] := Symbol["Wolfram`Arrays`" <> name]


arrayContainerQ[t_] := If[ arraysAvailableQ[],
	TrueQ @ arraysSymbol["ArrayContainerQ"][t],
	ArrayQ[t] || MatchQ[t, _SparseArray | _NumericArray | _SymmetrizedArray]
]

arrayContainerDimensions[t_] := Replace[
	If[arraysAvailableQ[], arraysSymbol["ArrayDimensions"][t], Dimensions[t]],
	Except[{___Integer}] :> {}
]

arrayContainerMaterialize[t_] := If[arraysAvailableQ[], arraysSymbol["ArrayMaterialize"][t], Normal[t]]

(* Compute-nativeness - does the container run Dot and elementwise arithmetic
   without materializing - is what decides whether a leaf container can be
   handed to an evaluated contraction at all.  The local fallback names the two
   heads this paclet can vouch for without Wolfram/Arrays. *)
arrayComputeNativeQ[t_] := If[
	arraysAvailableQ[],
	TrueQ @ arraysSymbol["ArrayComputeNativeQ"][t],
	ArrayQ[t] || MatchQ[t, _SparseArray]
]



Options[toSymbolicTensor] = {"ArrayDotExpand" -> False}

toSymbolicTensor[t_, OptionsPattern[]] := Activate[t /. {
	c_Cycles :> c,
	IgnoringInactive[Verbatim[With][vars_, body_]] :> ArraySymbol["T", symbolicTensorDimensions[body(* /. Rule @@@ vars*)]],
	IgnoringInactive[Verbatim[ArrayReshape][a_, d_]] :> ArraySymbol[toSymbolicTensor[a], d],
	IgnoringInactive[Verbatim[ArrayDot][a_, b_, k_Integer]] :> If[TrueQ[OptionValue["ArrayDotExpand"]],
		With[{d1 = symbolicTensorDimensions[a], d2 = symbolicTensorDimensions[b]},
			Inactive[Dot][
				ArraySymbol[toSymbolicTensor[a], Append[d1[[;; - k - 1]], Times @@ d1[[- k ;;]]]],
				ArraySymbol[toSymbolicTensor[b], Prepend[d2[[k + 1 ;;]], Times @@ d2[[;; k]]]]
			]
		],
		Inactive[ArrayDot][toSymbolicTensor[a], toSymbolicTensor[b], k]
	],
	IgnoringInactive[Verbatim[ArrayDot][a_, b_, indices : {{_Integer, _Integer} ...}]] :> If[TrueQ[OptionValue["ArrayDotExpand"]],
		With[{d1 = symbolicTensorDimensions[a], d2 = symbolicTensorDimensions[b]},
			Inactive[Dot][
				ArraySymbol[
					Inactive[Transpose][toSymbolicTensor[a], FindPermutation[Range[Length[d1]], Join[Complement[Range[Length[d1]], #], #] & @ indices[[All, 1]]]],
					Append[Delete[d1, List /@ indices[[All, 1]]], Times @@ d1[[indices[[All, 1]]]]]
				],
				ArraySymbol[
					Inactive[Transpose][toSymbolicTensor[b], FindPermutation[Range[Length[d2]], Join[#, Complement[Range[Length[d2]], #]] & @ indices[[All, 2]]]],
					Prepend[Delete[d2, List /@ indices[[All, 2]]], Times @@ d2[[indices[[All, 2]]]]]
				]
			]
		],
		Inactive[ArrayDot][toSymbolicTensor[a], toSymbolicTensor[b], indices]
	],
	IgnoringInactive[Dot[a_, b_]] :> Inactive[Dot][toSymbolicTensor[a], toSymbolicTensor[b]],
	IgnoringInactive[Verbatim[Table][_, iter : {_, _Integer} ..]] :> ArraySymbol["T", {iter}[[All, 2]]],
	IgnoringInactive[(h : TensorContract | Transpose)[body_, args__]] :> Inactive[h][toSymbolicTensor[body], args],
	IgnoringInactive[Verbatim[TensorProduct][args__]] :> ArraySymbol["T", Catenate[symbolicTensorDimensions /@ {args}]],
	indices : {{_Integer, _Integer} ...} :> indices,
	tt_ :> ArraySymbol["T", tensorDimensions[tt]]
}, Except[TensorContract | Dot | ArrayDot | TensorProduct]]

(* Base cases for symbolicTensorDimensions - compute dimensions directly without calling toSymbolicTensor *)
symbolicTensorDimensions[ArraySymbol[_, dims_List]] := dims
symbolicTensorDimensions[Inactive[TensorProduct][args__]] := Catenate[symbolicTensorDimensions /@ {args}]
symbolicTensorDimensions[Inactive[ArrayDot][a_, b_, k_Integer]] := Join[Drop[symbolicTensorDimensions[a], -k], Drop[symbolicTensorDimensions[b], k]]
symbolicTensorDimensions[Inactive[ArrayDot][a_, b_, indices : {{_Integer, _Integer} ...}]] := Join[
	Delete[symbolicTensorDimensions[a], List /@ indices[[All, 1]]],
	Delete[symbolicTensorDimensions[b], List /@ indices[[All, 2]]]
]
symbolicTensorDimensions[SymbolicDeltaProductArray[dims_List, _]] := dims
symbolicTensorDimensions[t_ ? TensorQ] := TensorDimensions[t]
(* Transpose with Cycles permutation - permute dimensions accordingly *)
symbolicTensorDimensions[HoldPattern[Transpose[a_, perm_Cycles]]] := Permute[symbolicTensorDimensions[a], perm]
symbolicTensorDimensions[Inactive[Transpose][a_, perm_Cycles]] := Permute[symbolicTensorDimensions[a], perm]
(* Transpose with list permutation *)
symbolicTensorDimensions[HoldPattern[Transpose[a_, perm_List]]] := symbolicTensorDimensions[a][[perm]]
symbolicTensorDimensions[Inactive[Transpose][a_, perm_List]] := symbolicTensorDimensions[a][[perm]]
(* General fallback *)
symbolicTensorDimensions[t_] := Replace[TensorDimensions[toSymbolicTensor[t, "ArrayDotExpand" -> True]], Except[_List] -> {}]

symbolicTensorRank[t_] := Length[symbolicTensorDimensions[t]]
