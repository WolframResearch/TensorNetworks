#!/usr/bin/env wolframscript

(* PacletInstall["https://www.wolframcloud.com/obj/nikm/ExternalEvaluate.paclet", ForceVersionInstall -> True]
PacletInstall["https://www.wolframcloud.com/obj/nikm/PacletExtensions.paclet", ForceVersionInstall -> True] *)

<< ExtensionCargo`
<< ExtensionBuild`

pub = "Wolfram"
name = "TensorNetworks"

PacletDirectoryLoad[name]
paclet = PacletObject[StringTemplate["``/``"][pub, name]]

(* Pass workspace root explicitly so CargoCollect sees the workspace
   target/ at the repo root (not <paclet>/Cotengra/target/, which
   doesn't exist when cargo uses its default target dir). *)
CargoCollect[Directory[], FileNameJoin[{paclet["Location"], "Binaries"}]]

<< PacletTools`
build = PacletBuild[name]
If[FailureQ[build], Print["Build failed."]; Exit[1]]
pacletFile = build["PacletArchive"]

Echo[StringTemplate["Paclet `` has size ``"][pacletFile, FileSize[pacletFile]]]

PacletDirectoryUnload[name]

PacletInstall[pacletFile, ForceVersionInstall -> True]

(* CopyFile[pacletFile, CloudObject[name <> ".paclet", Permissions -> "Public"], OverwriteTarget -> True] *)