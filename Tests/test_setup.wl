(* Tests/test_setup.wl

   Loader shared by test_*.wl files. Resolves the paclet root by walking up
   from the current directory (or $InputFileName when it points at a valid
   file inside Tests/), looking for the PacletInfo.wl marker. This makes the
   test files robust whether they're run by:
     - wolframscript -file Tests/test_xyz.wl directly
     - TestReport["Tests/test_xyz.wl"] from a different cwd
     - The legacy run_tests.wl runner
*)

Module[{candidates, root},
    candidates = DeleteDuplicates @ Join[
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            NestList[ParentDirectory, DirectoryName[$InputFileName], 6],
            {}
        ],
        NestList[ParentDirectory, Directory[], 6]
    ];
    root = SelectFirst[
        candidates,
        DirectoryQ[#] && FileExistsQ[FileNameJoin[{#, "TensorNetworks", "PacletInfo.wl"}]] &,
        $Failed
    ];
    If[root === $Failed,
        Print["[test_setup] ERROR: cannot locate TensorNetworks paclet root from ",
            $InputFileName, " or cwd ", Directory[]];
        Abort[]
    ];
    PacletDirectoryLoad[FileNameJoin[{root, "TensorNetworks"}]];
    Needs["Wolfram`TensorNetworks`"];
    (* PackageScope is a context but not a package, so Needs alone cannot put it
       on $ContextPath and every internal symbol a test names would have to carry
       its full context.  BeginPackage/EndPackage registers it as one; the Block
       keeps the registration from leaking a context path change of its own. *)
    Block[{$ContextPath}, BeginPackage["Wolfram`TensorNetworks`PackageScope`"]; EndPackage[]];
    Needs["Wolfram`TensorNetworks`PackageScope`"];
];
