#!/usr/bin/env wolframscript
(* Submit the Wolfram/TensorNetworks paclet to the Wolfram Paclet Repository.

   The submission artifact is TensorNetworks/ResourceDefinition.nb, kept
   beside PacletInfo.wl.  build_docs.wls regenerates it from a repo-root
   ResourceDefinition.md when one exists; otherwise the notebook is edited
   directly.

   Run with:

       wolframscript -f submit.wls
*)

repoDir = DirectoryName[$InputFileName]

nbFile = FileNameJoin[{repoDir, "TensorNetworks", "ResourceDefinition.nb"}]

If[ ! FileExistsQ[nbFile],
    Print["FATAL: ", nbFile, " does not exist."];
    Exit[1]
]

Needs["DefinitionNotebookClient`"]

If[! TrueQ[$CloudConnected], CloudConnect[]]

If[ ! TrueQ[$CloudConnected],
    Print["FATAL: not cloud connected."];
    Exit[1]
]

Print["submitting as ", $WolframID]

(* Two dialogs stand between a headless kernel and a submission: the
   proceed-or-cancel confirmation raised by any outstanding suggestion or
   warning, and, when the repository already holds an earlier version, the
   dialog asking which version this update is.  DialogInput cannot run inside
   kernel initialization, which is where a wolframscript file body runs, so
   both are answered here instead.  The client's override registry loads
   lazily and is empty at this point, so the dialog symbols are Blocked
   directly at the call site below.

   Errors never reach the confirmation: the check below exits on them first,
   so this approves only what a human reading the printed issue list would.
   The version answer is the one the paclet itself declares. *)

version = Get[FileNameJoin[{repoDir, "TensorNetworks", "PacletInfo.wl"}]]["Version"]

If[ ! StringQ[version],
    Print["FATAL: cannot read the version from PacletInfo.wl."];
    Exit[1]
]

Print["version from PacletInfo: ", version]

(* The pre-submission check first: a submission with outstanding errors is
   rejected by the repository anyway, so failing here is strictly cheaper.
   Suggestions (such as PacletFilesChanged after a rebuild) do not block. *)

check = UsingFrontEnd @ Block[{nb, r},
    nb = NotebookOpen[nbFile, Visible -> False];
    r = DefinitionNotebookClient`CheckDefinitionNotebook[nb];
    NotebookClose[nb];
    r
]

issues = Normal[check]

Scan[Print["  [", #Level, "] ", #Tag] &, issues]

If[ MemberQ[issues[[All, "Level"]], "Error"],
    Print["FATAL: the definition notebook has errors; fix them before submitting."];
    Exit[1]
]

result = UsingFrontEnd @ Block[
    {
        nb, r,
        DefinitionNotebookClient`ConfirmIssuesDialog = Function[True],
        DefinitionNotebookClient`SpecifyUpdateVersionDialog = Function[version]
    },
    nb = NotebookOpen[nbFile, Visible -> False];
    r = DefinitionNotebookClient`SubmitRepository[nb];
    NotebookClose[nb];
    r
]

submission = FirstCase[result, _Success, Missing["NotFound"], Infinity]

If[ MatchQ[submission, _Success],
    Print["submitted:"];
    KeyValueMap[Print["  ", #1, ": ", #2] &, KeyDrop[Last[submission], "Message"]],
    Print["SUBMISSION DID NOT SUCCEED:"];
    Print[result];
    Exit[1]
]
