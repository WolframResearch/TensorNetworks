(* Read-only kernel audit. Only the plan-cache value is dynamically localized. *)
Begin["TNAudit`"];
manifestPath = Environment["TN_BENCH_MANIFEST"];
outputPath = Environment["TN_BENCH_OUTPUT"];
repo = Environment["TN_BENCH_REPO"];
manifest = Import[manifestPath, "RawJSON"];
root = DirectoryName[manifestPath];
protocol = manifest["protocol"];
samples = protocol["samples"];
sampleSeconds = protocol["sample_seconds"];
arraysDirectory = Environment["TN_BENCH_ARRAYS_DIRECTORY"];
If[StringQ[arraysDirectory] && StringLength[arraysDirectory] > 0,
    If[! FileExistsQ[FileNameJoin[{arraysDirectory, "PacletInfo.wl"}]],
        arraysDirectory = FileNameJoin[{arraysDirectory, "Arrays"}]];
    PacletDirectoryLoad[arraysDirectory]
];
PacletDirectoryLoad[FileNameJoin[{repo, "TensorNetworks"}]];
Needs["Wolfram`TensorNetworks`"];
SetSystemOptions["ParallelOptions" -> {"ParallelThreadNumber" -> protocol["threads"]}];

versionParts[s_] := PadRight[FromDigits /@ StringSplit[s, "."], 3];
arraysVersion = PacletObject["Wolfram/Arrays"]["Version"];
dependencySupported = OrderedQ[{versionParts[manifest["minimum_arrays_version"]], versionParts[arraysVersion]}];
result = <|"schema_version" -> 1, "corpus_sha256" -> FileHash[manifestPath, "SHA256", "HexString"],
    "backend" -> "tn", "metadata" -> <|"wolfram" -> $Version, "system_id" -> $SystemID,
        "paclet_location" -> PacletObject["Wolfram/TensorNetworks"]["Location"],
        "arrays_version" -> arraysVersion, "dependency_supported" -> dependencySupported,
        "arrays_location" -> PacletObject["Wolfram/Arrays"]["Location"],
        "parallel_options" -> ToString[SystemOptions["ParallelOptions"], InputForm]|>,
    "records" -> {}, "observations" -> {}|>;

save[] := If[ByteCount[result] < 8 2^20,
    Export[outputPath <> ".tmp", result, "RawJSON"]; RenameFile[outputPath <> ".tmp", outputPath, OverwriteTarget -> True],
    Echo["Result exceeds size limit"]; Exit[2]
];
If[! AllTrue[manifest["files"], Function[item, With[{file = FileNameJoin[{root, item["path"]}]},
    FileExistsQ[file] && FileByteCount[file] === item["bytes"] &&
        FileHash[file, "SHA256", "HexString"] === item["sha256"]
]]], result["error"] = "Corpus file checksum or size mismatch"; save[]; Exit[2]];
If[! dependencySupported && Environment["TN_BENCH_ALLOW_UNSUPPORTED"] =!= "1",
    result["error"] = "Installed Wolfram/Arrays is below the paclet minimum. Explicit provisional override required.";
    save[]; Echo[result["error"]]; Exit[2]
];

readArray[spec_] := With[{
    re = ArrayReshape[BinaryReadList[FileNameJoin[{root, spec["real"]}], "Real64", ByteOrdering -> -1], spec["shape"]]
}, Developer`ToPackedArray[If[KeyExistsQ[spec, "imag"],
    re + I ArrayReshape[BinaryReadList[FileNameJoin[{root, spec["imag"]}], "Real64", ByteOrdering -> -1], spec["shape"]], re]]];

errorOf[value_, reference_] := With[{error = Which[
    NumberQ[reference] && NumberQ[value], Abs[value - reference]/Max[1., Abs[reference]],
    ArrayQ[value, _, NumberQ] && Dimensions[value] === Dimensions[reference],
        Norm[Flatten[value - reference]]/Max[1., Norm[Flatten[reference]]],
    True, $Failed
]}, If[NumberQ[error] && TrueQ[error <= 1.*^-10], N[error], $Failed]];

SetAttributes[bounded, HoldAll];
bounded[expr_] := TimeConstrained[MemoryConstrained[expr, 1024 2^20, $Failed], 30, $Failed];

measure[case_, implementation_, task_, thunk_, valid_, mode_ : "prepared"] := Module[
    {base = <|"case" -> case, "implementation" -> implementation, "task" -> task, "mode" -> mode|>,
     warm, error, calibration, iterations, timings, after},
    warm = bounded[thunk[]];
    error = valid[warm];
    If[! NumberQ[error], Return[Join[base, <|"status" -> "failed", "error" -> "Warm-up result failed validation"|>]]];
    warm = Null;
    calibration = bounded[NestWhile[
        With[{count = 2 First[#]}, {count, First[AbsoluteTiming[Scan[(thunk[];) &, Range[count]]]]}] &,
        {0.5, 0.}, Last[#] < sampleSeconds && First[#] < 16384 &
    ]];
    If[! MatchQ[calibration, {_ ? NumberQ, _ ? NumberQ}],
        Return[Join[base, <|"status" -> "failed", "error" -> "Calibration resource limit"|>]]];
    iterations = Round[First[calibration]];
    timings = bounded[Table[First[AbsoluteTiming[Scan[(thunk[];) &, Range[iterations]]]]/iterations, {samples}]];
    after = bounded[valid[thunk[]]];
    If[! VectorQ[timings, NumberQ] || ! NumberQ[after] || ! AllTrue[timings, Positive],
        Return[Join[base, <|"status" -> "failed", "error" -> "Timing or post-timing validation failed"|>]]];
    Join[base, <|"status" -> "ok", "normalized_error" -> error, "samples_seconds" -> timings,
        "iterations_per_sample" -> iterations, "median_seconds" -> Median[timings],
        "min_seconds" -> Min[timings], "max_seconds" -> Max[timings]|>]
];

keyFunction = Symbol["Wolfram`TensorNetworks`Contraction`PackagePrivate`planKey"];
numericLeafFunction = Symbol["Wolfram`TensorNetworks`Contraction`PackagePrivate`numericLeafQ"];
parameterFunction = Symbol["Wolfram`TensorNetworks`PackageScope`extractContractionParameters"];
If[Length[DownValues[Wolfram`TensorNetworks`Contraction`PackagePrivate`planKey]] === 0,
    result["error"] = "Private plan-key API unavailable"; save[]; Exit[2]];

emit[args___] := Sow[measure[args], "rows"];
listValid[x_] := If[ListQ[x], 0., $Failed];
dataValid[x_] := If[AssociationQ[x], 0., $Failed];

chainAudit[case_] := Module[{id = case["id"], tensors, reference, changedReference, labels, out,
    net, data, tree, path, newTensors, changedTensors, newData, changedData, reverseData,
    key, newKey, changedKey, counts, checked, observation, sparseData, diagonalData, planned},
    ClearSystemCache[];
    tensors = readArray /@ case["tensors"];
    reference = readArray[case["reference"]];
    changedReference = readArray[case["changed_reference"]];
    {labels, out} = Lookup[case, {"labels", "output"}];
    net = TensorNetwork[tensors, labels -> out];
    data = TensorNetworkData[net];
    path = case["path"] + 1;
    tree = PathToTreePath[path];
    newTensors = ReplacePart[tensors, 1 -> 2 First[tensors]];
    changedTensors = ReplacePart[tensors, 1 -> readArray[case["changed_first"]]];
    newData = TensorNetworkData[TensorNetwork[newTensors, labels -> out]];
    changedData = TensorNetworkData[TensorNetwork[changedTensors, labels -> out]];
    reverseData = TensorNetworkData[TensorNetwork[tensors, labels -> Reverse[out]]];
    key = keyFunction[data, "ArrayDot"]; newKey = keyFunction[newData, "ArrayDot"];
    changedKey = keyFunction[changedData, "ArrayDot"];
    counts = Block[{Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache = <||>},
        checked = MapThread[
            Function[{form, expected}, With[{value = TensorNetworkContract[form]},
                {errorOf[value, expected], Length[Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache]}
            ]],
            {{data, data, newData, changedData, reverseData},
             {reference, reference, 2 reference, changedReference, Transpose[reference]}}
        ];
        checked[[All, 2]]
    ];
    observation = <|"case" -> id, "same_support_same_key" -> SameQ[key, newKey],
        "changed_support_changes_key" -> UnsameQ[key, changedKey],
        "output_order_changes_key" -> UnsameQ[key, keyFunction[reverseData, "ArrayDot"]],
        "cache_counts_base_repeat_values_support_output" -> counts,
        "outputs_correct" -> AllTrue[checked[[All, 1]], NumberQ],
        "input_bytes" -> ByteCount[tensors], "packed_inputs" -> AllTrue[tensors, Developer`PackedArrayQ]|>;
    result["observations"] = Append[result["observations"], observation];
    sparseData = TensorNetworkData[TensorNetwork[SparseArray /@ tensors, labels -> out]];
    diagonalData = TensorNetworkData[TensorNetwork[
        (SparseArray[Band[{1, 1}] -> Diagonal[#], Dimensions[#]] & /@ tensors), labels -> out]];
    First[Reap[
        emit[id, "tn", "chain.prepare.data", Function[TensorNetworkData[net]], dataValid];
        emit[id, "tn", "cache.key.dense", Function[keyFunction[data, "ArrayDot"]], listValid];
        emit[id, "tn", "cache.key.sparse_full", Function[keyFunction[sparseData, "ArrayDot"]], listValid];
        emit[id, "tn", "cache.key.sparse_diagonal", Function[keyFunction[diagonalData, "ArrayDot"]], listValid];
        emit[id, "tn", "cache.component.precision", Function[Precision /@ tensors], listValid];
        emit[id, "tn", "cache.component.numericq", Function[numericLeafFunction /@ tensors], listValid];
        emit[id, "tn", "cache.component.zero_mask_hash", Function[Hash[Unitize[#]] & /@ tensors], listValid];
        emit[id, "tn", "chain.prepare.parameters", Function[parameterFunction[data]],
            If[MatchQ[#, {_List, _List, _Association}], 0., $Failed] &];
        emit[id, "tn", "chain.prepare.path_to_tree", Function[PathToTreePath[path]], If[TreePathQ[#], 0., $Failed] &];
        planned = GreedyContractionPath[data];
        Sow[Join[measure[id, "tn", "chain.plan.greedy", Function[GreedyContractionPath[data]],
            If[CanonicalPathQ[#], errorOf[TensorNetworkContract[data, #], reference], $Failed] &, "search"],
            If[CanonicalPathQ[planned], <|"planned_path" -> (planned - 1)|>, <||>]], "rows"];
        Scan[Function[method,
            emit[id, "tn." <> method, "chain.execute.fixed_path",
                Function[TensorNetworkContraction[data, tree, Method -> method, "Inactive" -> False]], errorOf[#, reference] &];
        ], {"ArrayDot", "Dot"}];
        emit[id, "wl.Dot", "chain.execute.fixed_path", Function[Fold[Dot, First[tensors], Rest[tensors]]], errorOf[#, reference] &];
        emit[id, "wl.ArrayDot", "chain.execute.fixed_path", Function[Fold[ArrayDot[#1, #2, {{2, 1}}] &, First[tensors], Rest[tensors]]], errorOf[#, reference] &];
        emit[id, "tn.ArrayDot", "chain.execute.fixed_path", Function[TensorNetworkContract[net, path]], errorOf[#, reference] &, "canonical_path_net"];
        Block[{Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache = <||>},
            TensorNetworkContract[data];
            emit[id, "tn", "chain.execute.automatic", Function[TensorNetworkContract[data]], errorOf[#, reference] &, "cache_hit_data"];
            emit[id, "tn", "chain.execute.new_values", Function[TensorNetworkContract[newData]], errorOf[#, 2 reference] &, "cache_hit_data"];
        ];
        emit[id, "tn", "chain.execute.automatic", Function[Block[
            {Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache = <||>}, TensorNetworkContract[data]
        ]], errorOf[#, reference] &, "cache_miss_data"];
        emit[id, "tn", "chain.execute.changed_support", Function[Block[
            {Wolfram`TensorNetworks`Contraction`PackagePrivate`$planCache = <||>}, TensorNetworkContract[changedData]
        ]], errorOf[#, changedReference] &, "cache_miss_data"];
        , "rows"][[2]], {}]
];

mpsAudit[case_] := Module[{tensors, mps, reference, n = case["n"], canonicalValid},
    ClearSystemCache[];
    tensors = readArray /@ case["tensors"];
    mps = TensorNetwork[tensors, case["labels"] -> case["output"]];
    reference = readArray[case["reference"]];
    canonicalValid = Function[x, If[TensorNetworkQ[x] && MPSCanonicalQ[x, "Left"],
        errorOf[TensorNetworkContract[x], reference], $Failed]];
    First[Reap[
        emit[case["id"], "tn.MPS", "mps.overlap", Function[MPSOverlap[mps, mps]], errorOf[#, case["norm_squared"]] &, "native_mps"];
        emit[case["id"], "tn.MPS", "mps.left_canonical", Function[MPSCanonicalForm[mps, "Left"]], canonicalValid, "native_mps"];
        , "rows"][[2]], {}]
];

result["records"] = {measure["harness", "wl", "harness.noop", Function[1], If[# === 1, 0., $Failed] &]};
Scan[Function[case,
    Echo[case["id"]];
    result["records"] = Join[result["records"], If[case["family"] === "matrix_chain", chainAudit[case], mpsAudit[case]]];
    save[];
], manifest["cases"]];
result["metadata"] = Append[result["metadata"], "wl_peak_memory_bytes" -> MaxMemoryUsed[]];
save[];
Exit[Boole[AnyTrue[result["records"], #["status"] =!= "ok" &] ||
    AnyTrue[result["observations"], ! TrueQ[#["outputs_correct"]] &]]];
End[];
