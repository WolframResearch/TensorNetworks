#!/usr/bin/env wolframscript
(* Build the documentation notebooks from the markdown in docs/ with PacletPage's
   BuildPacletDocumentation: wolframscript -f build_docs.wls [docs/....md ...]
   Needs a front end, so it runs locally; CI runs the pages' examples instead *)

repo = DirectoryName[ExpandFileName[$InputFileName]]

(* PacletPage's public paclet resource; it converts with MarkdownToNotebook's public deployment,
   which installs Wolfram/Parser for LaTeX itself *)
pacletPage = ResourceObject["https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/PacletPage"]

If[ FailureQ[PacletInstall[pacletPage]] || FailureQ[PacletInstall["Wolfram/Arrays"]],
    Print["FATAL: cannot install PacletPage or Wolfram/Arrays"]; Exit[1]
]
Needs["WolframInstitute`PacletPage`"]

files = ExpandFileName /@ Rest[$ScriptCommandLine]

result = BuildPacletDocumentation[FileNameJoin[{repo, "TensorNetworks"}],
    "Source" -> FileNameJoin[{repo, "docs"}],
    (* the committed ResourceDefinition.nb is the definition *)
    "Definition" -> None,
    "Files" -> If[files === {}, All, files],
    (* code the examples run, part of their cache key *)
    "Dependencies" -> {"Wolfram/Arrays"}
]

If[ ! AssociationQ[result] || result["Failed"] =!= {},
    Print["FATAL: pages did not convert: ", If[AssociationQ[result], result["Failed"], result]];
    Exit[1]
]

Print["done: ", Short[KeyDrop[result, "Failed"], 3]]
