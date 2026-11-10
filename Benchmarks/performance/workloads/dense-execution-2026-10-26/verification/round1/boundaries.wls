Begin["DenseBoundaryVerification`"];
here = Environment["TN_PROBE_HERE"];
Get[FileNameJoin[{here, "results", "dense-execution-verification-round1", "worker.wls"}]];
guardNames = Union[Catenate[Names[# <> "*"] & /@ Contexts["Wolfram`TensorNetworks`*"]]];
definitionHash[name_] := ToExpression[name, InputForm,
    Function[s, Hash[{DownValues[s], UpValues[s], SubValues[s], Attributes[s], Options[s]}, "SHA256", "HexString"], HoldAll]];
guardsBefore = AssociationMap[definitionHash, guardNames];
docs = AssociationMap[ToString[ToExpression[# <> "::usage"], InputForm] &,
    {"System`ArrayReshape", "System`ArrayDot", "System`Dot", "System`Transpose", "System`FindPermutation",
     "System`Flatten", "System`TensorContract", "System`TensorProduct", "System`ClearSystemCache",
     "System`MemoryConstrained", "System`TimeConstrained", "System`FileHash", "System`BinaryReadList",
     "System`Hash", "System`Contexts", "System`Names", "System`AssociationMap", "System`ToExpression"}];
oracle[{a_, i_}, {b_, j_}] := With[{
    common = Select[i, MemberQ[j, #] &],
    free = Join[Select[i, ! MemberQ[j, #] &], Select[j, ! MemberQ[i, #] &]],
    ai = AssociationThread[i, Range[Length[i]]], bi = AssociationThread[j, Range[Length[j]]]
},
    {If[common === {}, TensorProduct[a, b],
        TensorContract[TensorProduct[a, b], MapThread[{#1, Length[i] + #2} &, {Lookup[ai, common], Lookup[bi, common]}]]], free}
];
dims = <|11 -> 2, 12 -> 3, 13 -> 2, 14 -> 2|>;
labelPairs = Join[
    Tuples[{Permutations[{11, 12, 13}], Permutations[{13, 14, 12}]}],
    Tuples[{Permutations[{11, 12}], Permutations[{12, 11, 14}]}],
    {{{11}, {11}}, {{11, 12}, {13, 14}}, {{11, 12}, {12, 11}}, {{}, {11, 12}}, {{11, 12}, {}}, {{}, {}}}
];
makeTensor[labels_, offset_] := If[labels === {}, offset,
    ArrayReshape[Range[Times @@ Lookup[dims, labels]] + offset, Lookup[dims, labels]]];
methods = {"matrixPair" -> DenseExecutionProbe`matrixPair, "fusedPair" -> DenseExecutionProbe`fusedPair,
    "existingArrayDot" -> DenseExecutionProbe`arrayPair, "existingDot" -> DenseExecutionProbe`dotPair};
pairResults = Catenate[MapIndexed[Function[{labels, row}, Catenate[Map[Function[domain,
    With[{a = If[domain === "real", N, Identity][makeTensor[First[labels], 2]],
          b = If[domain === "real", N, Identity][makeTensor[Last[labels], -3]]},
        With[{expected = oracle[{a, First[labels]}, {b, Last[labels]}]},
            Map[Function[method, With[{actual = Last[method][{a, First[labels]}, {b, Last[labels]}]},
                With[{error = If[Dimensions[First[actual]] === Dimensions[First[expected]],
                    Max[Abs[Flatten[{N[First[actual] - First[expected]]}]]] / Max[1., Max[Abs[Flatten[{N[First[expected]]}]]]], "shape_mismatch"]},
                    <|"case" -> First[row], "labels" -> labels, "domain" -> domain, "method" -> First[method],
                      "expected_shape" -> Dimensions[First[expected]], "actual_shape" -> Dimensions[First[actual]],
                      "labels_match" -> (Last[actual] === Last[expected]), "relative_error" -> error,
                      "ok" -> (Last[actual] === Last[expected] && NumberQ[error] && error < 1.*^-13),
                      "actual" -> ToString[actual, InputForm], "expected" -> ToString[expected, InputForm]|>
                ]]], methods]
        ]
    ]], {"exact", "real"}]]], labelPairs]];
unitResult = Block[{dims = <|11 -> 1, 12 -> 1, 13 -> 2, 14 -> 1|>},
    With[{a = N[makeTensor[{11, 12, 13}, 2]], b = N[makeTensor[{13, 14, 12}, -3]]},
        {DenseExecutionProbe`matrixPair[{a, {11, 12, 13}}, {b, {13, 14, 12}}],
         oracle[{a, {11, 12, 13}}, {b, {13, 14, 12}}]}
    ]
];
networkSpecs = {
    <|"name" -> "four-cycle-first-step-outer-product", "labels" -> {{1, 2}, {2, 3}, {3, 4}, {4, 1}}, "path" -> {{1, 3}, {1, 2}, {1, 2}}|>,
    <|"name" -> "two-disconnected-inner-products-then-scalars", "labels" -> {{1}, {1}, {2}, {2}}, "path" -> {{1, 2}, {1, 2}, {1, 2}}|>,
    <|"name" -> "three-label-full-contraction-reversed", "labels" -> {{1, 2, 3}, {3, 2, 1}}, "path" -> {{1, 2}}|>,
    <|"name" -> "three-site-chain", "labels" -> {{1}, {1, 2}, {2}}, "path" -> {{1, 2}, {1, 2}}|>
};
networkResults = Map[Function[spec,
    With[{labels = spec["labels"], tensors = MapIndexed[N[ArrayReshape[Range[2^Length[#1]] + First[#2], ConstantArray[2, Length[#1]]]] &, spec["labels"]]},
        With[{expected = TensorContract[TensorProduct @@ tensors, Values[PositionIndex[Catenate[labels]]]]},
            Block[{DenseExecutionProbe`tensors = tensors, DenseExecutionProbe`case = <|"labels" -> labels|>, DenseExecutionProbe`path = spec["path"]},
                <|"name" -> spec["name"], "expected" -> expected,
                  "actual" -> DenseExecutionProbe`runPairs[DenseExecutionProbe`matrixPair],
                  "ok" -> (expected === DenseExecutionProbe`runPairs[DenseExecutionProbe`matrixPair])|>
            ]
        ]
    ]], networkSpecs];
symbolicExpected = x1 y1 + x2 y2;
symbolicActual = First[DenseExecutionProbe`matrixPair[{{x1, x2}, {1}}, {{y1, y2}, {1}}]];
malformed = Block[{$MessageList = {}}, With[{
    result = DenseExecutionProbe`matrixPair[{{1., 2.}, {1}}, {{1., 2., 3.}, {1}}]
}, <|"result" -> ToString[result, InputForm], "messages" -> ToString[$MessageList, InputForm], "scope" -> "outside measured eligible shapes"|>]];
empty = Block[{$MessageList = {}}, With[{
    result = DenseExecutionProbe`matrixPair[{{}, {1}}, {{}, {1}}]
}, <|"result" -> ToString[result, InputForm], "messages" -> ToString[$MessageList, InputForm], "scope" -> "outside positive PEPS dimensions"|>]];
report = <|"pair_results" -> pairResults, "failed_pairs" -> Select[pairResults, ! TrueQ[#["ok"]] &],
    "pair_test_count" -> Length[pairResults], "unit_dimension_result" -> ToString[unitResult, InputForm],
    "network_results" -> networkResults,
    "symbolic_result" -> ToString[symbolicActual, InputForm], "symbolic_correct" -> (Expand[symbolicActual - symbolicExpected] === 0),
    "malformed" -> malformed, "empty" -> empty, "docs" -> docs,
    "guarded_symbol_count" -> Length[guardNames], "function_guards_before" -> guardsBefore,
    "function_guards_after" -> AssociationMap[definitionHash, guardNames],
    "all_function_definitions_unchanged" -> (guardsBefore === AssociationMap[definitionHash, guardNames]),
    "arrays_entry_file" -> FindFile["Wolfram`Arrays`"]|>;
Export[Environment["TN_VERIFY_BOUNDARY_OUT"], report, "RawJSON"];
Echo[KeyTake[report, {"pair_test_count", "failed_pairs", "network_results", "symbolic_correct", "all_function_definitions_unchanged", "arrays_entry_file"}]];
End[];
