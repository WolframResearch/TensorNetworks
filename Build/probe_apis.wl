#!/usr/bin/env wolframscript

PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks"];
Quiet @ Needs["Wolfram`TensorNetworks`"];

tn = RandomTensorNetwork[{4, 5}, 3];
Print["==== tn properties ===="];
Print["Properties: ", Short[tn["Properties"], 5]];
Print["tn[\"Hypergraph\"] -> ", Quiet @ Check[tn["Hypergraph"], "FAILED"]];
Print["tn[\"Hyperedges\"] -> ", Short[Quiet @ Check[tn["Hyperedges"], "FAILED"], 3]];
Print["tn[\"Vertices\"] -> ", Short[Quiet @ Check[tn["Vertices"], "FAILED"], 3]];

Print[];
Print["==== PathIndexContractions ===="];
path = GreedyContractionPath[tn];
Print["path = ", Short[path, 3]];
Print["PathIndexContractions[path, tn] -> ", Short[Quiet @ Check[PathIndexContractions[path, tn], "FAILED"], 3]];
Print["PathIndexContractions[path, {3}] -> ", Short[Quiet @ Check[PathIndexContractions[path, {3}], "FAILED"], 3]];

Print[];
Print["==== ToTensorNetworkGraph Method options ===="];
Print["Options[ToTensorNetworkGraph]: ", Quiet @ Options[ToTensorNetworkGraph]];
Print["Method -> \"Symbolic\": ", Short[Quiet @ Check[ToTensorNetworkGraph[tn, Method -> "Symbolic"], "FAILED"], 3]];

Quit[0]
