#!/usr/bin/env wolframscript
(* Build the TensorNetworks paclet documentation from the structured markdown
   in docs/, writing each notebook into the standard paclet layout under
   Documentation/English/. Modeled on AccessibleColors/build.wls
   (https://github.com/sw1sh/AccessibleColors/blob/main/build.wls). *)

print[args___] := WriteString["stdout", StringJoin[ToString /@ {args}], "\n"]

pacletDir = DirectoryName[ExpandFileName[If[$InputFileName === "", NotebookFileName[], $InputFileName]]]

(* MarkdownToNotebook is not on the public Function Repository yet, so use
   its public cloud deployment. *)
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]]

(* load the paclet so example cells resolve its symbols during evaluation *)
PacletDirectoryLoad[FileNameJoin[{pacletDir, "TensorNetworks"}]]
Needs["Wolfram`TensorNetworks`"]
Needs["Wolfram`TensorNetworks`IndexArray`"]
Needs["Wolfram`TensorNetworks`Symmetry`"]

subdir["Symbol"] = {"Documentation", "English", "ReferencePages", "Symbols"}
subdir["Guide"] = {"Documentation", "English", "Guides"}
subdir["TechNote"] = {"Documentation", "English", "Tutorials"}

buildDoc[srcFile_String] := Block[{info, tmpl, name, dir, out},
    info = mtn[srcFile, "Association"];
    tmpl = info["Template"];
    name = info["Metadata"]["Name"];
    If[ Head[subdir[tmpl]] === subdir,
        print["  [skip] ", FileNameTake[srcFile], " - unknown Template: ", tmpl];
        Return[Null]
    ];
    dir = FileNameJoin[Prepend[subdir[tmpl], FileNameJoin[{pacletDir, "TensorNetworks"}]]];
    Quiet @ CreateDirectory[dir, CreateIntermediateDirectories -> True];
    out = FileNameJoin[{dir, name <> ".nb"}];
    mtn[srcFile, out];
    print["  ", FileNameTake[srcFile], " -> TensorNetworks/", FileNameJoin[subdir[tmpl]], "/", name, ".nb"]
]

print["building TensorNetworks documentation"]
Scan[buildDoc, Sort @ FileNames["*.md", FileNameJoin[{pacletDir, "docs"}], Infinity]]

(* paclet-repository submission notebook at the paclet root *)
rd = FileNameJoin[{pacletDir, "ResourceDefinition.md"}]
If[ FileExistsQ[rd],
    mtn[rd, FileNameJoin[{pacletDir, "TensorNetworks", "ResourceDefinition.nb"}]];
    print["  ResourceDefinition.md -> TensorNetworks/ResourceDefinition.nb"]
]

print["done"]
