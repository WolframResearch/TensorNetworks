#!/usr/bin/env wolframscript

PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks"];
Quiet @ Needs["Wolfram`TensorNetworks`"];

tn = RandomTensorNetwork[{4, 5}, 3];
Print["plain:    ", Quiet @ Check[Head @ ToTensorNetworkGraph[tn], "FAILED"]];
Print["sym:      ", Quiet @ Check[Head @ ToTensorNetworkGraph[tn, Method -> Symbolic], "FAILED"]];
Print["sym str:  ", Quiet @ Check[Head @ ToTensorNetworkGraph[tn, Method -> "Symbolic"], "FAILED"]];

Quit[0]
