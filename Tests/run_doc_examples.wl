#!/usr/bin/env wolframscript

(* ============================================================
   Tests/run_doc_examples.wl

   Walks every .nb file under
     Documentation/English/ReferencePages/Symbols/
   extracts every Input cell, evaluates it with a 30-second timeout,
   and reports per-page pass/fail.

   An example passes when it neither times out nor returns $Failed, the
   messages it emits are, by name, the ones stored in the Message cells
   after its Input cell, and its result agrees with the stored Output
   cell (see "Comparison with the stored output" below). Each page
   evaluates in a context of its own, as it would in a fresh kernel.

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

(* Load the Rust library now, so its lazy load does not eat into an example's timeout *)
GreedyContractionPath[{{1}}, {}, <|1 -> 2|>];

(* Netcon C++ LibraryLink is in hibernation per user directive (2026-05-05).
   Pages whose examples invoke Netcon-backed paths are skipped here so the
   harness does not exercise that code path until Netcon comes back online.
   To re-enable: empty this list. *)
$NetconHibernated = {
  "EinsteinSummation",                   (* hangs on Netcon C++ *)
  "TensorNetworkFindContractionPath"     (* deprecated; internally calls Netcon *)
};

(* Optional page filter, a comma-separated list of page names, for local runs *)
$pageFilter = Replace[Environment["TN_DOC_EXAMPLES_PAGES"], {s_String :> StringSplit[s, ","], _ -> All}];

(* Inputs that need a front end, skipped where TN_DOC_EXAMPLES_FRONTEND is 0, as in CI:
   the "Hypergraph" property loads WolframInstitute/Hypergraph, which starts one *)
$frontEndQ = Environment["TN_DOC_EXAMPLES_FRONTEND"] =!= "0";
frontEndBoxQ[box_] := ! $frontEndQ && ! FreeQ[box, s_String /; StringContainsQ[s, "Hypergraph"]]

(* Stale examples, {"Page", input} -> {"Sym::tag", ...}, the exact messages each emits;
   any other outcome, even a pass, fails, so the list cannot go stale *)
$AwaitingRegeneration = <|
  (* the example flattens a contracted network that had a free leg only because RandomTensorNetwork
     dropped a bond; the full network contracts to a scalar *)
  {"CanonicalPath", 21} -> {"Flatten::normal"},
  {"OptimalContractionPath", 64} -> {"Flatten::normal"}
|>;

(* Stale stored outputs, {"Page", input}: the result differs from the stored Output
   cell because the notebook predates a change to the paclet or is itself wrong. Such an example passes as
   "StaleOutput" only while it still differs, so the list cannot go stale either. *)
$StaleOutputs = {
  (* hyperedges are contracted natively (fc52f75): paths no longer carry the steps of a binarizing delta *)
  {"BinaryTensorNetwork", 32}, {"OptimalContractionPath", 67}, {"OptimalContractionPath", 73},
  {"RandomTensorNetwork", 25}, {"TensorNetworkToNetGraph", 12},
  (* from SeedRandom[43], RandomTensorNetwork now draws different MPS tensors than when the page was made *)
  {"MPSOverlap", 31},
  (* the stored $Failed contradicts the example's own text; the guard now returns Missing[...] *)
  {"PartitionQ", 16}, {"PathQ", 20},
  (* the Input cell holds raw boxes inside a RowBox, so g is never assigned *)
  {"TensorNetworkGraphData", 35}, {"TensorNetworkGraphData", 36},
  (* a single leaf gives the empty path, as it has since before 17095ea; the page says {{1}} *)
  {"TreePathToPath", 4},
  (* stored from networks RandomTensorNetwork built with a dropped bond; the full network has
     another contraction order and no free leg *)
  {"CanonicalPath", 7}, {"CanonicalPath", 16},
  Splice[{"GreedyContractionPath", #} & /@ {2, 5, 6, 10, 11, 12, 17, 20, 26, 29, 32, 37, 40, 43}],
  {"PathToTreePath", 14}, {"TreePathToPath", 15}, {"TreePathToPath", 16}
};

(* Outputs, {"Page", input}, that depend on random draws the runner cannot reproduce
   (see "Random examples" below); they are not compared. One that comes to agree
   with its stored output fails until it is removed, and a random output that
   disagrees and is not listed fails, so a wrong result cannot hide here. *)
$UnreproducedRandom = Catenate[Thread /@ {
  {"ActivateTensors", {3, 4, 5}},
  {"MPSNorm", {35}},
  {"MPSOverlap", {11, 36}},
  {"MPSSchmidtValues", {2, 10, 20, 21, 24, 25, 27, 28, 32}},
  {"OptimalContractionPath", {6, 14, 17, 20, 23, 26, 29, 59}},
  {"RandomTensorNetwork", {10, 11, 22}},
  {"TensorNetwork", {3, 12, 14, 15, 44, 53, 66, 122}},
  {"TensorNetworkContract", {46, 49}},
  {"TensorNetworkData", {12, 13}},
  (* single-precision net outputs: their last digits follow the contraction order, which the
     planner's search now chooses in place of the exhaustive optimal one *)
  {"TensorNetworkToNetGraph", {5, 8}}
}];

(* Name "sym::tag" of a message recorded in $MessageList. *)
messageName[HoldForm[MessageName[s_, t_String]]] := SymbolName[Unevaluated[s]] <> "::" <> t
messageName[other_] := ToString[other]

(* Names of the messages a stored Message cell documents: the front end
   writes either a MessageName StyleBox or a MessageTemplate TemplateBox. *)
storedMessageNames[cells_List] := Cases[cells,
  StyleBox[RowBox[{s_String, "::", t_String}], "MessageName", ___] |
    TemplateBox[{s_String, t_String, ___}, "MessageTemplate" | "MessageTemplate2", ___] :> s <> "::" <> t,
  Infinity]

(* The cells stored after the Input cell at position pos, up to the next
   Input cell of the same group. *)
followingCells[nb_, pos_List] :=
  TakeWhile[Drop[Extract[nb, Most[pos]], Last[pos]], ! MatchQ[#, Cell[_, "Input", ___]] &]

documentedMessages[nb_, pos_List] := storedMessageNames @ Cases[followingCells[nb, pos], Cell[_, "Message", ___]]

(* The boxes of the Output cells stored after the Input cell at position pos. *)
storedOutputs[nb_, pos_List] := Cases[followingCells[nb, pos], Cell[BoxData[b_], "Output", ___] :> b]

(* Symbols an example creates live in a context of their own page, so a
   value one page assigns (a, g, chain, ...) never reaches another page. *)
$pageContextPath = DeleteCases[$ContextPath, "Global`"];
pageContext[baseName_String] := "DocExample`" <> baseName <> "`"


(* ---------- Comparison with the stored output ----------

   An Input cell's results that are not Null pair, in order, with the
   Output cells stored after it (a cell with one Output cell but several
   results shows its last; a top-level assignment may have none). % and %%
   refer to the page's earlier results. Each stored output is parsed back to an
   expression in the page's context and evaluated with the page's symbols
   blocked, so a symbol shown unevaluated stays unevaluated. A result
   agrees with it when
     - both are the same expression, or
     - both are numbers or numeric arrays of equal dimensions, one of them
       inexact, and they differ by at most 1e-8 of the larger magnitude in
       the array (plus 1e-12 absolute, for entries that are roundoff on zero),
     - both have the same head and length and agree part by part, or
     - both are exact, contain no lists, strings or rules, and Simplify
       reduces their difference to 0.
   A sparse array compares by its dense form, and MatrixForm, TableForm and
   the padding of a Grid, which the stored boxes do not keep, are ignored.

   Not compared (the example still runs and is checked as before): images
   and graphs, summary boxes, Dataset displays, outputs that do not parse
   or contain an elision, timings, and cells whose count of results differs
   from their count of Output cells. Random examples are handled under
   "Random examples" below. *)

$timingNames = {"Timing", "AbsoluteTiming", "RepeatedTiming", "AbsoluteTime", "SessionTime",
  "Now", "Today", "DateObject", "DateString", "MemoryInUse", "MaxMemoryUsed"};

boxStrings[box_] := Cases[box, s_String, {0, Infinity}]

graphicsBoxQ[box_] := ! FreeQ[box, GraphicsBox | Graphics3DBox | GraphicsComplexBox | RasterBox]
summaryBoxQ[box_] := ! FreeQ[box, "SummaryPanel" | "SummaryHead" | "SummaryItem" | "SummaryItemAnnotation"]
datasetBoxQ[box_] := ! FreeQ[box, "Dataset" | "DatasetBox"]
elidedBoxQ[box_] := ! FreeQ[box, s_String /; StringContainsQ[s, "\[LeftSkeleton]" | "\[RightSkeleton]"]]
graphicsValueQ[held_] := ! FreeQ[held, _Graphics | _Graphics3D | _Graph | _Image | _Legended | _GraphicsGrid | _GraphicsRow | _GraphicsColumn]

(* The stored output box as an expression: HoldComplete[expr] or $Failed. Symbols of
   the page context are blocked while it evaluates. *)
storedExpression[box_, context_String] := Block[{$Messages = {}},
  With[{held = ToExpression[box, StandardForm, HoldComplete]},
    Which[
      Head[held] =!= HoldComplete, $Failed,
      elidedBoxQ[box] || ! FreeQ[held, _Skeleton], "Elided",
      True,
        With[{blocked = Cases[held, s_Symbol /; Context[Unevaluated[s]] === context :> HoldComplete[s], {0, Infinity}, Heads -> True]},
          Replace[
            Join @@ Prepend[DeleteDuplicates[blocked], HoldComplete[]],
            HoldComplete[syms___] :> With[{v = TimeConstrained[Block[{syms}, ReleaseHold[held]], 10, $TimedOut]},
              If[v === $TimedOut, $Failed, HoldComplete[v]]]
          ]
        ]
    ]
  ]
]

numericBlockQ[x_] := NumberQ[x] || ArrayQ[x, _, NumberQ]
inexactQ[x_] := ! FreeQ[x, _?InexactNumberQ]
denseForm[x_] := If[Head[x] === SparseArray, Normal[x], x]
arithmeticQ[x_] := FreeQ[x, _List | _Association | _String | _Rule | _RuleDelayed | _SparseArray] && ! inexactQ[x]

numericCloseQ[a_, b_] := With[{d = Flatten[{a - b}], scale = Max[Abs[Flatten[{a, b}]]]},
  Max[Abs[d]] <= 1*^-8 scale + 1*^-12]

(* Display wrappers that the stored boxes do not keep: a MatrixForm or TableForm
   parses back to its contents, and a ragged Grid back to one padded with Null. *)
displayed[x_] := x /. {
  (MatrixForm | TableForm)[m_, ___] :> m,
  Grid[rows_List, ___] :> Grid[PadRight[rows, Automatic, Null]]}

closeQ[a_, b_] := Which[
  a === b, True,
  Head[a] === SparseArray || Head[b] === SparseArray, closeQ[denseForm[a], denseForm[b]],
  numericBlockQ[a] && numericBlockQ[b],
    Dimensions[a] === Dimensions[b] && (inexactQ[a] || inexactQ[b]) && numericCloseQ[a, b],
  AssociationQ[a] && AssociationQ[b],
    Keys[a] === Keys[b] && closeQ[Values[a], Values[b]],
  ! AtomQ[a] && ! AtomQ[b] && Length[a] === Length[b] && closeQ[Head[a], Head[b]] &&
    AllTrue[Transpose[{List @@ a, List @@ b}], closeQ @@ # &],
    True,
  arithmeticQ[a] && arithmeticQ[b],
    TimeConstrained[Simplify[a - b] === 0, 5, False],
  True, False
]

shortForm[x_] := StringTake[ToString[Unevaluated[x], InputForm], UpTo[160]]

(* Verdict on one stored Output cell paired with the result held in value. *)
compareOutput[box_, value_Hold, inputBox_, context_String] := Which[
  graphicsBoxQ[box] || graphicsValueQ[value], <|"Status" -> "Skip", "Reason" -> "image or graph"|>,
  summaryBoxQ[box], <|"Status" -> "Skip", "Reason" -> "summary box"|>,
  datasetBoxQ[box], <|"Status" -> "Skip", "Reason" -> "Dataset display"|>,
  IntersectingQ[boxStrings[inputBox], $timingNames], <|"Status" -> "Skip", "Reason" -> "timing"|>,
  True, With[{expected = storedExpression[box, context]},
    Which[
      expected === "Elided", <|"Status" -> "Skip", "Reason" -> "elided output"|>,
      expected === $Failed, <|"Status" -> "Skip", "Reason" -> "output does not parse"|>,
      closeQ[displayed[ReleaseHold[value]], displayed[ReleaseHold[expected]]], <|"Status" -> "Match"|>,
      True, <|"Status" -> "Mismatch",
        "Expected" -> Replace[expected, HoldComplete[e_] :> shortForm[e]],
        "Got" -> Replace[value, Hold[v_] :> shortForm[v]]|>
    ]
  ]
]


(* % and %% in an example mean the page's earlier results, as in a notebook;
   $outputHistory holds them, the latest first. *)
$outputHistory = {};
outRules[history_List] := Prepend[
  MapIndexed[With[{k = First[#2], v = First[#1]}, HoldPattern[Out[-k]] :> v] &, history],
  If[history === {}, Nothing, With[{v = First[First[history]]}, HoldPattern[Out[]] :> v]]]

(* Outcome of evaluating one input box. Messages the example emits must be
   among the ones documented after its Input cell. "Value" holds the result. *)
evalInput[box_, documented_List, issueQ_] /; frontEndBoxQ[box] := <|"Outcome" -> "NoFrontEnd", "Messages" -> {}|>

evalInput[box_, documented_List, issueQ_] := Block[{expr, parseMsgs, val, msgs},
  {expr, parseMsgs} = Block[{$MessageList = {}, $Messages = {}},
    {ToExpression[box, StandardForm, HoldComplete], DeleteDuplicates[messageName /@ $MessageList]}
  ];
  If[Head[expr] =!= HoldComplete,
    <|"Outcome" -> "ParseFailed: " <> ToString[parseMsgs], "Messages" -> parseMsgs|>,
    Block[{$MessageList = {}, $Messages = {}},
      val = TimeConstrained[ReleaseHold[expr /. outRules[$outputHistory]], 30, $TimedOut];
      msgs = DeleteDuplicates[messageName /@ $MessageList]
    ];
    If[val =!= Null && val =!= $TimedOut,
      $outputHistory = Take[Prepend[$outputHistory, With[{v = val}, Hold[v]]], UpTo[9]]];
    <|"Outcome" -> Which[
        val === $TimedOut, "Timeout",
        issueQ && val === $Failed, "OK",
        val === $Failed, "Failed",
        ! SubsetQ[documented, msgs],
          "UndocumentedMessage: " <> ToString[Complement[msgs, documented]],
        True, "OK"
      ],
      "Messages" -> msgs,
      "Value" -> With[{v = val}, Hold[v]]|>
  ]
]

(* Random examples. Most stored notebooks were evaluated with the random generator
   seeded with 42 before each Input cell, so a first run seeding the same way
   reproduces their random draws; a few pages were evaluated top to bottom from one
   seed. When a result disagrees with its stored output the page runs three more
   times: seeded per cell with another value, seeded once at the top with 42 (a
   result that then agrees passes), and seeded once at the top with another value.
   A result that changes between the two per-cell runs or between the two top-seeded
   runs depends on random draws; any other disagreement is deterministic and fails. *)
$cellSeed = 42;
$otherSeed = 1729;

(* Outcomes of the boxes of one Input cell, the first of which has page index
   offset + 1. A message stored after the cell that none of its boxes emits is
   reported on the cell's last box. mode gives "CellSeed" (an integer to seed with
   before the cell, or None), "Compare" (All, or the page indices whose stored
   outputs to compare) and "Prior" (page index -> held result of an earlier run, to
   check this run's result against). Comparisons happen right after the cell,
   before later inputs can assign the symbols a result shows. *)
evalCell[{boxes_List, documented_List, issueQ_, outputs_List}, offset_Integer, mode_Association, context_String] := Block[
  {results, valued, records, stable},
  If[IntegerQ[mode["CellSeed"]], SeedRandom[mode["CellSeed"]]];
  results = evalInput[#, documented, issueQ] & /@ boxes;
  results = With[{missing = Complement[documented, Union @@ Lookup[results, "Messages"]]},
    If[missing === {} || Last[results]["Outcome"] =!= "OK" || MemberQ[Lookup[results, "Outcome"], "NoFrontEnd"],
      results,
      Append[Most[results],
        <|Last[results], "Outcome" -> "DocumentedMessageNotEmitted: " <> ToString[missing]|>]
    ]
  ];
  (* indices of the results the front end would print: evaluated and not Null; where
     several are but one Output cell is stored, the cell was evaluated as a whole
     and shows its last result *)
  valued = Flatten[Position[results, r_ /; KeyExistsQ[r, "Value"] && r["Value"] =!= Hold[Null], {1}, Heads -> False]];
  If[Length[outputs] === 1 && Length[valued] > 1 && Last[valued] === Length[results], valued = {Last[valued]}];
  (* some pages store no output for a top-level assignment such as par = {4, 2, 1} *)
  If[Length[valued] > Length[outputs],
    With[{shown = Select[valued, ! MatchQ[ToExpression[boxes[[#]], StandardForm, HoldComplete], HoldComplete[_Set]] &]},
      If[Length[shown] === Length[outputs], valued = shown]]];
  records = Which[
    outputs === {} && valued === {}, {},
    ! AllTrue[results, KeyExistsQ[#, "Value"] &],
      ConstantArray[<|"Status" -> "Skip", "Reason" -> "example did not complete", "Cell" -> offset + Length[results]|>, Length[outputs]],
    Length[valued] =!= Length[outputs],
      ConstantArray[<|"Status" -> "Skip", "Reason" -> "result count differs from Output cells", "Cell" -> offset + Length[results]|>, Length[outputs]],
    True,
      MapThread[
        If[mode["Compare"] === All || MemberQ[mode["Compare"], offset + #1],
          Append[compareOutput[#2, results[[#1]]["Value"], boxes[[#1]], context], "Index" -> offset + #1],
          Nothing] &,
        {valued, outputs}]
  ];
  records = If[mode["Compare"] === All, records, Select[records, KeyExistsQ[#, "Index"] &]];
  stable = Association @ Map[
    With[{k = offset + #}, k -> closeQ[ReleaseHold[mode["Prior"][k]], ReleaseHold[results[[#]]["Value"]]]] &,
    Select[Range[Length[results]], KeyExistsQ[mode["Prior"], offset + #] && KeyExistsQ[results[[#]], "Value"] &]
  ];
  <|"Results" -> KeyDrop[results, "Value"],
    "Records" -> records,
    "Values" -> Association[(#["Index"] -> results[[#["Index"] - offset]]["Value"]) & /@
      Select[records, #["Status"] === "Mismatch" &]],
    "Stable" -> stable|>
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

(* One evaluation of a page's cells in its own context, cleared first. mode is as in
   evalCell, plus "PageSeed", an integer to seed with once before the first cell, or None. *)
runPage[baseName_String, cells_List, mode_Association] := Block[
  {$Context = pageContext[baseName], $ContextPath = $pageContextPath, $outputHistory = {}},
  Block[{$Messages = {}},
    Unprotect[Evaluate[pageContext[baseName] <> "*"]];
    ClearAll[Evaluate[pageContext[baseName] <> "*"]]
  ];
  If[IntegerQ[mode["PageSeed"]], SeedRandom[mode["PageSeed"]]];
  With[{run = MapThread[evalCell[#1, #2, mode, pageContext[baseName]] &,
      {cells, Most[Accumulate[Prepend[Length[First[#]] & /@ cells, 0]]]}]},
    <|"Results" -> Catenate[Lookup[run, "Results"]],
      "Records" -> Catenate[Lookup[run, "Records"]],
      "Values" -> Association[Lookup[run, "Values"]],
      "Stable" -> Association[Lookup[run, "Stable"]]|>
  ]
]

(* Final verdict on a first-run record, given the three further runs of its page. *)
settleRecord[record_Association, page_String, againCell_Association, topRecords_Association, againTop_Association] := With[
  {k = Lookup[record, "Index", None]},
  Which[
    record["Status"] =!= "Mismatch",
      If[MemberQ[$UnreproducedRandom, {page, k}],
        <|record, "Status" -> "ListedButReproduced"|>, record],
    MatchQ[topRecords[k], KeyValuePattern["Status" -> "Match"]],
      If[MemberQ[$UnreproducedRandom, {page, k}],
        <|record, "Status" -> "ListedButReproduced"|>, <|"Status" -> "Match", "Index" -> k|>],
    againCell[k] =!= True || (KeyExistsQ[againTop, k] && againTop[k] =!= True),
      If[MemberQ[$UnreproducedRandom, {page, k}],
        <|"Status" -> "Skip", "Reason" -> "random, not reproduced (listed)", "Index" -> k|>,
        <|record, "Status" -> "RandomMismatch"|>],
    True, record
  ]
]

(* Per-page evaluator *)
evalPage[nbPath_String] := Block[
  {
    nb = Get[nbPath],
    positions, cells, issueGroups, first, records, mismatched, againCell, top, againTop,
    failures, outcomes, staleIdx, baseName = FileBaseName[nbPath]
  },
  If[Head[nb] =!= Notebook,
    Return[<|"Page" -> baseName, "Total" -> 0, "Failed" -> 0, "Skipped" -> True|>]
  ];
  (* Every Input cell as {boxes, documented message names, issueQ, stored output
     boxes}. Cells under a "Possible Issues" section document a call that fails, so
     $Failed there is the expected outcome; their messages are still checked whenever
     they return anything else. Position and Cases traverse the notebook in the same order. *)
  positions = Position[nb, Cell[BoxData[_], "Input", ___]];
  issueGroups = Position[nb,
    CellGroupData[{Cell[head_, "ExampleSection", ___] /; ! FreeQ[head, "Possible Issues"], ___}, ___]];
  cells = MapThread[
    {If[MatchQ[#2, _List], #2, {#2}],
     documentedMessages[nb, #1],
     AnyTrue[issueGroups, Function[g, Take[#1, UpTo[Length[g]]] === g]],
     storedOutputs[nb, #1]} &,
    {positions, Cases[nb, Cell[BoxData[box_], "Input", ___] :> box, Infinity]}
  ];
  first = runPage[baseName, cells, <|"CellSeed" -> $cellSeed, "PageSeed" -> None, "Compare" -> All, "Prior" -> <||>|>];
  records = first["Records"];
  mismatched = Keys[first["Values"]];
  {againCell, top, againTop} = If[mismatched === {}, {<||>, <||>, <||>},
    With[{
        cellRun = runPage[baseName, cells, <|"CellSeed" -> $otherSeed, "PageSeed" -> None, "Compare" -> {}, "Prior" -> first["Values"]|>],
        topRun = runPage[baseName, cells, <|"CellSeed" -> None, "PageSeed" -> $cellSeed, "Compare" -> mismatched, "Prior" -> <||>|>]},
      {cellRun["Stable"],
       Association[#["Index"] -> # & /@ topRun["Records"]],
       If[topRun["Values"] === <||>, <||>,
         runPage[baseName, cells, <|"CellSeed" -> None, "PageSeed" -> $otherSeed, "Compare" -> {}, "Prior" -> topRun["Values"]|>]["Stable"]]}
    ]
  ];
  records = settleRecord[#, baseName, againCell, top, againTop] & /@ records;
  outcomes = MapIndexed[applyRegeneration[baseName, First[#2], #1] &, first["Results"]];
  (* a disagreement fails the example unless it already failed or is listed as stale *)
  outcomes = Fold[
    Function[{acc, rec}, If[MemberQ[{"Mismatch", "RandomMismatch", "ListedButReproduced"}, rec["Status"]],
      ReplacePart[acc, rec["Index"] -> Which[
        rec["Status"] === "ListedButReproduced",
          "ListedAsUnreproducedButReproduced: remove it from $UnreproducedRandom",
        rec["Status"] === "Mismatch" && MemberQ[$StaleOutputs, {baseName, rec["Index"]}], "StaleOutput",
        acc[[rec["Index"]]] =!= "OK", acc[[rec["Index"]]],
        rec["Status"] === "RandomMismatch",
          "RandomOutputMismatch (random draws not reproduced, and not listed in $UnreproducedRandom): expected " <>
            rec["Expected"] <> ", got " <> rec["Got"],
        True, "OutputMismatch: expected " <> rec["Expected"] <> ", got " <> rec["Got"]]],
      acc]],
    outcomes, records];
  staleIdx = Cases[$StaleOutputs, {baseName, i_} :> i];
  outcomes = MapIndexed[
    If[MemberQ[staleIdx, First[#2]] && #1 =!= "StaleOutput",
      "StaleOutputListedButAgrees: " <> #1, #1] &, outcomes];
  failures = MapIndexed[
    Function[{outcome, idx},
      If[MatchQ[outcome, "OK" | "Regenerate" | "NoFrontEnd" | "StaleOutput"], Nothing,
        <|"InputIndex" -> idx[[1]], "Outcome" -> outcome|>]
    ],
    outcomes
  ];
  <|"Page" -> baseName,
    "Total" -> Length[outcomes],
    "Failed" -> Length[failures],
    "Failures" -> failures,
    "Regenerate" -> Flatten[Position[outcomes, "Regenerate"]],
    "StaleOutput" -> Flatten[Position[outcomes, "StaleOutput"]],
    "NoFrontEnd" -> Count[outcomes, "NoFrontEnd"],
    "Outputs" -> Length[records],
    "Matched" -> Count[records, KeyValuePattern["Status" -> "Match"]],
    "Mismatched" -> Count[records, KeyValuePattern["Status" -> "Mismatch" | "RandomMismatch" | "ListedButReproduced"]],
    "SkipRecords" -> Cases[records, KeyValuePattern["Status" -> "Skip"]],
    "SkipReasons" -> Counts[Cases[records, KeyValuePattern[{"Status" -> "Skip", "Reason" -> r_}] :> r]],
    "Skipped" -> False|>
];

(* Run *)
nbFiles = FileNames["*.nb", docsDir];
nbFiles = Select[nbFiles, ! MemberQ[$NetconHibernated, FileBaseName[#]] &];
If[$pageFilter =!= All, nbFiles = Select[nbFiles, MemberQ[$pageFilter, FileBaseName[#]] &]];
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
staleOutPages = Select[reports, Length[Lookup[#, "StaleOutput", {}]] > 0 &];
totalStaleOut = Total[Length[Lookup[#, "StaleOutput", {}]] & /@ reports];
totalNoFE     = Total[Lookup[#, "NoFrontEnd", 0] & /@ reports];
totalOutputs  = Total[Lookup[reports, "Outputs", 0]];
totalMatched  = Total[Lookup[reports, "Matched", 0]];
totalMismatch = Total[Lookup[reports, "Mismatched", 0]];
skipReasons   = Merge[Lookup[reports, "SkipReasons", <||>], Total];

Print[""];
printHeader["Summary"];
Print[bold, "  Pages:     ", totalPages, reset];
Print[bold, "  Examples:  ", totalExamples, reset];
Print[green, "  Passed:    ", totalExamples - totalFailed - totalStale - totalNoFE - totalStaleOut, reset];
If[totalNoFE > 0, Print[yellow, "  Skipped:   ", totalNoFE, " (need a front end)", reset]];
If[totalStale > 0,
  Print[yellow, "  Awaiting regeneration: ", totalStale, " (documented message missing from the stored notebook)", reset];
  Scan[Print[yellow, "    ", #["Page"], " inputs ", #["Regenerate"], reset] &, stalePages]
];
If[totalStaleOut > 0,
  Print[yellow, "  Stale stored outputs: ", totalStaleOut, " (listed in $StaleOutputs)", reset];
  Scan[Print[yellow, "    ", #["Page"], " inputs ", #["StaleOutput"], reset] &, staleOutPages]
];
If[skipped > 0, Print[yellow, "  Skipped:   ", skipped, " (notebook parse failed)", reset]];
Print[bold, "  Stored outputs: ", totalOutputs, reset];
Print[green, "    compared and agree: ", totalMatched, reset];
If[totalMismatch - totalStaleOut > 0, Print[red, "    compared and differ: ", totalMismatch - totalStaleOut, reset]];
If[totalStaleOut > 0, Print[yellow, "    compared and differ, stored output stale (listed): ", totalStaleOut, reset]];
KeyValueMap[Print[yellow, "    not compared, ", #1, ": ", #2, reset] &, ReverseSort[skipReasons]];
(* TN_DOC_EXAMPLES_VERBOSE=1 lists every result that was not compared, by page and input *)
If[Environment["TN_DOC_EXAMPLES_VERBOSE"] === "1",
  Scan[Function[r, Scan[Print["    ", r["Page"], " input #", Lookup[#, "Index", #["Cell"]], ": ", #["Reason"]] &,
    Lookup[r, "SkipRecords", {}]]], reports]];

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
  printSuccess[Which[
    totalStale > 0,
      "No failures; " <> ToString[totalStale] <> " of " <> ToString[totalExamples] <> " examples await regeneration of their pages.",
    totalNoFE > 0,
      "No failures; " <> ToString[totalNoFE] <> " of " <> ToString[totalExamples] <> " examples skipped for want of a front end.",
    True,
      "All " <> ToString[totalExamples] <> " examples passed."]];
  Quit[0]
]
