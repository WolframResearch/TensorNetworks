(* ci_build.wl - Build paclet for CI (no cloud upload) *)

(* The version floor is asserted here as well as declared in PacletInfo, because
   nothing enforces "Dependencies" at load time: an older Wolfram/Arrays loads
   without complaint and then answers three shape questions the IndexArray
   subcontext depends on with a quietly wrong result - the gradient of a rank-0
   operand under Inactive[D], the shape of a list whose leaves are symbolic
   containers, and a structural node over operands of symbolic size, such as
   the transpose of an n x m ArraySymbol.  None of them raises a message, so
   without this the build goes green and the paclet ships broken.

   The comparison is done on PARSED version numbers, deliberately, and not by
   either of the two shorter spellings that look right and are not.
   PacletFind["Wolfram/Arrays", "Version" -> "99.9.9+"] returns the installed
   1.3.3 - the range is not applied as a filter, so that check can never fail -
   and comparing the version STRINGS orders 1.10.0 before 1.3.3. *)
requiredArraysVersion = "1.4.2";

versionNumbers[v_String] := Replace[
    Quiet @ Check[ToExpression /@ StringSplit[v, "."], $Failed],
    Except[{___Integer}] :> {0}
];
versionNumbers[_] := {0};

arraysCurrentQ[] := OrderedQ[{versionNumbers[requiredArraysVersion], versionNumbers[PacletObject["Wolfram/Arrays"]["Version"]]}];

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

(* The paclet site can lag the Paclet Repository by days: two days after
   Arrays 1.4.2 was published it still served 1.4.0.  When what it installed
   is older than the floor, the release is installed from its repository
   resource, which is current at once. *)
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
