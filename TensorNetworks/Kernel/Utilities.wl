Package["Wolfram`TensorNetworks`"]

PackageScope[tensorToVector]
PackageScope[toTensor]
PackageScope[tensorDimensions]
PackageScope[tensorRank]

PackageScope[toSymbolicTensor]
PackageScope[symbolicTensorDimensions]
PackageScope[symbolicTensorRank]



tensorToVector[t_ ? TensorQ] := Flatten[t]

tensorToVector[t_] := {t}


toTensor[t_ ? TensorQ] := t

toTensor[t_] := {t}


tensorDimensions[t_] := Replace[TensorDimensions[t], Except[_List] :> {}]


tensorRank[t_] := Length @ tensorDimensions[t]



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
