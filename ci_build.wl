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
    FileNameJoin[{paclet["Location"], "Binaries"}]
]

(* Create Paclet Archive *)
Print["Creating Paclet Archive..."];

<< PacletTools`
build = PacletBuild[name]
If[FailureQ[build], Print["Build failed."]; Exit[1]]
pacletFile = build["PacletArchive"]

Print["Paclet created: ", pacletFile];
Print["Size: ", FileSize[pacletFile]];

(* Export version for GitHub Actions *)
version = paclet["Version"];
Print["Exporting version: ", version];
Export["paclet_version.txt", version, "String"];
