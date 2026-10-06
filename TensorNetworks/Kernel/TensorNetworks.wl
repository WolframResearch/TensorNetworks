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

(* wolfram-serialize reads a bool only from a symbol spelled out as
   System`True or System`False, while BinarySerialize writes System` symbols
   without their context. Each loaded function is a Composition that applies
   BinarySerialize to the argument list; serializeArguments takes its place.
   It writes the argument list itself and serializes each argument with
   BinarySerialize, except a Boolean, alone or as {"Some", b}, whose symbol
   is spelled out in full. Only whole arguments are rewritten, never bytes
   inside another value. A WXF symbol token is the byte 115 ("s"), the name
   length and the name; a function token is 102 ("f"), the argument count
   and the head. Both counts are one byte here, since every name and
   argument list is shorter than 128. *)
wxfSymbolToken[name_String] := Join[{115, StringLength[name]}, ToCharacterCode[name, "UTF8"]]

wxfArgument[b : True | False] := wxfSymbolToken["System`" <> ToString[b]]
wxfArgument[{"Some", b : True | False}] := Join[{102, 2}, wxfSymbolToken["List"], wxfArgument["Some"], wxfArgument[b]]
(* BinarySerialize output starts with the two header bytes "8:". *)
wxfArgument[x_] := Drop[Normal @ BinarySerialize[x], 2]

serializeArguments[args_List] := ByteArray @ Join[
	{56, 58, 102, Length[args]},
	wxfSymbolToken["List"],
	Catenate[wxfArgument /@ args]
]

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
			#2 /. HoldPattern[BinarySerialize] -> serializeArguments
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

(* A network with no index at all - scalars only - gives the optimizers nothing
   to weigh, and their size table cannot be empty: every order contracts it the
   same, so the path is any order. *)
GreedyContractionPath[input : {{} ...}, {}, sizeDict_Association /; sizeDict === <||>, ___] :=
    ConstantArray[{1, 2}, Max[Length[input] - 1, 0]]

OptimalContractionPath[input : {{} ...}, {}, sizeDict_Association /; sizeDict === <||>, ___] :=
    ConstantArray[{1, 2}, Max[Length[input] - 1, 0]]

(* Internal helper for parameter extraction.

   An index on three or more tensors - a hyperedge - is ONE index of the einsum,
   which is how the Rust optimizers read it: it stays on every intermediate that
   still needs it and is summed once nothing outside does.  So every member of a
   group maps to one representative, whatever the group's size.  A pair maps its
   first member to its second, as it always has, so the numbering - and with it
   every path planned for a binary network - is unchanged.

   Both rule sets are Dispatch tables.  As plain rule lists every index
   occurrence was matched against every rule in turn, which made this the
   quadratic step of path finding: 0.68 s of the 0.75 s GreedyContractionPath
   spent on a 216-tensor circuit, of which the optimizer itself took 0.013 s.

   The body is a Block, not Enclose or Module, and that is load-bearing.  Both of
   those walk their held argument - Enclose to tag the Confirm calls in it,
   Module to rename its locals - and the data bound by the pattern is spliced
   into that argument, Association values included.  For a hyperedge network
   "Contractions" spells each group out again at every slot of the group: two
   million expressions for a circuit whose wires each sit on two hundred gates,
   walked once per mention, a second per mention.  Block holds its body without
   walking it, so the disagreeing-dimension check is an explicit Failure. *)
extractContractionParameters[data : KeyValuePattern[{
    "Dimensions" -> _,
    "Indices" -> _,
    "Contractions" -> _
}]] := Block[{
    tensorIndices = data["Indices"], dimensions, groups, rules, indices, normalIndices, input, output
},
    dimensions = AssociationThread[Catenate[tensorIndices], Catenate[data["Dimensions"]]];
    groups = contractionGroups[data];
    If[ AllTrue[groups, Equal @@ Lookup[dimensions, #] &],
        rules = Dispatch @ Catenate[Thread[Most[#] -> Last[#]] & /@ groups];
        dimensions = KeyMap[Replace[rules], dimensions];
        indices = Replace[tensorIndices, rules, {2}];
        normalIndices = Dispatch @ Thread[# -> Range[Length[#]]] & [Union @@ indices];
        input = Replace[indices, normalIndices, {2}];
        output = Replace[plannedOutput[data, rules], normalIndices, 1];
        dimensions = KeyMap[Replace[normalIndices], dimensions];
        {input, output, dimensions}
        ,
        Failure["DimensionMismatch", <|
            "MessageTemplate" -> "The slots of contracted indices `1` do not all have the same dimension.",
            "MessageParameters" -> {Select[groups, ! Equal @@ Lookup[dimensions, #] &]}
        |>]
    ]
]

(* The groups of index slots that are one index of the einsum.  Data that names
   its indices by label - TensorNetworkData - is grouped by label, one pass over
   the slots; reading the groups off its "Contractions" instead costs the square
   of every group's size (see above).  Graph data names a bond only through its
   contraction pairs, so it is read from those.  For a binary network both
   readings give the same groups in the same order, so the numbering of its
   indices does not depend on which one ran. *)
contractionGroups[data_] := If[
    KeyExistsQ[data, "Hyperedges"],
    Select[Values[GroupBy[Catenate[data["Indices"]], Last]], Length[#] > 1 &],
    DeleteDuplicates @ Cases[Catenate[data["Contractions"]], {_, __}]
]

(* The output a path is planned for.  For a network whose shared labels are all
   plain bonds the free indices are exactly the slots no group claims, which is
   how graph data and every binary network has always been read.  A network
   that shares an OUTPUT label between tensors, or leaves a label of its own out
   of its output to be summed, declares its output by label, and each label is
   named through the representative its group maps to - so an output index that
   several tensors carry is planned as one output index.

   One definition, not two clauses: data that declares its output by label is
   also data with "Contractions", so two clauses would be told apart only by the
   order the kernel stores them in, and it does not keep the order they were
   written in. *)
plannedOutput[data_, rules_] := With[{
    hyperedges = Lookup[data, "Hyperedges", None],
    freeIndices = Lookup[data, "FreeIndices", None]
},
    If[ ListQ[hyperedges] && ListQ[freeIndices] && ! plainBondsQ[hyperedges, freeIndices],
        Lookup[
            Association[Last[#] -> Replace[#, rules] & /@ Catenate[data["Indices"]]],
            freeIndices
        ],
        Cases[Catenate[data["Contractions"]], Except[_List]]
    ]
]

(* Every shared label is a bond between exactly two slots and the output is
   exactly the labels carried once: the network every route of this paclet was
   first written for, and the one whose behaviour must not move. *)
plainBondsQ[hyperedges_, freeIndices_] := With[{counts = Counts[Catenate[hyperedges]]},
    AllTrue[counts, # <= 2 &] && Sort[freeIndices] === Sort[Keys[Select[counts, # == 1 &]]]
]

extractContractionParameters[net_Graph ? TensorNetworkGraphQ] :=
    extractContractionParameters[TensorNetworkGraphData[net]]

(* A network is planned over its OWN tensors, hyperedges included: the
   optimizers take an index shared by any number of tensors, and the contraction
   executor keeps such an index on every step that still needs it, so no delta
   spider is inserted.  BinaryTensorNetwork remains the way to plan over the
   binarized network explicitly. *)
extractContractionParameters[net_TensorNetwork ? TensorNetworkQ] :=
    extractContractionParameters[TensorNetworkData[net]]

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

