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

(* PacletTools has to be loaded before the definition notebook is scraped: the
   scrape lists the files of the Documentation extension through
   PacletTools`PacletExtensionFiles, and with the context not loaded that call
   stays unevaluated, a Failure lands in the file listing, and the repository
   refuses the request ("The content of the request contains disallowed
   symbols: {System`Failure}"). *)
Needs["PacletTools`"]

(* The client turns any server response it cannot parse into "Unknown error",
   so the status and body of every error response are printed first; the
   condition always fails, and the client's own handling then runs as before. *)
Needs["ResourceSystemClient`"]

ResourceSystemClient`Private`handleError[head_, endpoint_, code_, chars_, params_, rbase_] /; (
    Print["API error ", code, " from ", endpoint, ": ",
        StringTake[Quiet @ Check[FromCharacterCode[chars], ToString[chars]], UpTo[1500]]];
    False
) := Null

(* The account to submit from: WOLFRAM_CLOUD_USER and WOLFRAM_CLOUD_PASSWORD,
   where both are set, as a CI job would be given them; otherwise the stored
   login.  The password is read from the environment and never printed. *)

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

(* The paclet is published under its PublisherID, "Wolfram", and the
   repository checks that against $PublisherID, which is unset in a fresh
   kernel: without it every client-side check passes and the submission is
   then refused with ResourceObject::apierr ("An unexpected internal error
   occurred (ConfirmationFailed)"). *)

publisher = Get[FileNameJoin[{repoDir, "TensorNetworks", "PacletInfo.wl"}]]["PublisherID"]

If[ ! StringQ[publisher],
    Print["FATAL: cannot read the PublisherID from PacletInfo.wl."];
    Exit[1]
]

$PublisherID = publisher

Print["submitting as ", $WolframID, " for publisher ", $PublisherID]

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
