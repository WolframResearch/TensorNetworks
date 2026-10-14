#!/usr/bin/env wolframscript
(* Submit Wolfram/TensorNetworks to the Paclet Repository: wolframscript -f submit.wls
   Artifact: TensorNetworks/ResourceDefinition.nb (build_docs.wls regenerates it from ResourceDefinition.md) *)

repoDir = DirectoryName[$InputFileName]

nbFile = FileNameJoin[{repoDir, "TensorNetworks", "ResourceDefinition.nb"}]

If[ ! FileExistsQ[nbFile],
    Print["FATAL: ", nbFile, " does not exist."];
    Exit[1]
]

Needs["DefinitionNotebookClient`"]

(* The notebook scrape calls PacletTools`PacletExtensionFiles; unloaded, it leaves a
   Failure the repository refuses as "disallowed symbols: {System`Failure}" *)
Needs["PacletTools`"]

(* Print API errors the client reduces to "Unknown error"; the condition always fails *)
Needs["ResourceSystemClient`"]

ResourceSystemClient`Private`handleError[head_, endpoint_, code_, chars_, params_, rbase_] /; (
    Print["API error ", code, " from ", endpoint, ": ",
        StringTake[Quiet @ Check[FromCharacterCode[chars], ToString[chars]], UpTo[1500]]];
    False
) := Null

(* CI passes the account in the environment; otherwise use the stored login *)

submitUser = Environment["WOLFRAM_CLOUD_USER"]

If[ StringQ[submitUser] && StringQ[Environment["WOLFRAM_CLOUD_PASSWORD"]],
    Quiet @ CloudConnect[submitUser, Environment["WOLFRAM_CLOUD_PASSWORD"]];
    If[ $WolframID =!= submitUser,
        Print["FATAL: could not connect as ", submitUser, " from WOLFRAM_CLOUD_USER."];
        Exit[1]
    ],
    If[! TrueQ[$CloudConnected], CloudConnect[]]
]

If[ ! TrueQ[$CloudConnected],
    Print["FATAL: not cloud connected."];
    Exit[1]
]

(* The repository checks the PublisherID against $PublisherID, unset in a fresh kernel;
   without it the submission fails with ResourceObject::apierr (ConfirmationFailed) *)

publisher = Get[FileNameJoin[{repoDir, "TensorNetworks", "PacletInfo.wl"}]]["PublisherID"]

If[ ! StringQ[publisher],
    Print["FATAL: cannot read the PublisherID from PacletInfo.wl."];
    Exit[1]
]

$PublisherID = publisher

Print["submitting as ", $WolframID, " for publisher ", $PublisherID]

(* Headless: answer the proceed and update-version dialogs here, Blocked at the call site
   (the client's override registry loads lazily). Errors exit earlier; version from PacletInfo. *)

version = Get[FileNameJoin[{repoDir, "TensorNetworks", "PacletInfo.wl"}]]["Version"]

If[ ! StringQ[version],
    Print["FATAL: cannot read the version from PacletInfo.wl."];
    Exit[1]
]

Print["version from PacletInfo: ", version]

(* Check first: errors would be rejected anyway; suggestions don't block *)

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
