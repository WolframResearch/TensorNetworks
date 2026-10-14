(* ci_build.wl - Build paclet for CI (no cloud upload) *)

(* PacletInfo's floor isn't enforced, and an older Arrays gives silently wrong shapes.
   Compare parsed numbers: strings sort 1.10.0 before 1.3.3, PacletFind ignores ranges. *)
requiredArraysVersion = "1.4.2";

versionNumbers[v_String] := Replace[
    Quiet @ Check[ToExpression /@ StringSplit[v, "."], $Failed],
    Except[{___Integer}] :> {0}
];
versionNumbers[_] := {0};

arraysCurrentQ[] := OrderedQ[{versionNumbers[requiredArraysVersion], versionNumbers[PacletObject["Wolfram/Arrays"]["Version"]]}];

(* Install Runtime Dependencies: PacletInfo declares Arrays but nothing installs it *)
Check[
    PacletInstall["Wolfram/Arrays"],
    Print["FATAL: could not install the Wolfram/Arrays dependency."];
    Exit[1]
];

(* The paclet site can lag the repository by days; fall back to the resource *)
If[ ! arraysCurrentQ[],
    Print["Wolfram/Arrays ", PacletObject["Wolfram/Arrays"]["Version"], " from the paclet site is older than ",
        requiredArraysVersion, "; installing from its repository resource."];
    Quiet @ PacletInstall[ResourceObject["Wolfram/Arrays"]]
];

Needs["Wolfram`Arrays`"];

If[ ! MemberQ[$Packages, "Wolfram`Arrays`"],
    Print["FATAL: Wolfram`Arrays` did not load."];
    Exit[1]
];

If[ ! arraysCurrentQ[],
    Print[
        "FATAL: Wolfram/Arrays ", PacletObject["Wolfram/Arrays"]["Version"],
        " is older than the required ", requiredArraysVersion, "."
    ];
    Exit[1]
];

PacletDirectoryLoad[FileNameJoin[{Directory[], "TensorNetworks"}]];

name = "TensorNetworks";
paclet = PacletObject["Wolfram/TensorNetworks"];

(* Cotengra libraries are prebuilt by build_all_targets.sh *)
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
