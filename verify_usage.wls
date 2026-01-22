#!/usr/bin/env wolframscript
(* Test script to verify usage messages display correctly *)

(* Load the package *)
PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks"];
Get["Wolfram`TensorNetworks`"];

Print["\\n========================================"];
Print["Package Loaded Successfully!"];
Print["========================================\\n"];

(* Test a few key functions *)
Print["=== TensorNetwork ==="];
Print["?TensorNetwork"];
Print[TensorNetwork::usage];
Print[""];

Print["=== RandomTensorNetwork ==="];
Print[RandomTensorNetwork::usage];
Print[""];

Print["=== MPSCanonicalForm ==="];
Print[MPSCanonicalForm::usage];
Print[""];

Print["=== EinsteinSummation ==="];
Print[EinsteinSummation::usage];
Print[""];

Print["=== TensorNetworkContract ==="];
Print[TensorNetworkContract::usage];
Print[""];

Print["\\n========================================"];
Print["Verification Complete!");
Print["========================================"];
