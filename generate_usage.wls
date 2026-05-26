#!/usr/bin/env wolframscript
(* Regenerate the Usage.wl files (one per paclet context) from the Usage
   cells of every reference page.

   Each doc symbol is routed to the context whose kernel sources define it
   (detected by scanning Kernel/**/*.wl for the Package[...] header and
   top-level symbol definitions). Three contexts are produced:

       Wolfram`TensorNetworks`            -> Kernel/Usage.wl
       Wolfram`TensorNetworks`IndexArray` -> Kernel/IndexArray/Usage.wl
       Wolfram`TensorNetworks`Symmetry`   -> Kernel/Symmetry/Usage.wl

   Formula cells (InlineFormula) are emitted in the canonical Wolfram
   linear-box form so the kernel/FrontEnd renders bold function names and
   italic argument slots - like native System` usage strings (cf. ?Map).
   Mirrors GeneralUtilities`Code`PackagePrivate`asLinear and linearSlot,
   the helpers SetUsage uses internally. *)

$root = DirectoryName[ExpandFileName[If[$InputFileName === "", NotebookFileName[], $InputFileName]]];

$symbolsDir = FileNameJoin[{$root, "TensorNetworks", "Documentation", "English", "ReferencePages", "Symbols"}];
$kernelDir = FileNameJoin[{$root, "TensorNetworks", "Kernel"}];

$defaultContext = "Wolfram`TensorNetworks`";
$contextFiles = <|
	"Wolfram`TensorNetworks`" -> FileNameJoin[{$kernelDir, "Usage.wl"}],
	"Wolfram`TensorNetworks`IndexArray`" -> FileNameJoin[{$kernelDir, "IndexArray", "Usage.wl"}],
	"Wolfram`TensorNetworks`Symmetry`" -> FileNameJoin[{$kernelDir, "Symmetry", "Usage.wl"}]
|>;

(* ---- symbol -> context map, built by scanning kernel sources ---- *)

scanKernelFile[file_String] := Module[{text, ctx, syms},
	text = Import[file, "Text"];
	ctx = FirstCase[
		StringCases[text, "Package[\"" ~~ c : Except["\""] .. ~~ "\"]" :> c],
		_String, Missing[]
	];
	If[MissingQ[ctx], Return[{}]];
	syms = DeleteDuplicates @ StringCases[
		text,
		StartOfLine ~~ name : ((LetterCharacter | "$") ~~ (WordCharacter | "$") ...) ~~
			Except[WordCharacter | "$"] :> name
	];
	# -> ctx & /@ syms
];

kernelFiles = Select[FileNames["*.wl", $kernelDir, Infinity], FileBaseName[#] =!= "Usage" &];
$symContext = Association @@ Flatten[scanKernelFile /@ kernelFiles];

(* ---- box-tree cleanup: strip link buttons, tags, decorations ---- *)

cleanBoxes[ButtonBox[label_, ___]] := cleanBoxes[label]
cleanBoxes[FormBox[x_, ___]] := cleanBoxes[x]
cleanBoxes[TagBox[x_, ___]] := cleanBoxes[x]
cleanBoxes[InterpretationBox[x_, ___]] := cleanBoxes[x]
cleanBoxes[TooltipBox[x_, ___]] := cleanBoxes[x]
cleanBoxes[AdjustmentBox[x_, ___]] := cleanBoxes[x]
cleanBoxes[FrameBox[x_, ___]] := cleanBoxes[x]
cleanBoxes[StyleBox[x_, opts___]] := StyleBox[cleanBoxes[x], opts]
cleanBoxes[(h : RowBox | SubscriptBox | SuperscriptBox | SubsuperscriptBox |
		FractionBox | SqrtBox | RadicalBox | OverscriptBox |
		UnderscriptBox | UnderoverscriptBox | GridBox)[args__]] :=
	h @@ Replace[{args}, x_ :> cleanBoxes[x], {1}]
cleanBoxes[list_List] := cleanBoxes /@ list
cleanBoxes[other_] := other

(* ---- linear-box form: \!\(\*<inputform>\) ---- *)

(* When the cleaned formula is just a plain string (e.g. "True", "False",
   "OptimalContractionPath"), drop the linear-box wrapper - the result
   renders identically and the source stays readable. *)
asLinear[s_String] := s
asLinear[expr_] := "\!\(\*" <> ToString[expr, InputForm] <> "\)"

(* ---- TextData / Cell -> usage-string fragments ---- *)

cellToString[s_String] := s
cellToString[TextData[items_List]] := StringJoin[cellToString /@ items]
cellToString[TextData[item_]] := cellToString[item]
cellToString[Cell[_, "ModInfo", ___]] := ""
cellToString[Cell[BoxData[boxes_], "InlineFormula", ___]] := asLinear[cleanBoxes[boxes]]
cellToString[Cell[BoxData[boxes_], ___]] := asLinear[cleanBoxes[boxes]]
cellToString[Cell[content_, ___]] := cellToString[content]
cellToString[other_] := ToString[other, InputForm]

(* ---- post-process: collapse separators, one paragraph per line ---- *)

formatUsage[raw_String] := Module[{s = raw, paragraphs},
	s = StringReplace[s, "\[LineSeparator]" -> " "];
	paragraphs = StringTrim /@ StringSplit[s, "\n"];
	paragraphs = StringTrim[StringTrim[#, WhitespaceCharacter]] & /@ paragraphs;
	paragraphs = DeleteCases[paragraphs, ""];
	StringRiffle[paragraphs, "\n"]
];

(* ---- per-file pipeline ---- *)

processFile[file_String] := Module[{nb, cell, raw, text, name = FileBaseName[file], ctx},
	nb = Get[file];
	If[Head[nb] =!= Notebook, Print["Could not Get ", file]; Return[Nothing]];
	cell = FirstCase[nb, Cell[content_, "Usage", ___] :> content, Missing[], Infinity];
	If[MissingQ[cell], Print["No Usage cell in ", file]; Return[Nothing]];
	ctx = Lookup[$symContext, name, $defaultContext];
	If[! KeyExistsQ[$contextFiles, ctx],
		Print["Unknown context ", ctx, " for ", name, " - routing to default"];
		ctx = $defaultContext
	];
	raw = cellToString[cell];
	text = formatUsage[raw];
	ctx -> (name <> "::usage = " <> ExportString[text, "WL", "Comments" -> None])
];

symbolFiles = Sort @ FileNames["*.nb", $symbolsDir];
Print["Processing ", Length[symbolFiles], " files\:2026"];

entries = processFile /@ symbolFiles;
grouped = GroupBy[entries, First -> Last];

KeyValueMap[
	Function[{ctx, lines},
		Module[{outFile = $contextFiles[ctx], stream, content},
			content = StringRiffle[Prepend[Sort[lines], "Package[\"" <> ctx <> "\"]"], "\r\n\r\n\r\n"];
			stream = OpenWrite[outFile, CharacterEncoding -> "UTF-8"];
			WriteString[stream, content];
			Close[stream];
			Print["Wrote ", Length[lines], " usage messages to ", outFile];
		]
	],
	grouped
];

(* Make sure every context's file gets touched (in case a context has no symbols) *)
KeyValueMap[
	Function[{ctx, outFile},
		If[! KeyExistsQ[grouped, ctx],
			Module[{stream},
				stream = OpenWrite[outFile, CharacterEncoding -> "UTF-8"];
				WriteString[stream, "Package[\"" <> ctx <> "\"]\r\n"];
				Close[stream];
				Print["Wrote empty stub to ", outFile];
			]
		]
	],
	$contextFiles
];
