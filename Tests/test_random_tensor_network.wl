(* Tests/test_random_tensor_network.wl *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

VerificationTest[
    rtnAuto = RandomTensorNetwork[{10, 15}, 2, 4];
    tensorsAuto = rtnAuto["Tensors"];
    AllTrue[Flatten[tensorsAuto], Element[#, Reals] &],
    True,
    TestID -> "RandomTensorNetwork_Real_Default"
]

(* Note: There is a tiny chance RandomComplex returns a real number, but across many tensors it should be complex *)
VerificationTest[
    rtnComplex = RandomTensorNetwork[{10, 15}, 2, 4, Method -> "Complex"];
    tensorsComplex = rtnComplex["Tensors"];
    AnyTrue[Flatten[tensorsComplex], !Element[#, Reals] &],
    True,
    TestID -> "RandomTensorNetwork_Complex"
]

VerificationTest[
    rtnReal = RandomTensorNetwork[{10, 15}, 2, 4, Method -> "Real"];
    tensorsReal = rtnReal["Tensors"];
    AllTrue[Flatten[tensorsReal], Element[#, Reals] &],
    True,
    TestID -> "RandomTensorNetwork_Real_Explicit"
]
