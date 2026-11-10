Begin["DenseVerification`"];
here = Environment["TN_PROBE_HERE"];
PacletDirectoryLoad[FileNameJoin[{here, ".dependencies", "Arrays", "Arrays"}]];
PacletDirectoryLoad[FileNameJoin[{DirectoryName[DirectoryName[here]], "TensorNetworks"}]];
Needs["Wolfram`TensorNetworks`"];
apiOptions = Options[TensorNetworkContract];
guardNames = Names["Wolfram`TensorNetworks`*"];
definitionHash[name_] := ToExpression[name, InputForm,
    Function[s, Hash[{DownValues[s], UpValues[s], SubValues[s], Attributes[s], Options[s]}, "SHA256", "HexString"], HoldAll]];
guardsBefore = AssociationMap[definitionHash, guardNames];
started = AbsoluteTime[];
Get[FileNameJoin[{here, "workloads", "dense-execution-2026-10-26", "probe.wls"}]];
guardsAfter = AssociationMap[definitionHash, guardNames];
guardReport = <|"version" -> $Version, "system" -> $SystemID,
    "api_options" -> ToString[apiOptions, InputForm],
    "function_guards_before" -> guardsBefore, "function_guards_after" -> guardsAfter,
    "all_preexisting_function_definitions_unchanged" -> (guardsBefore === guardsAfter),
    "probe_total_seconds_excluding_wrapper_load" -> (AbsoluteTime[] - started),
    "probe_sha256" -> FileHash[FileNameJoin[{here, "workloads", "dense-execution-2026-10-26", "probe.wls"}], "SHA256", "HexString"],
    "reference" -> DenseExecutionProbe`case["reference"],
    "path_hash" -> Hash[DenseExecutionProbe`path, "SHA256", "HexString"],
    "native_environment" -> AssociationMap[Environment, {"OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "BLIS_NUM_THREADS"}],
    "parallel_options" -> ToString[SystemOptions["ParallelOptions"], InputForm],
    "arrays_paclet" -> ToString[PacletFind["Wolfram/Arrays"], InputForm]|>;
Export[Environment["TN_VERIFY_GUARDS"], guardReport, "RawJSON"];
Echo[KeyTake[guardReport, {"api_options", "all_preexisting_function_definitions_unchanged", "probe_sha256", "reference"}]];
End[];
