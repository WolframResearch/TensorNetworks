(* Component replays use captured arguments; no TN function is replaced or instrumented. *)
Begin["TNProfile`"];
manifestPath = Environment["TN_BENCH_MANIFEST"];
outputPath = Environment["TN_BENCH_OUTPUT"];
repo = Environment["TN_BENCH_REPO"];
manifest = Import[manifestPath, "RawJSON"];
root = DirectoryName[manifestPath];
protocol = manifest["protocol"];
PacletDirectoryLoad[Environment["TN_BENCH_ARRAYS_DIRECTORY"]];
PacletDirectoryLoad[FileNameJoin[{repo, "TensorNetworks"}]];
Needs["Wolfram`TensorNetworks`"];
SetSystemOptions["ParallelOptions" -> {"ParallelThreadNumber" -> protocol["threads"]}];
p[name_] := Symbol["Wolfram`TensorNetworks`Contraction`PackagePrivate`" <> name];
s[name_] := Symbol["Wolfram`TensorNetworks`PackageScope`" <> name];
profiled = p /@ {"planKey", "leafSignature", "numericLeafQ", "contractTreePath", "contractStep",
    "contractTensorPair", "einsumDot", "einsumArrayDot", "settleLeaf", "labelDimensions",
    "computeRepresentation", "machinePrecisionLeaves", "integerScaledLeaves", "computableLeafTensors"};
fingerprint[] := Hash[Function[h, {DownValues[h], UpValues[h], SubValues[h], Attributes[h], Options[h]}] /@ profiled];
before = fingerprint[];
result = <|"schema_version" -> 1, "backend" -> "tn.profile", "corpus_sha256" -> FileHash[manifestPath, "SHA256", "HexString"],
    "metadata" -> <|"wolfram" -> $Version, "system_id" -> $SystemID,
        "arrays_version" -> PacletObject["Wolfram/Arrays"]["Version"],
        "parallel_options" -> ToString[SystemOptions["ParallelOptions"], InputForm],
        "trace_method" -> "TraceScan captures evaluated arguments outside timing; duplicate evaluation events are removed. Replays are inclusive, overlapping component costs, not additive time shares."|>,
    "records" -> {}, "observations" -> {}|>;
If[PacletObject["Wolfram/Arrays"]["Version"] =!= "1.4.2", Echo["Requires the baseline Arrays 1.4.2"]; Exit[2]];
If[! AllTrue[manifest["files"], Function[item, With[{file = FileNameJoin[{root, item["path"]}]},
    FileByteCount[file] === item["bytes"] && FileHash[file, "SHA256", "HexString"] === item["sha256"]]]], Exit[2]];
save[] := If[ByteCount[result] < 8 2^20, Export[outputPath, result, "RawJSON"], Exit[2]];
readArray[spec_] := With[{re = ArrayReshape[BinaryReadList[FileNameJoin[{root, spec["real"]}], "Real64", ByteOrdering -> -1], spec["shape"]]},
    Developer`ToPackedArray[If[KeyExistsQ[spec, "imag"], re + I ArrayReshape[
        BinaryReadList[FileNameJoin[{root, spec["imag"]}], "Real64", ByteOrdering -> -1], spec["shape"]], re]]];
errorOf[value_, reference_] := If[ArrayQ[value, _, NumberQ] && Dimensions[value] === Dimensions[reference],
    With[{error = Norm[Flatten[value - reference]]/Max[1., Norm[Flatten[reference]]]},
        If[NumberQ[error] && TrueQ[error <= 1.*^-10], N[error], $Failed]], $Failed];
SetAttributes[bounded, HoldAll];
bounded[expr_] := TimeConstrained[MemoryConstrained[expr, 1024 2^20, $Failed], 30, $Failed];
measure[id_, task_, thunk_, valid_, count_ : 1] := Module[{base, error, calibration, iterations, timings, after},
    base = <|"case" -> id, "task" -> task, "calls_per_replay" -> count|>;
    error = valid[bounded[thunk[]]];
    If[! NumberQ[error], Return[Join[base, <|"status" -> "failed", "error" -> "warm validation"|>]]];
    calibration = bounded[NestWhile[With[{n = 2 First[#]}, {n, First[AbsoluteTiming[Scan[(thunk[];) &, Range[n]]]]}] &,
        {0.5, 0.}, Last[#] < protocol["sample_seconds"] && First[#] < 16384 &]];
    If[! MatchQ[calibration, {_ ? NumberQ, _ ? NumberQ}], Return[Join[base, <|"status" -> "failed", "error" -> "calibration limit"|>]]];
    iterations = Round[First[calibration]];
    timings = bounded[Table[First[AbsoluteTiming[Scan[(thunk[];) &, Range[iterations]]]]/iterations, {protocol["samples"]}]];
    after = valid[bounded[thunk[]]];
    If[! VectorQ[timings, NumberQ] || ! NumberQ[after] || ! AllTrue[timings, Positive],
        Return[Join[base, <|"status" -> "failed", "error" -> "post validation or timing"|>]]];
    Join[base, <|"status" -> "ok", "normalized_error" -> Max[error, after], "samples_seconds" -> timings,
        "iterations_per_sample" -> iterations, "median_seconds" -> Median[timings], "min_seconds" -> Min[timings], "max_seconds" -> Max[timings]|>]
];
emit[id_, task_, thunk_, valid_, count_ : 1] := Sow[measure[id, task, thunk, valid, count], "rows"];
same[expected_] := Function[x, If[SameQ[x, expected], 0., $Failed]];
SetAttributes[capture, HoldAllComplete];
capture[HoldCompleteForm[expr_]] := With[{h = Head[Unevaluated[expr]], args = List @@ Unevaluated[expr]}, Sow[{h, args}, "calls"];];
replay[calls_] := Apply @@@ calls;
orderedPairLabels[i_, j_] := With[{c = Select[i, MemberQ[j, #] &]},
    {c, Select[i, ! MemberQ[c, #] &], Select[j, ! MemberQ[c, #] &]}];
labelExamples = {{{3, 1, 2}, {2, 3, 5}}, {{3, 1}, {4, 5}}, {{3, 1}, {1, 3}}, {{1, 2}, {2, 3}}, {{}, {1}}, {{}, {}}};
labelCandidateValid = AllTrue[labelExamples, Function[axes, With[{i = First[axes], j = Last[axes]},
    With[{c = DeleteElements[DeleteDuplicates@Join[i, j], SymmetricDifference[i, j]]},
        orderedPairLabels[i, j] === {c, DeleteElements[i, c], DeleteElements[j, c]}]]]];
result["metadata"] = Append[result["metadata"], "ordered_label_candidate_boundary_checks" -> labelCandidateValid];
freshHashRecord[id_, tensors_, expected_] := Module[{timings, fresh, hashes, valid = True},
    timings = Table[
        fresh = Unitize /@ tensors;
        With[{elapsed = First[AbsoluteTiming[hashes = Hash /@ fresh]]},
            valid = valid && SameQ[hashes, expected]; elapsed],
        {protocol["samples"]}
    ];
    If[! valid || ! VectorQ[timings, Positive],
        <|"case" -> id, "task" -> "key.hash_fresh_masks", "calls_per_replay" -> 1, "status" -> "failed", "error" -> "fresh-mask hash validation"|>,
        <|"case" -> id, "task" -> "key.hash_fresh_masks", "calls_per_replay" -> 1, "status" -> "ok", "normalized_error" -> 0.,
          "samples_seconds" -> timings, "iterations_per_sample" -> 1, "median_seconds" -> Median[timings],
          "min_seconds" -> Min[timings], "max_seconds" -> Max[timings],
          "timing_scope" -> "Fresh Unitize arrays are prepared outside each timed first hash. One complete tensor set per sample; no calibration hashes."|>
    ]
];

profileCase[case_] := Module[{id = case["id"], tensors, labels, output, net, data, reference, tree, key, masks,
    sparseData, keyParts, records, small, method, calls, unique, rawCounts, counts, group, expected, inactive,
    leaves, options, slotOf, steps, traceResult, keyObservation, stateAfter, pairParts, cachedKeyProbe, pairCalls, pairInputs, pairFunctions, pairResult},
    ClearSystemCache[];
    tensors = readArray /@ case["tensors"];
    {labels, output} = Lookup[case, {"labels", "output"}];
    reference = readArray[case["reference"]];
    net = TensorNetwork[tensors, labels -> output]; data = TensorNetworkData[net];
    tree = PathToTreePath[case["path"] + 1];
    key = p["planKey"][data, "ArrayDot"];
    masks = Unitize /@ tensors;
    sparseData = TensorNetworkData[TensorNetwork[SparseArray /@ tensors, labels -> output]];
    small = case["d"] <= 16;
    leaves = AssociationThread[data["Vertices"], MapThread[List, {tensors, data["ContractionIndices"]}]];
    slotOf = AssociationThread[List /@ data["Vertices"], Range[Length[tensors]]];
    steps = s["treeSteps"][tree, slotOf];
    cachedKeyProbe = Association[Rule[key, {"Given", tree}]];
    keyParts = {Dimensions /@ tensors, Precision /@ tensors, p["numericLeafQ"] /@ tensors, ArrayQ[#, _, NumericQ] & /@ tensors};
    keyObservation = <|"case" -> id, "input_bytes" -> ByteCount[tensors], "elements" -> Total[Times @@@ (Dimensions /@ tensors)],
        "packed_inputs" -> AllTrue[tensors, Developer`PackedArrayQ], "packed_masks" -> AllTrue[masks, Developer`PackedArrayQ],
        "mask_bytes" -> ByteCount[masks], "expected_steps" -> Length[tensors] - 1,
        "same_support_same_key" -> SameQ[key, p["planKey"][Append[data, "Tensors" -> ReplacePart[tensors, 1 -> 2 First[tensors]]], "ArrayDot"]],
        "changed_support_changes_key" -> UnsameQ[key, p["planKey"][Append[data, "Tensors" -> ReplacePart[tensors, 1 -> readArray[case["changed_first"]]]], "ArrayDot"]]|>;
    records = First[Reap[
        emit[id, "key.total", Function[p["planKey"][data, "ArrayDot"]], same[key]];
        emit[id, "key.leaf_signatures", Function[p["leafSignature"] /@ tensors], same[Last[key]]];
        emit[id, "key.mask_and_hash", Function[Hash[Unitize[#]] & /@ tensors], same[Hash /@ masks]];
        emit[id, "key.unitize", Function[Unitize /@ tensors], same[masks]];
        emit[id, "key.hash_precomputed_masks", Function[Hash /@ masks], same[Hash /@ masks]];
        Sow[freshHashRecord[id, tensors, Hash /@ masks], "rows"];
        emit[id, "key.dimensions", Function[Dimensions /@ tensors], same[keyParts[[1]]]];
        emit[id, "key.precision", Function[Precision /@ tensors], same[keyParts[[2]]]];
        emit[id, "key.numeric_leaf", Function[p["numericLeafQ"] /@ tensors], same[keyParts[[3]]]];
        emit[id, "key.arrayq_numeric", Function[ArrayQ[#, _, NumericQ] & /@ tensors], same[keyParts[[4]]]];
        emit[id, "key.sparse_full", Function[p["planKey"][sparseData, "ArrayDot"]], same[p["planKey"][sparseData, "ArrayDot"]]];
        emit[id, "key.cache_lookup_precomputed", Function[Lookup[cachedKeyProbe, Key[key]]], same[{"Given", tree}]];
        If[small,
            emit[id, "execute.direct_dot", Function[Fold[Dot, First[tensors], Rest[tensors]]], errorOf[#, reference] &];
            emit[id, "prepare.data", Function[TensorNetworkData[net]], same[data]];
            emit[id, "prepare.tree_predicate", Function[TreePathQ[tree]], same[True]];
            emit[id, "prepare.tree_steps", Function[s["treeSteps"][tree, slotOf]], same[steps]];
            emit[id, "prepare.label_dimensions", Function[p["labelDimensions"][Values[leaves]]], same[p["labelDimensions"][Values[leaves]]]];
            emit[id, "prepare.convert_leaves", Function[p["convertLeafTensors"]["Dot", tensors]], same[tensors]];
            emit[id, "prepare.computable_leaves", Function[p["computableLeafTensors"][tensors]], same[tensors]];
            emit[id, "prepare.machine_precision_leaves", Function[p["machinePrecisionLeaves"][tensors]], same[tensors]];
            emit[id, "prepare.integer_scaled_leaves", Function[p["integerScaledLeaves"][tensors]], same[{1, tensors}]];
            emit[id, "prepare.represent_leaves", Function[p["computeRepresentation"] /@ tensors], same[tensors]];
            emit[id, "prepare.holder_counts", Function[Counts[Catenate[DeleteDuplicates /@ Values[leaves][[All, 2]]]]], same[Counts[Catenate[labels]]]];
            emit[id, "prepare.leaf_association", Function[AssociationThread[data["Vertices"], MapThread[List, {tensors, data["ContractionIndices"]}]]], same[leaves]];
            Scan[Function[engine,
                inactive = TensorNetworkContraction[data, tree, Method -> engine, "Inactive" -> True];
                emit[id, "execute.total." <> engine, Function[TensorNetworkContraction[data, tree, Method -> engine, "Inactive" -> False]], errorOf[#, reference] &];
                emit[id, "execute.build_inactive." <> engine, Function[TensorNetworkContraction[data, tree, Method -> engine, "Inactive" -> True]], errorOf[Activate[#], reference] &];
                emit[id, "execute.activate_prebuilt." <> engine, Function[Activate[inactive]], errorOf[#, reference] &];
                traceResult = Reap[TraceScan[capture,
                    TensorNetworkContraction[data, tree, Method -> engine, "Inactive" -> False],
                    HoldPattern[(Wolfram`TensorNetworks`Contraction`PackagePrivate`contractTreePath |
                        Wolfram`TensorNetworks`Contraction`PackagePrivate`contractStep |
                        Wolfram`TensorNetworks`Contraction`PackagePrivate`contractTensorPair |
                        Wolfram`TensorNetworks`Contraction`PackagePrivate`einsumDot |
                        Wolfram`TensorNetworks`Contraction`PackagePrivate`einsumArrayDot |
                        Wolfram`TensorNetworks`Contraction`PackagePrivate`settleLeaf)[___]], TraceInternal -> False], "calls"];
                calls = First[traceResult[[2]], {}]; unique = DeleteDuplicates[calls];
                rawCounts = Counts[SymbolName[First[#]] & /@ calls]; counts = Counts[SymbolName[First[#]] & /@ unique];
                pairCalls = Select[unique, SymbolName[First[#]] === If[engine === "Dot", "einsumDot", "einsumArrayDot"] &];
                pairInputs = Map[Function[call, With[{args = Last[call]}, With[{
                    i = args[[1, 1, 1]], j = args[[1, 1, 2]], a = args[[2]], b = args[[3]]
                }, With[{c = Intersection[i, j]}, {a, b, i, j, c, DeleteElements[i, c], DeleteElements[j, c]}]]]], pairCalls];
                pairFunctions = <|
                    "symmetric_difference" -> Function[x, SymmetricDifference[x[[3]], x[[4]]]],
                    "contracted_labels" -> Function[x, DeleteElements[DeleteDuplicates@Join[x[[3]], x[[4]]], SymmetricDifference[x[[3]], x[[4]]]]],
                    "ordered_label_candidate" -> Function[x, orderedPairLabels[x[[3]], x[[4]]]],
                    "delete_elements_single" -> Function[x, DeleteElements[x[[3]], x[[5]]]],
                    "remaining_labels" -> Function[x, {DeleteElements[x[[3]], x[[5]]], DeleteElements[x[[4]], x[[5]]]}],
                    "position_indices" -> Function[x, PositionIndex /@ x[[{3, 4}]]],
                    "symbolic_dimensions" -> Function[x, s["symbolicTensorDimensions"] /@ x[[{1, 2}]]],
                    "tensor_dimensions" -> Function[x, s["tensorDimensions"] /@ x[[{1, 2}]]],
                    "permutations" -> Function[x, {FindPermutation[x[[3]], Join[x[[6]], x[[5]]]], FindPermutation[x[[4]], Join[x[[5]], x[[7]]]]}],
                    "numeric_dot" -> Function[x, Dot[x[[1]], x[[2]]]],
                    "numeric_arraydot" -> Function[x, ArrayDot[x[[1]], x[[2]], {{2, 1}}]]
                |>;
                KeyValueMap[Function[{name, fn},
                    pairResult = If[name === "ordered_label_candidate", ({#[[5]], #[[6]], #[[7]]} & /@ pairInputs), fn /@ pairInputs];
                    emit[id, "pair." <> engine <> "." <> name, Function[fn /@ pairInputs], same[pairResult], Length[pairInputs]];
                ], pairFunctions];
                result["observations"] = Append[result["observations"], <|"case" -> id, "engine" -> engine,
                    "raw_trace_events" -> rawCounts, "unique_replay_inputs" -> counts|>];
                Scan[Function[name,
                    group = Select[unique, SymbolName[First[#]] === name &];
                    expected = Map[Switch[name,
                        "contractTreePath", reference,
                        "settleLeaf", #[[2, 1, 1]],
                        "contractStep", Dot[#[[2, 1, 1]], #[[2, 2, 1]]],
                        "contractTensorPair", Dot[First[#[[2, 1, 1]]], First[#[[2, 1, 2]]]],
                        _, Dot[#[[2, 2]], #[[2, 3]]]
                    ] &, group];
                    emit[id, "replay." <> engine <> "." <> name, Function[replay[group]],
                        Function[x, With[{errors = MapThread[errorOf[First[#1], #2] &, {x, expected}]},
                            If[Length[group] > 0 && AllTrue[errors, NumberQ], Max[errors], $Failed]]], Length[group]];
                ], {"contractTreePath", "contractStep", "contractTensorPair", If[engine === "Dot", "einsumDot", "einsumArrayDot"], "settleLeaf"}];
                emit[id, "harness.replay_dispatch." <> engine, Function[Scan[(Last[#];) &, unique]], same[Null], Length[unique]];
            ], {"Dot", "ArrayDot"}];
            Block[{Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache = <||>},
                TensorNetworkContract[data];
                emit[id, "automatic.cached_plan", Function[p["automaticPlan"][data, "ArrayDot"]],
                    If[MatchQ[#, {_Association, _ ? TreePathQ}], 0., $Failed] &];
                emit[id, "automatic.warm_execute", Function[TensorNetworkContract[data]], errorOf[#, reference] &];
            ];
        ];
    , "rows"][[2]], {}];
    result["observations"] = Append[result["observations"], keyObservation];
    records
];
result["records"] = {measure["harness", "harness.noop", Function[1], same[1]]};
Scan[Function[case, Echo[case["id"]]; result["records"] = Join[result["records"], profileCase[case]]; save[]], manifest["cases"]];
result["metadata"] = Join[result["metadata"], <|"profiled_definitions_unchanged" -> SameQ[before, fingerprint[]], "wl_peak_memory_bytes" -> MaxMemoryUsed[]|>];
save[];
Exit[Boole[AnyTrue[result["records"], #["status"] =!= "ok" &] || ! result["metadata"]["profiled_definitions_unchanged"]]];
End[];
