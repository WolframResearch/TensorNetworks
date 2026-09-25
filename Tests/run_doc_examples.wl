#!/usr/bin/env wolframscript

(* ============================================================
   Tests/run_doc_examples.wl

   Walks every .nb file under
     Documentation/English/ReferencePages/Symbols/
   extracts every Input cell, evaluates it with a 30-second timeout,
   and reports per-page pass/fail.

   An example passes when it neither times out nor returns $Failed and
   the messages it emits are, by name, the ones stored in the Message
   cells after its Input cell. Each page evaluates in a context of its
   own, as it would in a fresh kernel.

   Exit 0 on success, 1 on any failure.
   ============================================================ *)

(* Colored output *)
red    = "\033[0;31m"; green = "\033[0;32m";
yellow = "\033[0;33m"; blue  = "\033[0;34m";
bold   = "\033[1m";    reset = "\033[0m";

checkMark = green <> "\[Checkmark]" <> reset;
crossMark = red   <> "\[Cross]"     <> reset;

printHeader [m_] := Print[bold, blue, "==> ", reset, bold, m, reset];
printSuccess[m_] := Print[green, "  ", checkMark, " ", m, reset];
printFailure[m_] := Print[red,   "  ", crossMark, " ", m, reset];

(* Resolve paths *)
root = DirectoryName @ DirectoryName @ $InputFileName;
If[root === "", root = Directory[]];

pacletDir = FileNameJoin[{root, "TensorNetworks"}];
docsDir   = FileNameJoin[{pacletDir, "Documentation", "English", "ReferencePages", "Symbols"}];

If[! DirectoryQ[docsDir],
  Print[red, "Documentation directory not found: ", docsDir, reset];
  Quit[1]
];

PacletDirectoryLoad[pacletDir];
Needs["Wolfram`TensorNetworks`"];
Needs["Wolfram`TensorNetworks`IndexArray`"];
Needs["Wolfram`TensorNetworks`Symmetry`"];

(* Pre-warm the cotengrust library. The first call into a Rust-backed
   function (e.g. GreedyContractionPath) lazily loads the prebuilt library
   package from Binaries/Cotengra-<SystemID>/. Triggering the lazy load now
   keeps the per-input timeouts honest. *)
GreedyContractionPath[{{1}}, {}, <|1 -> 2|>];

(* Netcon C++ LibraryLink is in hibernation per user directive (2026-05-05).
   Pages whose examples invoke Netcon-backed paths are skipped here so the
   harness does not exercise that code path until Netcon comes back online.
   To re-enable: empty this list. *)
$NetconHibernated = {
  "EinsteinSummation",                   (* hangs on Netcon C++ *)
  "TensorNetworkFindContractionPath"     (* deprecated; internally calls Netcon *)
};

(* Examples whose notebooks are stale: each emits a deliberate validation
   message that the stored notebook has no Message cell for, so the page
   must be regenerated from its source (the .nb is a build output). An
   entry holds the exact message names the example emits today; any other
   outcome, including a pass, fails so the list cannot go stale.
   TableauShape, TableauSize and YoungSymmetrize: the input reads
   "Quiet FailureQ[...]" (Quiet times FailureQ[...]) where
   "Quiet @ FailureQ[...]" was meant. TensorNetworkGraphQ, TensorNetworkQ,
   YoungTableauQ: the message is intended, only the Message cell is missing
   (and YoungTableauQ #13 stores True for a tableau YoungTableau now
   rejects). *)
$AwaitingRegeneration = <|
  {"TableauShape", 7} -> {"TableauShape::noyt"},
  {"TableauSize", 7} -> {"TableauSize::noyt"},
  {"TableauSize", 13} -> {"YoungSymmetrize::rank"},
  {"YoungSymmetrize", 8} -> {"YoungSymmetrize::rank"},
  {"TensorNetworkGraphQ", 4} -> {"TensorNetworkGraphQ::msg2"},
  {"TensorNetworkGraphQ", 10} -> {"TensorNetworkGraphQ::msg2"},
  {"TensorNetworkGraphQ", 11} -> {"TensorNetworkGraphQ::msg3"},
  {"TensorNetworkQ", 12} -> {"TensorNetwork::length"},
  {"TensorNetworkQ", 13} -> {"TensorNetwork::shape"},
  {"TensorNetworkQ", 14} -> {"TensorNetwork::dim"},
  {"TensorNetworkQ", 15} -> {"TensorNetwork::output"},
  {"TensorNetworkQ", 19} -> {"TensorNetwork::shape"},
  {"YoungTableauQ", 3} -> {"YoungTableau::notslot"},
  {"YoungTableauQ", 7} -> {"YoungTableau::notslot"},
  {"YoungTableauQ", 8} -> {"YoungTableau::notslot"},
  {"YoungTableauQ", 9} -> {"YoungTableau::notslot"},
  {"YoungTableauQ", 10} -> {"YoungTableau::notslot"},
  {"YoungTableauQ", 13} -> {"YoungTableau::notslot"},
  {"YoungTableauQ", 16} -> {"YoungTableau::notslot"}
|>;

(* Name "sym::tag" of a message recorded in $MessageList. *)
messageName[HoldForm[MessageName[s_, t_String]]] := SymbolName[Unevaluated[s]] <> "::" <> t
messageName[other_] := ToString[other]

(* Names of the messages a stored Message cell documents: the front end
   writes either a MessageName StyleBox or a MessageTemplate TemplateBox. *)
storedMessageNames[cells_List] := Cases[cells,
  StyleBox[RowBox[{s_String, "::", t_String}], "MessageName", ___] |
    TemplateBox[{s_String, t_String, ___}, "MessageTemplate" | "MessageTemplate2", ___] :> s <> "::" <> t,
  Infinity]

(* The Message cells stored after the Input cell at position pos, up to
   the next Input cell of the same group. *)
documentedMessages[nb_, pos_List] := storedMessageNames @ Cases[
  TakeWhile[Drop[Extract[nb, Most[pos]], Last[pos]], ! MatchQ[#, Cell[_, "Input", ___]] &],
  Cell[_, "Message", ___]]

(* Symbols an example creates live in a context of their own page, so a
   value one page assigns (a, g, chain, ...) never reaches another page. *)
$pageContextPath = DeleteCases[$ContextPath, "Global`"];

(* Outcome of evaluating one input box. Messages the example emits must be
   among the ones documented after its Input cell. *)
evalInput[box_, documented_List, issueQ_] := Block[{expr, parseMsgs, val, msgs},
  {expr, parseMsgs} = Block[{$MessageList = {}, $Messages = {}},
    {ToExpression[box, StandardForm, HoldComplete], DeleteDuplicates[messageName /@ $MessageList]}
  ];
  If[Head[expr] =!= HoldComplete,
    <|"Outcome" -> "ParseFailed: " <> ToString[parseMsgs], "Messages" -> parseMsgs|>,
    Block[{$MessageList = {}, $Messages = {}},
      val = TimeConstrained[ReleaseHold[expr], 30, $TimedOut];
      msgs = DeleteDuplicates[messageName /@ $MessageList]
    ];
    <|"Outcome" -> Which[
        val === $TimedOut, "Timeout",
        issueQ && val === $Failed, "OK",
        val === $Failed, "Failed",
        ! SubsetQ[documented, msgs],
          "UndocumentedMessage: " <> ToString[Complement[msgs, documented]],
        True, "OK"
      ],
      "Messages" -> msgs|>
  ]
]

(* Outcomes of the boxes of one Input cell. A message stored after the
   cell that none of its boxes emits is reported on the cell's last box. *)
evalCell[{boxes_List, documented_List, issueQ_}] := With[
  {results = evalInput[#, documented, issueQ] & /@ boxes},
  With[{missing = Complement[documented, Union @@ Lookup[results, "Messages"]]},
    If[missing === {} || Last[results]["Outcome"] =!= "OK",
      results,
      Append[Most[results],
        <|Last[results], "Outcome" -> "DocumentedMessageNotEmitted: " <> ToString[missing]|>]
    ]
  ]
]

(* An example listed in $AwaitingRegeneration passes as "Regenerate" only
   while it emits exactly its listed messages and nothing else fails. *)
applyRegeneration[page_String, idx_Integer, result_Association] :=
  With[{listed = Lookup[$AwaitingRegeneration, Key[{page, idx}], Missing[]]},
    Which[
      MissingQ[listed], result["Outcome"],
      StringStartsQ[result["Outcome"], "UndocumentedMessage"] && Sort[result["Messages"]] === Sort[listed],
        "Regenerate",
      True,
        "AwaitingRegenerationMismatch: expected " <> ToString[listed] <> ", got " <> result["Outcome"] <>
          " with " <> ToString[result["Messages"]]
    ]
  ]

(* Per-page evaluator *)
evalPage[nbPath_String] := Block[
  {
    nb = Get[nbPath],
    positions, cells, issueGroups, results, failures, baseName = FileBaseName[nbPath]
  },
  If[Head[nb] =!= Notebook,
    Return[<|"Page" -> baseName, "Total" -> 0, "Failed" -> 0, "Skipped" -> True|>]
  ];
  (* Every Input cell as {boxes, documented message names, issueQ}. Cells
     under a "Possible Issues" section document a call that fails, so
     $Failed there is the expected outcome; their messages are still
     checked whenever they return anything else. Position and Cases traverse the notebook
     in the same order. *)
  positions = Position[nb, Cell[BoxData[_], "Input", ___]];
  issueGroups = Position[nb,
    CellGroupData[{Cell[head_, "ExampleSection", ___] /; ! FreeQ[head, "Possible Issues"], ___}, ___]];
  cells = MapThread[
    {If[MatchQ[#2, _List], #2, {#2}],
     documentedMessages[nb, #1],
     AnyTrue[issueGroups, Function[g, Take[#1, UpTo[Length[g]]] === g]]} &,
    {positions, Cases[nb, Cell[BoxData[box_], "Input", ___] :> box, Infinity]}
  ];
  results = Block[
    {$Context = "DocExample`" <> baseName <> "`", $ContextPath = $pageContextPath},
    MapIndexed[applyRegeneration[baseName, First[#2], #1] &, Catenate[evalCell /@ cells]]
  ];
  failures = MapIndexed[
    Function[{outcome, idx},
      If[MatchQ[outcome, "OK" | "Regenerate"], Nothing,
        <|"InputIndex" -> idx[[1]], "Outcome" -> outcome|>]
    ],
    results
  ];
  <|"Page" -> baseName,
    "Total" -> Length[results],
    "Failed" -> Length[failures],
    "Failures" -> failures,
    "Regenerate" -> Flatten[Position[results, "Regenerate"]],
    "Skipped" -> False|>
];

(* Run *)
nbFiles = FileNames["*.nb", docsDir];
nbFiles = Select[nbFiles, ! MemberQ[$NetconHibernated, FileBaseName[#]] &];
printHeader[StringTemplate["Evaluating examples in `1` reference pages (Netcon-hibernated: `2` skipped)"][Length[nbFiles], Length[$NetconHibernated]]];

reports = evalPage /@ nbFiles;

(* Summary *)
totalPages    = Length[reports];
totalExamples = Total[#["Total"] & /@ reports];
totalFailed   = Total[#["Failed"] & /@ reports];
skipped       = Count[reports, _?(#["Skipped"] === True &)];
failedPages   = Select[reports, #["Failed"] > 0 &];
stalePages    = Select[reports, Length[Lookup[#, "Regenerate", {}]] > 0 &];
totalStale    = Total[Length[Lookup[#, "Regenerate", {}]] & /@ reports];

Print[""];
printHeader["Summary"];
Print[bold, "  Pages:     ", totalPages, reset];
Print[bold, "  Examples:  ", totalExamples, reset];
Print[green, "  Passed:    ", totalExamples - totalFailed - totalStale, reset];
If[totalStale > 0,
  Print[yellow, "  Awaiting regeneration: ", totalStale, " (documented message missing from the stored notebook)", reset];
  Scan[Print[yellow, "    ", #["Page"], " inputs ", #["Regenerate"], reset] &, stalePages]
];
If[skipped > 0, Print[yellow, "  Skipped:   ", skipped, " (notebook parse failed)", reset]];

If[totalFailed > 0,
  Print[red, "  Failed:    ", totalFailed, reset];
  Print[""];
  printHeader["Failures by page"];
  Scan[
    Function[r,
      printFailure[r["Page"] <> " (" <> ToString[r["Failed"]] <> "/" <> ToString[r["Total"]] <> ")"];
      Scan[
        Function[f, Print["    input #", f["InputIndex"], ": ", f["Outcome"]]],
        r["Failures"]
      ]
    ],
    failedPages
  ];
  Quit[1],
  printSuccess[If[totalStale > 0,
    "No failures; " <> ToString[totalStale] <> " of " <> ToString[totalExamples] <> " examples await regeneration of their pages.",
    "All " <> ToString[totalExamples] <> " examples passed."]];
  Quit[0]
]
