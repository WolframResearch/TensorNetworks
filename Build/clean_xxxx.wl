#!/usr/bin/env wolframscript

(* Clean XXXX placeholder cells from every reference-page .nb.

   Replaces:
     Cell["XXXX", "Notes" | "Tutorials" | "MoreAbout" | "RelatedLinks" | "Keywords", ...]
       -> Cell[" ", style, ...]                  (* clears boilerplate *)
     Cell["XXXX", "ExampleSubsection", ...]
       -> Cell[" ", "ExampleSubsection", ...]    (* clears option subsections *)
     FrameBox["\"XXXX\""]                          inside SeeAlso TemplateBox
       -> leave alone (the See Also cell was already replaced for new pages;
          existing pages may still have a FunctionPlaceholder XXXX)

   Run:
     wolframscript -file Build/clean_xxxx.wl
   ============================================================ *)

docsDir = "/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks/Documentation/English/ReferencePages/Symbols";

emptyCellStyles = {"Notes", "Tutorials", "MoreAbout", "RelatedLinks", "Keywords", "ExampleSubsection"};

processNB[path_String] := Module[{nb, before, after, edits},
  nb = Get[path];
  before = Count[nb, "XXXX", Infinity];
  nb = nb /. Cell["XXXX", style_String, rest___] /;
    MemberQ[emptyCellStyles, style] :> Cell[" ", style, rest];
  after = Count[nb, "XXXX", Infinity];
  edits = before - after;
  If[edits > 0,
    Export[path, nb, "NB"];
    Print["  ", FileBaseName[path], ": ", before, " -> ", after, " (", edits, " cleared)"]
  ];
  edits
];

Print["Scanning ", docsDir];
files = FileNames["*.nb", docsDir];
Print["Files: ", Length[files]];

totalEdits = Total[processNB /@ files];
Print[""];
Print["Total XXXX cells cleared: ", totalEdits];
remaining = Total[Count[Get[#], "XXXX", Infinity] & /@ files];
Print["Remaining XXXX strings (mostly FrameBox/SeeAlso placeholders): ", remaining];
Quit[0]
