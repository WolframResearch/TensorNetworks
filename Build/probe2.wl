#!/usr/bin/env wolframscript

PacletDirectoryLoad["/Users/mohammadb/Documents/GitHub/TensorNetworks/TensorNetworks"];
Quiet @ Needs["Wolfram`TensorNetworks`"];

tn = RandomTensorNetwork[{4, 5}, 3];
path = GreedyContractionPath[tn];

Print["path = ", path];
Print["tn[\"Hyperedges\"] = ", tn["Hyperedges"]];
Print["tn[\"Indices\"] = ", tn["Indices"]];

Print[];
Print["PathIndexContractions[path, tn[\"Hyperedges\"]] = ",
  Quiet @ Check[PathIndexContractions[path, tn["Hyperedges"]], "FAILED"]];
Print["PathIndexContractions[path, tn[\"Indices\"]] = ",
  Quiet @ Check[PathIndexContractions[path, tn["Indices"]], "FAILED"]];
Print["PathIndexContractions[path] = ",
  Quiet @ Check[PathIndexContractions[path], "FAILED"]];

Quit[0]
