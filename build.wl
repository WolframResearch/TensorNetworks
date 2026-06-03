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
CargoCollect[Directory[], FileNameJoin[paclet["Location"], "Binaries"]]

<< PacletTools`

(* The "Cargo" (Root -> Cotengra) and "Build" (Actions -> {CargoBuild})
   extensions both enumerate Cotengra/Cargo.toml and Cotengra/src/lib.rs.
   PacletBuild copies the first set successfully and then aborts on
   CopyFile::eexist when the second extension tries to copy the same
   files. Override only the "Build" extension's Build handler with a
   no-op so the Cargo extension is the sole copier of the source files;
   keep the other operations (Files, DefaultRoot, ...) at their default
   so PacletBuild can still enumerate them. *)
build = PacletBuild[name,
    PacletTools`PacletExtensionHandlers -> Append[
        PacletTools`$PacletExtensionHandlers,
        "Build" -> <|
            "DefaultRoot" -> Automatic,
            "AllowedAtPacletRoot" -> False,
            "Files" -> Automatic,
            "Build" -> (Null &)
        |>
    ]
]
If[FailureQ[build], Print["Build failed."]; Exit[1]]
pacletFile = build["PacletArchive"]

Echo[StringTemplate["Paclet `` has size ``"][pacletFile, FileSize[pacletFile]]]

PacletDirectoryUnload[name]

PacletInstall[pacletFile, ForceVersionInstall -> True]

CopyFile[pacletFile, CloudObject[name <> ".paclet", Permissions -> "Public"], OverwriteTarget -> True]