#!/usr/bin/env wolframscript

(* Tests/external_validation/run_external_validation.wl

Master runner for the external-validation test suite. Iterates over two groups:

  paclet_primitives/  - tests that genuinely exercise paclet symbols
                        (TensorNetwork, OptimalContractionPath, EinsteinSummation,
                         MPSCanonicalForm, MPSOverlap, etc.)
  baselines/          - Mathematica-native sanity checks against catalogued
                        analytic answers (no paclet calls). These document that
                        the catalog values are reachable; they are NOT paclet
                        regression tests.

Aggregates outcomes across all files and writes SKIPPED_AND_MISSING.md.

Outcome classes:
  Pass         - assertion held
  Failure      - assertion violated (numeric mismatch or wrong value)
  SkipRNG      - RNG-dependence cannot be reproduced cross-language
  SkipMissing  - paclet lacks a required symbol/feature
  Error        - unexpected exception (a bug, distinct from feature gap)
*)

red = "\033[0;31m"; green = "\033[0;32m"; yellow = "\033[0;33m"; blue = "\033[0;34m";
bold = "\033[1m"; dim = "\033[2m"; reset = "\033[0m";

$ValidationRoot = SelectFirst[
    NestList[ParentDirectory, Directory[], 8],
    DirectoryQ[#] && FileExistsQ[FileNameJoin[{#, "TensorNetworks", "PacletInfo.wl"}]] &,
    Directory[]
];

$ValidationDir = FileNameJoin[{$ValidationRoot, "Tests", "external_validation"}];
Get[FileNameJoin[{$ValidationDir, "Helpers", "ValidationHelpers.wl"}]];

$AllRNGSkipped = <||>;
$AllMissingSkipped = <||>;
$AllErrors = <||>;
$AllFailures = <||>;
$AllSucceeded = <||>;

testGroups = {
    "paclet_primitives" -> {
        (* Tier-1 *)
        "tensor_algebra.wl",
        "contraction_paths.wl",
        "tn_expectations.wl",
        "mps.wl",
        (* Tier-2: direct external-value comparisons *)
        "cotengra_benchmarks.wl",
        "tn_canonical_states.wl",
        "mps_canonical_states.wl"
    },
    "baselines" -> {
        "decomposition.wl",
        "analytic_grounds.wl",
        "gate_identities.wl",
        "state_expectations.wl"
    }
};

padR[s_, n_] := StringPadRight[ToString[s], n];
padL[s_, n_] := StringPadLeft[ToString[s], n];

$GroupRows = <||>;

Do[
    Module[{groupName, groupFiles, dirPath, rows = {}},
        groupName = First[group]; groupFiles = Last[group];
        dirPath = FileNameJoin[{$ValidationDir, groupName}];
        Print[bold, blue, "==> ", groupName, "/", reset];

        Do[
            Module[{file, fullPath, report, results, succeeded, failed,
                    fileRNG, fileMissing, fileErrors, label, succColor},
                file = groupFiles[[k]];
                label = StringDrop[file, -3];  (* strip .wl *)
                fullPath = FileNameJoin[{dirPath, file}];

                Print["  ", bold, file, reset];
                (* PacletDirectoryLoad shifts Directory[]; restore worktree root
                   before each TestReport so each tier file's loader resolves
                   Directory[]-relative paths correctly. *)
                SetDirectory[$ValidationRoot];
                report = TestReport[fullPath];
                results = report["TestResults"];

                succeeded = Select[Values[results], #["Outcome"] === "Success" &];
                failed = Select[Values[results], #["Outcome"] === "Failure" &];

                fileRNG = $ValidationRNGSkipped;
                fileMissing = $ValidationMissingSkipped;
                fileErrors = $ValidationErrors;

                AssociateTo[$AllRNGSkipped, Normal[fileRNG]];
                AssociateTo[$AllMissingSkipped, Normal[fileMissing]];
                AssociateTo[$AllErrors, Normal[fileErrors]];
                Scan[(AssociateTo[$AllSucceeded, #["TestID"] -> True]) &, succeeded];
                Scan[(AssociateTo[$AllFailures,
                    #["TestID"] -> <|
                        "expected" -> ToString[#["ExpectedOutput"]],
                        "actual" -> ToString[Short[#["ActualOutput"], 200]]
                    |>]) &, failed];

                succColor = If[Length[failed] === 0, green, red];
                Print["      ", green, "passed: ", Length[succeeded], reset,
                      "  ", succColor, "failed: ", Length[failed], reset,
                      "  ", yellow, "skip-rng: ", Length[fileRNG], reset,
                      "  ", yellow, "skip-missing: ", Length[fileMissing], reset,
                      "  ", red, "errors: ", Length[fileErrors], reset];

                Scan[Function[v,
                    Print["        ", red, "FAIL ", v["TestID"], reset];
                    Print["          expected: ", v["ExpectedOutput"]];
                    Print["          actual:   ", Short[v["ActualOutput"], 100]];
                ], failed];

                AppendTo[rows, {
                    label,
                    Length[succeeded], Length[failed],
                    Length[fileRNG], Length[fileMissing], Length[fileErrors]
                }];
            ],
            {k, Length[groupFiles]}
        ];

        AssociateTo[$GroupRows, groupName -> rows];
    ],
    {group, testGroups}
];

Print[""];
Print[bold, blue, "==> Coverage matrix", reset];
Module[{groupTotals = <||>, grandPass = 0, grandFail = 0, grandRNG = 0, grandMiss = 0, grandErr = 0},
    Do[
        Module[{groupName, rows, gp, gf, gr, gm, ge},
            groupName = First[group];
            rows = $GroupRows[groupName];
            gp = Total[rows[[All, 2]]]; gf = Total[rows[[All, 3]]];
            gr = Total[rows[[All, 4]]]; gm = Total[rows[[All, 5]]];
            ge = Total[rows[[All, 6]]];
            grandPass += gp; grandFail += gf; grandRNG += gr;
            grandMiss += gm; grandErr += ge;
            Print[""];
            Print[bold, "  [", groupName, "]", reset];
            Print[bold, "  ", padR["File", 24], padL["Pass", 6], "  ",
                padL["Fail", 6], "  ", padL["SkipRNG", 8], "  ",
                padL["SkipMiss", 9], "  ", padL["Errors", 7], reset];
            Scan[Function[row,
                Print["  ", padR[row[[1]], 24],
                    padL[row[[2]], 6], "  ", padL[row[[3]], 6], "  ",
                    padL[row[[4]], 8], "  ", padL[row[[5]], 9], "  ",
                    padL[row[[6]], 7]];
            ], rows];
            Print[bold, "  ", padR["  group total", 24],
                green, padL[gp, 6], reset, "  ",
                If[gf > 0, red, dim], padL[gf, 6], reset, "  ",
                yellow, padL[gr, 8], reset, "  ",
                yellow, padL[gm, 9], reset, "  ",
                If[ge > 0, red, dim], padL[ge, 7], reset];
        ],
        {group, testGroups}
    ];
    Print[""];
    Print[bold, "  ", padR["GRAND TOTAL", 24],
        green, padL[grandPass, 6], reset, "  ",
        If[grandFail > 0, red, dim], padL[grandFail, 6], reset, "  ",
        yellow, padL[grandRNG, 8], reset, "  ",
        yellow, padL[grandMiss, 9], reset, "  ",
        If[grandErr > 0, red, dim], padL[grandErr, 7], reset];
];

(* Repopulate globals from aggregator and write SKIPPED_AND_MISSING.md *)
$ValidationRNGSkipped = $AllRNGSkipped;
$ValidationMissingSkipped = $AllMissingSkipped;
$ValidationErrors = $AllErrors;

skipLogPath = FileNameJoin[{$ValidationDir, "SKIPPED_AND_MISSING.md"}];
ValidationWriteSkipLog[
    skipLogPath,
    Length[$AllSucceeded],
    Length[$AllFailures]
];
Print[""];
Print[bold, "Wrote skip log: ", reset, skipLogPath];

If[Length[$AllFailures] > 0 || Length[$AllErrors] > 0, Quit[1], Quit[0]];
