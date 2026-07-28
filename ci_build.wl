(* ci_build.wl - Build paclet for CI (no cloud upload) *)

(* Install Runtime Dependencies.

   The container ships no paclets beyond the base image, and declaring a
   dependency in PacletInfo does not install one - it is a statement about
   what the paclet needs, which something has to act on.  Without this the
   kernel files' PackageImport of Wolfram`Arrays` finds no such context and
   every symbol it exports resolves into TensorNetworks' own private context
   instead, undefined: the container tests then fail with $Failed results
   naming Wolfram`TensorNetworks`Utilities`PackagePrivate`ArrayMaterialize. *)
Check[
    PacletInstall["Wolfram/Arrays"],
    Print["FATAL: could not install the Wolfram/Arrays dependency."];
    Exit[1]
];

Needs["Wolfram`Arrays`"];

If[ ! MemberQ[$Packages, "Wolfram`Arrays`"],
    Print["FATAL: Wolfram`Arrays` did not load."];
    Exit[1]
];

PacletDirectoryLoad[FileNameJoin[{Directory[], "TensorNetworks"}]];

name = "TensorNetworks";
paclet = PacletObject["Wolfram/TensorNetworks"];

(* The Rust libraries are already in place: build_all_targets.sh runs
   `cargo wl build` for the host and each cross target, which compiles the
   cdylibs and writes them - together with their generated Functions.wl
   loaders - into TensorNetworks/Binaries/Cotengra-<SystemID>/, where the
   paclet's "Asset" extension picks them up. *)
If[ ! FileExistsQ[FileNameJoin[{paclet["Location"], "Binaries", "Cotengra-" <> $SystemID, "Functions.wl"}]],
    Print["FATAL: no Cotengra library package for ", $SystemID, "; run build_all_targets.sh first."];
    Exit[1]
];

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
