(* Usage and message text of the paclet outside the IndexArray sub-context: no em dashes, and
   no box code shown as literal text (a StyleBox outside a \!\(...\) segment) *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

usKernel = FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "TensorNetworks", "Kernel"}];

usFiles = Select[FileNames["*.wl", usKernel, Infinity], ! StringContainsQ[#, "IndexArray"] &];

(* the source text with every \!\(...\) segment removed *)
usOutsideBoxes[text_String] := StringDelete[text, "\\!\\(" ~~ Shortest[___] ~~ "\\)"];

(* files containing an em dash, written or as \[LongDash] *)
VerificationTest[
    Select[usFiles, StringContainsQ[ReadString[#], "\[LongDash]" | "\\[LongDash]"] &],
    {},
    TestID -> "Usage_NoEmDashes"
]

(* usage files whose text shows a StyleBox outside a box segment *)
VerificationTest[
    Select[usFiles, StringEndsQ[#, "Usage.wl"] && StringContainsQ[usOutsideBoxes[ReadString[#]], "StyleBox["] &],
    {},
    TestID -> "Usage_NoLiteralBoxCode"
]

(* the one-argument contraction usage describes both results *)
VerificationTest[
    StringContainsQ[TensorNetworkContraction::usage, "Einstein summation"] && StringContainsQ[TensorNetworkContraction::usage, "contracted array"],
    True,
    TestID -> "Usage_TensorNetworkContractionDescribesResults"
]
