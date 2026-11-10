Begin["PEPSAPIVerifier`"];
out = "/Users/mohammadb/Documents/GitHub/TensorNetworks/Benchmarks/performance/results/peps-verification-round1";
usage = Association @ Map[Function[s, ToString[Unevaluated[s], InputForm] -> ToString[Information[s, "Usage"], InputForm], HoldAll], {FileHash, BinaryReadList, ArrayReshape, MemoryConstrained, TimeConstrained, MaxMemoryUsed, ClearSystemCache, SetSystemOptions}];
Echo[usage];
Export[FileNameJoin[{out, "builtin-usage.json"}], usage, "RawJSON"];
End[];
