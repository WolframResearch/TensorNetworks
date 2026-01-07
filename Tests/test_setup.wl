(* Tests/test_setup.wl *)

(* Ensure we are in a valid directory context *)
root = DirectoryName @ DirectoryName @ $InputFileName;
If[root === "", root = Directory[]];

(* Load the TensorNetworks paclet from source *)
PacletDirectoryLoad[FileNameJoin[{root, "TensorNetworks"}]];
Needs["Wolfram`TensorNetworks`"];