Package["Wolfram`TensorNetworks`"]

PackageExport[GreedyContractionPath]
PackageExport[OptimalContractionPath]

PackageScope[extractContractionParameters]



ClearAll["Wolfram`TensorNetworks`*", "Wolfram`TensorNetworks`**`*"]

(* The Rust optimizers are packaged by `cargo wl build` (cargo-wl, from
   WolframResearch/wolfram-rust-library): it compiles the Cotengra cdylib,
   reads the function manifest the #[export] macro embeds in the binary, and
   writes the library together with a generated Functions.wl loader into
   Binaries/Cotengra-<SystemID>/. Getting that Functions.wl yields
   <|"name" -> function, ...|> with the WXF (de)serialization built in. *)

libraryLoaderFile := FileNameJoin[{
	PacletObject["Wolfram/TensorNetworks"]["Location"],
	"Binaries", "Cotengra-" <> $SystemID, "Functions.wl"
}]

libraryFunctions := libraryFunctions = Replace[
	If[ FileExistsQ[libraryLoaderFile], Get[libraryLoaderFile], $Failed], {
	functions_ ? AssociationQ :>
		Association @ KeyValueMap[
			#1 -> Composition[
				Replace[LibraryFunctionError[error_, code_] :>
					Failure["RustError", <|
						"MessageTemplate" -> "Rust error: `` (``)",
						"MessageParameters" -> {error, code},
					"Error" -> error, "ErrorCode" -> code, "Function" -> #1
				|>]
			],
			#2
		] &,
		functions
	],
	failure_ :> Function @ Function @ Failure["LibraryLoadError", <|
		"MessageTemplate" -> "No Cotengra library package for ``; prebuild it with build_all_targets.sh",
		"MessageParameters" -> {$SystemID},
		"Return" -> failure
	|>]
}
]

(* WXF boundary helpers: the generated loader BinarySerializes the argument
   list, and the Rust side reads Vec<u32> from a packed array (ByteArray[{}]
   standing in for an empty one, which NumericArray cannot express), jagged
   index lists flattened to (indices, lengths), and Option values in
   wolfram-serialize's enum encoding. *)
indexArray[{}] := ByteArray[{}]
indexArray[list_List] := NumericArray[list, "UnsignedInteger32"]
option[None] := "None"
option[value_] := {"Some", value}


Options[GreedyContractionPath] = {
    "MemoryWeight" -> None,
    "Temperature" -> None,
    "MaxNeighbors" -> None,
    "RandomSeed" -> None,
    "PreSimplify" -> None,
    "FixedIndexing" -> None
};

GreedyContractionPath[
    input : {{___Integer}...},
    output : {___Integer},
    sizeDict : KeyValuePattern[(_Integer -> _Integer) ...] ? AssociationQ,
    opts : OptionsPattern[]
] := GreedyContractionPath[
    input, output, sizeDict,
    OptionValue["MemoryWeight"],
    OptionValue["Temperature"],
    OptionValue["MaxNeighbors"],
    OptionValue["RandomSeed"],
    OptionValue["PreSimplify"],
    OptionValue["FixedIndexing"]
]

GreedyContractionPath[
	input : {{___Integer}...},
	output : {___Integer},
	sizeDict : KeyValuePattern[(_Integer -> _Integer) ...] ? AssociationQ,
	costMod : _ ? NumericQ | None : None,
	temperature : _ ? NumericQ | None : None,
	maxNeighbors : _Integer | None : None,
    seed : _Integer | None : None,
	simplify : True | False | None : None,
	useSSA : True | False | None : None
] := Block[{path},
	Enclose[
		path = Confirm @ libraryFunctions["optimize_greedy"][
			indexArray @ Catenate[input],
			indexArray[Length /@ input],
			indexArray @ output,
			N /@ Replace[sizeDict, Except[_ ? NumericQ] -> 2, 1],
			option @ N[costMod],
			option @ N[temperature],
			option @ maxNeighbors,
			option @ seed,
			option @ simplify,
			option @ useSSA
		];
		path + 1
	]
]

Options[OptimalContractionPath] = {
    Method -> "size",
    "PruningThreshold" -> None,
    "AllowOuterProducts" -> None,
    "PreSimplify" -> None,
    "FixedIndexing" -> None
};

(* Pattern using Method option - must come before positional pattern *)
OptimalContractionPath[
    input : {{___Integer}...},
    output : {___Integer},
    sizeDict : KeyValuePattern[(_Integer -> _Integer) ...] ? AssociationQ,
    opts : OptionsPattern[]
] := OptimalContractionPath[
    input, output, sizeDict,
    OptionValue[Method],
    OptionValue["PruningThreshold"],
    OptionValue["AllowOuterProducts"],
    OptionValue["PreSimplify"],
    OptionValue["FixedIndexing"]
]

(* Pattern with positional minimize for backward compatibility *)
OptimalContractionPath[
    input : {{___Integer}...},
    output : {___Integer},
    sizeDict : KeyValuePattern[(_Integer -> _Integer) ...] ? AssociationQ,
    minimize : _String | None,
    opts : OptionsPattern[]
] := OptimalContractionPath[
    input, output, sizeDict, minimize,
    OptionValue["PruningThreshold"],
    OptionValue["AllowOuterProducts"],
    OptionValue["PreSimplify"],
    OptionValue["FixedIndexing"]
]

OptimalContractionPath[
	input : {{___Integer}...},
	output : {___Integer},
	sizeDict : KeyValuePattern[(_Integer -> _Integer) ...] ? AssociationQ,
	minimize : _String | None : None,
	costCap : _ ? NumericQ | None : None,
	searchOuter : True | False | None : None,
	simplify : True | False | None : None,
	useSSA : True | False | None : None
] := Block[{path},
	Enclose[
		path = Confirm @ libraryFunctions["optimize_optimal"][
			indexArray @ Catenate[input],
			indexArray[Length /@ input],
			indexArray @ output,
			N /@ Replace[sizeDict, Except[_ ? NumericQ] -> 2, 1],
			option @ minimize,
			option @ N[costCap],
			option @ searchOuter,
			option @ simplify,
			option @ useSSA
		];
		path + 1
	]
]

(* Internal helper for parameter extraction *)
extractContractionParameters[KeyValuePattern[{
    "Dimensions" -> tensorDimensions_,
    "Indices" -> tensorIndices_,
    "Contractions" -> contractions_
}]] := Enclose @ Block[{
    dimensions, pairs, rules, indices, normalIndices, input, output
},
    dimensions = AssociationThread[Catenate[tensorIndices], Catenate[tensorDimensions]];
    pairs = Cases[Catenate[contractions], {_, _}];
    rules = Rule @@@ pairs;
    ConfirmAssert[AllTrue[Partition[Lookup[dimensions, Catenate[pairs]], 2], Apply[Equal]]];
    dimensions = KeyMap[Replace[rules], dimensions];
    indices = Replace[tensorIndices, rules, {2}];
    normalIndices = Thread[# -> Range[Length[#]]] & [Union @@ indices];
    input = Replace[indices, normalIndices, {2}];
    output = Replace[Cases[Catenate[contractions], Except[{_, _}]], normalIndices, 1];
    dimensions = KeyMap[Replace[normalIndices], dimensions];
    {input, output, dimensions}
]

extractContractionParameters[net_Graph ? TensorNetworkGraphQ] :=
    extractContractionParameters[TensorNetworkGraphData[net]]

extractContractionParameters[net_TensorNetwork ? TensorNetworkQ] :=
    extractContractionParameters[TensorNetworkData[BinaryTensorNetwork[net]]]

(* `"FixedIndexing" -> True` puts the Rust path in SSA form (positions > input length).
   CanonicalPath assumes the opt_einsum convention and fails with `Delete::partw`
   on SSA positions, so we skip the canonicalize step in that case. *)
fixedIndexingQ[args___] := MemberQ[{args}, ("FixedIndexing" -> True) | (True /; False)] ||
    Cases[{args}, ("FixedIndexing" -> v_) :> TrueQ[v]] === {True}
maybeCanonicalize[result_, args___] :=
    If[fixedIndexingQ[args] || !MatchQ[result, _List ? PathQ], result, CanonicalPath[result]]

(* TensorNetwork input patterns *)
GreedyContractionPath[net_TensorNetwork ? TensorNetworkQ, args___] :=
    With[{params = extractContractionParameters[net]},
        maybeCanonicalize[GreedyContractionPath[Sequence @@ params, args], args]
    ]

OptimalContractionPath[net_TensorNetwork ? TensorNetworkQ, args___] :=
    With[{params = extractContractionParameters[net]},
        maybeCanonicalize[OptimalContractionPath[Sequence @@ params, args], args]
    ]

(* Graph input patterns *)
GreedyContractionPath[net_Graph ? TensorNetworkGraphQ, args___] :=
    With[{params = extractContractionParameters[net]},
        maybeCanonicalize[GreedyContractionPath[Sequence @@ params, args], args]
    ]

OptimalContractionPath[net_Graph ? TensorNetworkGraphQ, args___] :=
    With[{params = extractContractionParameters[net]},
        maybeCanonicalize[OptimalContractionPath[Sequence @@ params, args], args]
    ]

(* Association/data input patterns *)
GreedyContractionPath[data : KeyValuePattern[{
    "Dimensions" -> _, "Indices" -> _, "Contractions" -> _
}], args___] :=
    With[{params = extractContractionParameters[data]},
        maybeCanonicalize[GreedyContractionPath[Sequence @@ params, args], args]
    ]

OptimalContractionPath[data : KeyValuePattern[{
    "Dimensions" -> _, "Indices" -> _, "Contractions" -> _
}], args___] :=
    With[{params = extractContractionParameters[data]},
        maybeCanonicalize[OptimalContractionPath[Sequence @@ params, args], args]
    ]

(* Inactive TensorContract/Transpose input patterns *)
GreedyContractionPath[
    expr : IgnoringInactive @ HoldPattern @ TensorContract[TensorProduct[___], _],
    args___
] := GreedyContractionPath[TensorNetwork[expr], args]

GreedyContractionPath[
    expr : HoldPattern[Transpose[_, _Cycles]],
    args___
] := GreedyContractionPath[TensorNetwork[expr], args]

OptimalContractionPath[
    expr : IgnoringInactive @ HoldPattern @ TensorContract[TensorProduct[___], _],
    args___
] := OptimalContractionPath[TensorNetwork[expr], args]

OptimalContractionPath[
    expr : HoldPattern[Transpose[_, _Cycles]],
    args___
] := OptimalContractionPath[TensorNetwork[expr], args]

