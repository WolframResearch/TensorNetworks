#!/usr/bin/env wolframscript

(* Colored output helpers *)
red = "\033[0;31m";
green = "\033[0;32m";
yellow = "\033[0;33m";
blue = "\033[0;34m";
bold = "\033[1m";
reset = "\033[0m";

checkMark = green <> "\[Checkmark]" <> reset;
crossMark = red <> "\[Cross]" <> reset;

printHeader[msg_] := Print[bold, blue, "==> ", reset, bold, msg, reset];
printSuccess[msg_] := Print[green, "  ", checkMark, " ", msg, reset];
printFailure[msg_] := Print[red, "  ", crossMark, " ", msg, reset];

(* Setup *)
root = DirectoryName @ DirectoryName @ $InputFileName;
If[root === "", root = Directory[]];
testsDir = FileNameJoin[{root, "Tests"}];

(* Parse Arguments *)
args = Rest[$ScriptCommandLine];
If[! VectorQ[args, StringQ],
    printFailure["Runner arguments must all be strings."];
    Quit[2]
];
argMap = Association[];
Do[
    If[StringStartsQ[args[[i]], "-"],
        key = StringDrop[args[[i]], 1];
        val = If[i < Length[args] && !StringStartsQ[args[[i+1]], "-"], args[[i+1]], True];
        AssociateTo[argMap, key -> val];
    ],
    {i, Length[args]}
];

targetFile = argMap["file"];
targetID = argMap["id"];

(* An explicitly requested file must resolve before dispatch. In particular a
   missing/non-string -file value must never fall back to the entire suite. *)
If[KeyExistsQ[argMap, "file"] && (! StringQ[targetFile] || targetFile === ""),
    printFailure["-file requires a nonempty file path."];
    Quit[2]
];
If[KeyExistsQ[argMap, "id"] && (! StringQ[targetID] || targetID === ""),
    printFailure["-id requires a nonempty test ID."];
    Quit[2]
];
filesToRun = If[KeyExistsQ[argMap, "file"],
    targetFile = If[FileExistsQ[targetFile], targetFile, FileNameJoin[{testsDir, targetFile}]];
    If[! FileExistsQ[targetFile] || DirectoryQ[targetFile],
        printFailure["Test file does not exist: " <> targetFile];
        Quit[2]
    ];
    {ExpandFileName[targetFile]},
    FileNames["*.wl", testsDir]
];

(* Filter out the master runner itself and other standalone runners. Each
   "run_*.wl" file is its own entry point (typically calling Quit[]) and
   would terminate this script if Get'd here; standalone tests live in
   test_*.wl. *)
filesToRun = Select[filesToRun,
    With[{name = FileNameTake[#]},
        name =!= "run_tests.wl" && !StringStartsQ[name, "run_"]
    ] &
];
If[KeyExistsQ[argMap, "file"] && filesToRun === {},
    printFailure["The requested file is a standalone runner, not a test file."];
    Quit[2]
];

(* Pre-load the paclet so test_setup.wl Get failures are harmless. *)
PacletDirectoryLoad[FileNameJoin[{root, "TensorNetworks"}]];
Needs["Wolfram`TensorNetworks`"];

(* A test that ends in an unexpected message or an evaluation error is a failure too. *)
$failedOutcomes = {"Failure", "MessagesFailure", "Error"};
(* Current MUnit reports Abort[] as a Failure with a FailureType; older
   reports may use an Aborted outcome. Keep the aborted tally disjoint
   from ordinary failures so Total Tests counts each test exactly once. *)
runnerAbortedQ[test_] := test["Outcome"] === "Aborted" ||
    (test["Outcome"] === "Failure" && test["FailureType"] === "EvaluationAbortedFailure");
runnerUnsuccessfulQ[test_] := MemberQ[$failedOutcomes, test["Outcome"]] || runnerAbortedQ[test];

totalPassed = 0;
totalFailed = 0;
totalAborted = 0;

Do[
    file = filesToRun[[f]];
    printHeader["Running tests from " <> FileNameTake[file]];
    
    (* Configure TestReport options based on arguments *)
    opts = {};
    (* Note: TestReport doesn't natively filter by ID easily without running them. 
       We will run the file and filter the results if needed, or rely on TestReport to run everything 
       and we just filter what we display/count if we want strict filtering. 
       However, efficient filtering would require Parsing the file. 
       For now, we'll run the report and check if specific ID was requested. *)
       
    report = TestReport[file];
    
    results = report["TestResults"];
    
    (* Filter results if ID is specified *)
    If[StringQ[targetID],
        results = Select[results, #["TestID"] === targetID &];
    ];
    
    filePassed = Count[results, _?(#["Outcome"] === "Success" &)];
    fileFailed = Count[results, _?(runnerUnsuccessfulQ[#] && ! runnerAbortedQ[#] &)];
    fileAborted = Count[results, _?runnerAbortedQ];
    
    (* Update Totals *)
    totalPassed += filePassed;
    totalFailed += fileFailed;
    totalAborted += fileAborted;
    
    If[fileFailed + fileAborted > 0,
        Scan[
            Function[{testObj},
                If[runnerUnsuccessfulQ[testObj],
                   id = testObj["TestID"] <> " (" <> If[runnerAbortedQ[testObj], "Aborted", testObj["Outcome"]] <> ")";
                   actual = testObj["ActualOutput"];
                   expected = testObj["ExpectedOutput"];
                   printFailure[ToString[id]];
                   Print["    Expected: ", expected];
                   Print["    Actual:   ", actual];
                   Print[""];
                ]
            ],
            Values[results]
        ]
    ];
    
, {f, Length[filesToRun]}];

Print[""];
printHeader["Total Summary"];
Print[bold, "Total Tests: ", totalPassed + totalFailed + totalAborted, reset];
Print[green, "Passed:      ", totalPassed, reset];

If[totalFailed + totalAborted > 0,
    Print[red, "Failed:      ", totalFailed, reset];
    Print[red, "Aborted:     ", totalAborted, reset];
    Print[""];
    printFailure["Some tests failed or aborted."];
    Quit[1];
,
    If[totalPassed == 0 && totalAborted == 0, 
        Print[yellow, "No tests found matching criteria.", reset];
    ,
        printSuccess["All tests passed!"];
    ];
    Quit[0];
];
