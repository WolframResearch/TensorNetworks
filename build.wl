#!/usr/bin/env wolframscript

pub = "Wolfram"
name = "TensorNetworks"

PacletDirectoryLoad[name]
paclet = PacletObject[StringTemplate["``/``"][pub, name]]

(* Build the host Rust library with cargo-wl (WolframResearch/
   wolfram-rust-library): it compiles the Cotengra cdylib and writes it,
   together with its generated Functions.wl loader, into
   TensorNetworks/Binaries/Cotengra-<SystemID>/ per the
   [package.metadata.wl.pacletinfo] table in Cotengra/Cargo.toml. *)
run = RunProcess[
    {"cargo", "wl", "build", "--release"},
    ProcessDirectory -> FileNameJoin[{paclet["Location"], "Cotengra"}]
]
If[ ! MatchQ[run, KeyValuePattern["ExitCode" -> 0]],
    Print["cargo wl build failed: ", run];
    Exit[1]
]

<< PacletTools`

build = PacletBuild[name]
If[FailureQ[build], Print["Build failed."]; Exit[1]]
pacletFile = build["PacletArchive"]

Echo[StringTemplate["Paclet `` has size ``"][pacletFile, FileSize[pacletFile]]]

PacletDirectoryUnload[name]

PacletInstall[pacletFile, ForceVersionInstall -> True]

CopyFile[pacletFile, CloudObject[name <> ".paclet", Permissions -> "Public"], OverwriteTarget -> True]
