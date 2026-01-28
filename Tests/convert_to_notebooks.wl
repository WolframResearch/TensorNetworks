(* convert_to_notebooks.wl *)
(* Run this script in Mathematica to convert all test_*.wl files to .nb notebooks *)
(* Usage: Get["convert_to_notebooks.wl"] *)

convertWLToNotebook[wlFile_String] := Module[{
    content, lines, cells, nbFile, sectionPattern, testPattern,
    currentSection = None, cellGroups = {}, currentGroup = {}
},
    (* Read the .wl file *)
    content = Import[wlFile, "Text"];
    lines = StringSplit[content, "\n"];

    (* Pattern for section headers *)
    sectionPattern = RegularExpression["^\\(\\* =+ \\*\\)$"];

    (* Build cells from lines *)
    cells = {};
    Do[
        Which[
            (* Section separator line *)
            StringMatchQ[line, sectionPattern],
            Null,

            (* Section title comment *)
            StringMatchQ[line, "(* " ~~ __ ~~ " *)"] &&
            StringLength[line] < 60 &&
            !StringContainsQ[line, "Tests/"] &&
            !StringContainsQ[line, "Comprehensive"],
            (* Extract section name *)
            currentSection = StringTrim[StringReplace[line, {"(* " -> "", " *)" -> ""}]];
            If[currentGroup =!= {},
                AppendTo[cellGroups, currentGroup];
                currentGroup = {}
            ];
            AppendTo[currentGroup, Cell[currentSection, "Section"]],

            (* Title comment at top *)
            StringMatchQ[line, "(* Tests/" ~~ __ ~~ " *)"],
            AppendTo[cells, Cell[StringReplace[line, {"(* " -> "", " *)" -> ""}], "Title"]],

            (* Subtitle comment *)
            StringMatchQ[line, "(* Comprehensive" ~~ __ ~~ " *)"],
            AppendTo[cells, Cell[StringReplace[line, {"(* " -> "", " *)" -> ""}], "Subtitle"]],

            (* Empty line - skip *)
            StringMatchQ[line, Whitespace...],
            Null,

            (* Code line *)
            True,
            AppendTo[currentGroup, line]
        ],
        {line, lines}
    ];

    (* Add last group *)
    If[currentGroup =!= {},
        AppendTo[cellGroups, currentGroup]
    ];

    (* Convert groups to notebook cells *)
    cells = Join[cells,
        Flatten[Map[
            Function[group,
                If[MatchQ[group, {_Cell, ___}],
                    (* Has section header *)
                    {
                        group[[1]], (* Section cell *)
                        If[Length[group] > 1,
                            Cell[BoxData[RowBox[{StringRiffle[Rest[group], "\n"]}]], "Input"],
                            Nothing
                        ]
                    },
                    (* Just code *)
                    {Cell[BoxData[RowBox[{StringRiffle[group, "\n"]}]], "Input"]}
                ]
            ],
            cellGroups
        ], 1]
    ];

    (* Create notebook *)
    nbFile = StringReplace[wlFile, ".wl" -> ".nb"];

    Export[nbFile,
        Notebook[cells,
            StyleDefinitions -> "Default.nb"
        ]
    ];

    Print["Converted: ", wlFile, " -> ", nbFile];
    nbFile
]

(* Simple conversion - just wrap all code in Input cells *)
simpleConvertWLToNotebook[wlFile_String] := Module[{
    content, nbFile, cells
},
    content = Import[wlFile, "Text"];
    nbFile = StringReplace[wlFile, ".wl" -> ".nb"];

    (* Create a single Input cell with all the code *)
    cells = {
        Cell[FileBaseName[wlFile], "Title"],
        Cell[BoxData[content], "Input",
            InitializationCell -> True,
            CellLabel -> "In[1]:="
        ]
    };

    Export[nbFile, Notebook[cells, StyleDefinitions -> "Default.nb"]];
    Print["Converted: ", wlFile, " -> ", nbFile];
    nbFile
]

(* Better conversion that preserves structure *)
betterConvertWLToNotebook[wlFile_String] := Module[{
    content, nbFile
},
    content = Import[wlFile, "Text"];
    nbFile = StringReplace[wlFile, ".wl" -> ".nb"];

    (* Split content by VerificationTest blocks and section comments *)
    (* Each VerificationTest becomes its own cell *)

    Block[{
        lines = StringSplit[content, "\n"],
        cells = {},
        currentCode = {},
        inTest = False,
        bracketCount = 0,
        title = FileBaseName[wlFile]
    },
        (* Add title *)
        AppendTo[cells, Cell[title, "Title"]];

        Do[
            Which[
                (* Section header *)
                StringMatchQ[line, "(* " ~~ Repeated[" " | "=", {10, 100}] ~~ " *)"],
                If[currentCode =!= {},
                    AppendTo[cells, Cell[BoxData[StringRiffle[currentCode, "\n"]], "Input"]];
                    currentCode = {}
                ],

                (* Section title *)
                StringMatchQ[line, "(* " ~~ __ ~~ "Tests" ~~ __ ~~ " *)"] &&
                !StringContainsQ[line, "Comprehensive"] &&
                !StringContainsQ[line, "Tests/"],
                If[currentCode =!= {},
                    AppendTo[cells, Cell[BoxData[StringRiffle[currentCode, "\n"]], "Input"]];
                    currentCode = {}
                ];
                AppendTo[cells, Cell[
                    StringTrim[StringReplace[line, {"(* " -> "", " *)" -> ""}]],
                    "Section"
                ]],

                (* File header comment *)
                StringMatchQ[line, "(* Tests/" ~~ __ ~~ " *)"],
                Null, (* Skip, we use FileBaseName as title *)

                (* Comprehensive subtitle *)
                StringMatchQ[line, "(* Comprehensive" ~~ __ ~~ " *)"],
                AppendTo[cells, Cell[
                    StringTrim[StringReplace[line, {"(* " -> "", " *)" -> ""}]],
                    "Subtitle"
                ]],

                (* Empty line - if we have accumulated code that looks complete, flush it *)
                StringMatchQ[line, Whitespace...],
                If[currentCode =!= {} && bracketCount == 0,
                    AppendTo[cells, Cell[BoxData[StringRiffle[currentCode, "\n"]], "Input"]];
                    currentCode = {}
                ],

                (* Start of VerificationTest *)
                StringMatchQ[line, "VerificationTest[" ~~ ___],
                If[currentCode =!= {},
                    AppendTo[cells, Cell[BoxData[StringRiffle[currentCode, "\n"]], "Input"]];
                    currentCode = {}
                ];
                AppendTo[currentCode, line];
                bracketCount = StringCount[line, "["] - StringCount[line, "]"],

                (* Regular code line *)
                True,
                AppendTo[currentCode, line];
                bracketCount += StringCount[line, "["] - StringCount[line, "]"]
            ],
            {line, lines}
        ];

        (* Flush remaining code *)
        If[currentCode =!= {},
            AppendTo[cells, Cell[BoxData[StringRiffle[currentCode, "\n"]], "Input"]]
        ];

        Export[nbFile, Notebook[cells, StyleDefinitions -> "Default.nb"]];
        Print["Converted: ", wlFile, " -> ", nbFile];
        nbFile
    ]
]

(* Main conversion function *)
convertAllTestFiles[] := Module[{testDir, wlFiles},
    testDir = DirectoryName[$InputFileName];
    If[testDir === "",
        testDir = Directory[]
    ];

    wlFiles = FileNames["test_*.wl", testDir];

    Print["Found ", Length[wlFiles], " test files to convert"];

    Map[betterConvertWLToNotebook, wlFiles]
]

(* Simpler conversion that creates valid notebooks *)
simpleNotebookConvert[wlFile_String] := Module[{
    content, nbFile, cells, blocks, title, subtitle
},
    content = Import[wlFile, "Text"];
    nbFile = StringReplace[wlFile, ".wl" -> ".nb"];
    title = FileBaseName[wlFile];

    (* Extract subtitle if present *)
    subtitle = StringCases[content,
        "(* Comprehensive" ~~ Shortest[x__] ~~ " *)" :> StringTrim[x]];

    (* Split by VerificationTest or section markers *)
    blocks = StringSplit[content,
        RegularExpression["\\n(?=VerificationTest\\[|\\(\\* =)"]];

    cells = {Cell[title, "Title"]};

    If[subtitle =!= {},
        AppendTo[cells, Cell["Comprehensive" <> First[subtitle], "Subtitle"]]
    ];

    (* Process each block *)
    Do[
        Which[
            (* Section header *)
            StringStartsQ[StringTrim[block], "(* ="],
            Module[{sectionName},
                sectionName = StringCases[block,
                    "(* " ~~ Except[{"\n", "*"}].. ~~ " Tests" ~~ ___ ~~ " *)" :>
                    StringTrim[StringReplace[StringCases[block,
                        "(* " ~~ x:(Except[{"\n", "*"}]..) ~~ " *)" :> x][[1]],
                        {"=" -> "", "  " -> " "}]]];
                If[sectionName =!= {},
                    AppendTo[cells, Cell[First[sectionName], "Section"]]
                ]
            ],

            (* VerificationTest *)
            StringStartsQ[StringTrim[block], "VerificationTest["],
            AppendTo[cells, Cell[StringTrim[block], "Input"]],

            (* Setup/initialization code *)
            StringContainsQ[block, "Get["] && !StringContainsQ[block, "VerificationTest"],
            AppendTo[cells, Cell[StringTrim[block], "Input", InitializationCell -> True]],

            (* Other code *)
            StringLength[StringTrim[block]] > 0 && !StringStartsQ[StringTrim[block], "(*"],
            AppendTo[cells, Cell[StringTrim[block], "Input"]]
        ],
        {block, blocks}
    ];

    Export[nbFile,
        Notebook[cells, StyleDefinitions -> "Default.nb"],
        "NB"
    ];

    Print["Converted: ", wlFile, " -> ", nbFile];
    nbFile
]

(* Convert all test files *)
convertAllTestFiles[] := Module[{testDir, wlFiles},
    testDir = DirectoryName[$InputFileName];
    If[testDir === "",
        testDir = Directory[]
    ];

    wlFiles = FileNames["test_*.wl", testDir];

    Print["Found ", Length[wlFiles], " test files to convert"];

    Map[simpleNotebookConvert, wlFiles]
]

(* Run if this file is executed directly *)
If[TrueQ[$Notebooks] || ValueQ[$InputFileName],
    convertAllTestFiles[]
]
