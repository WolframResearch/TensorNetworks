(* ci_build.wl - Build paclet for CI (no cloud upload) *)

(* Install Build Dependencies *)
PacletInstall["https://www.wolframcloud.com/obj/nikm/ExternalEvaluate.paclet"];
PacletInstall["https://www.wolframcloud.com/obj/nikm/PacletExtensions.paclet"];

PacletDirectoryLoad[FileNameJoin[{Directory[], "TensorNetworks"}]];

Needs["ExtensionCargo`"];

name = "TensorNetworks";
paclet = PacletObject["Wolfram/TensorNetworks"];

(* CargoCollect - collects binaries built by build_all_targets.sh.
   The paclet's "Cargo" extension Root points at TensorNetworks/Cotengra,
   but cargo workspace artifacts live at <workspace-root>/target/, so
   the default invocation would only find the host's native build.
   Pass the workspace root as the source and the paclet's Binaries dir
   as the destination so all 5 cross-built libraries are manifested
   without polluting the paclet tree with target/. *)
Print["Running CargoCollect..."];
ExtensionCargo`CargoCollect[
    Directory[],
    FileNameJoin[paclet["Location"], "Binaries"]
]

(* Create Paclet Archive *)
Print["Creating Paclet Archive..."];

<< PacletTools`

(* The "Cargo" (Root -> Cotengra) and "Build" (Actions -> {CargoBuild})
   extensions both enumerate Cotengra/Cargo.toml and Cotengra/src/lib.rs.
   PacletBuild copies them once for the Cargo extension and then aborts
   on CopyFile::eexist when the Build extension tries to copy the same
   files. Override only the "Build" extension's Build handler with a
   no-op so the Cargo extension stays the sole copier; keep the other
   operations (Files, DefaultRoot, ...) at their default so PacletBuild
   can still enumerate files. *)
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

Print["Paclet created: ", pacletFile];
Print["Size: ", FileSize[pacletFile]];

(* Export version for GitHub Actions *)
version = paclet["Version"];
Print["Exporting version: ", version];
Export["paclet_version.txt", version, "String"];
