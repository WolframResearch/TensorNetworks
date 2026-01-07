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

(* Determine files to run *)
filesToRun = If[StringQ[targetFile],
    {If[FileExistsQ[targetFile], targetFile, FileNameJoin[{testsDir, targetFile}]]},
    FileNames["*.wl", testsDir]
];

(* Filter out the runner itself and setup/debug files *)
filesToRun = Select[filesToRun, 
    !StringContainsQ[FileNameTake[#], "run_tests.wl"] &
];

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
    fileFailed = Count[results, _?(#["Outcome"] === "Failure" &)];
    fileAborted = Count[results, _?(#["Outcome"] === "Aborted" &)]; (* Simplified check *)
    
    (* Update Totals *)
    totalPassed += filePassed;
    totalFailed += fileFailed;
    totalAborted += fileAborted;
    
    If[fileFailed > 0,
        Scan[
            Function[{testObj},
                If[testObj["Outcome"] === "Failure",
                   id = testObj["TestID"];
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

If[totalFailed > 0,
    Print[red, "Failed:      ", totalFailed, reset];
    Print[""];
    printFailure["Some tests failed."];
    Quit[1];
,
    If[totalPassed == 0 && totalAborted == 0, 
        Print[yellow, "No tests found matching criteria.", reset];
    ,
        printSuccess["All tests passed!"];
    ];
    Quit[0];
];
