(* TensorNetworkAdd and TensorNetworkDelete: after each change the network is contracted
   and compared with the value written out as an explicit sum *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* Integer entries: every contraction must match its explicit sum exactly *)
SeedRandom[42];

ri[d__] := RandomInteger[{-3, 3}, {d}]

(* Square matrices: a leg wired to the wrong label still has the right dimension,
   so only the value can tell *)
{ma, mb, mc} = {ri[3, 3], ri[3, 3], ri[3, 3]};
{pm, qm} = {ri[2, 3], ri[3, 4]};
{uv, vv, wv} = {ri[2], ri[3], ri[4]};


(* ------------------------------------------------------------------ *)
(* TensorNetwork form                                                  *)
(* ------------------------------------------------------------------ *)

(* Output Cycles[{{1, 2}}] swaps the free labels {1, 3} to {3, 1} *)
swappedPair = TensorNetwork[{pm, qm}, {{1, 2}, {2, 3}}, Cycles[{{1, 2}}]];

VerificationTest[
    {swappedPair["FreeIndices"], TensorNetworkContract[swappedPair]},
    {{3, 1}, Table[Sum[pm[[i, j]] qm[[j, k]], {j, 3}], {k, 4}, {i, 2}]},
    TestID -> "Contract_SwappedOutput"
]

(* A tensor on fresh labels appends its legs after the existing output *)
VerificationTest[
    With[{t = ri[5, 6]},
        With[{added = TensorNetworkAdd[swappedPair, t, {4, 5}]},
            {
                added["FreeIndices"],
                TensorNetworkContract[added] ===
                    Table[Sum[pm[[i, j]] qm[[j, k]], {j, 3}] t[[l, m]], {k, 4}, {i, 2}, {l, 5}, {m, 6}]
            }
        ]
    ],
    {{3, 1, 4, 5}, True},
    TestID -> "Add_FreshLabels_OuterProduct"
]

(* A tensor on an open label contracts it away *)
VerificationTest[
    With[{t = ri[4, 2]},
        With[{added = TensorNetworkAdd[swappedPair, t, {3, 6}]},
            {
                added["FreeIndices"],
                TensorNetworkContract[added] === Table[Sum[pm[[i, j]] qm[[j, k]] t[[k, m]], {j, 3}, {k, 4}], {i, 2}, {m, 2}]
            }
        ]
    ],
    {{1, 6}, True},
    TestID -> "Add_OpenLabel_Contracts"
]

(* Square matrices in a chain: wiring a new leg to the other open label would transpose the result *)
VerificationTest[
    With[{
        net = TensorNetworkAdd[TensorNetworkAdd[TensorNetwork[{ma}, {{1, 2}}, {1, 2}], mb, {2, 3}], mc, {3, 4}]
    },
        {net["FreeIndices"], TensorNetworkContract[net] === Table[Sum[ma[[i, j]] mb[[j, k]] mc[[k, l]], {j, 3}, {k, 3}], {i, 3}, {l, 3}]}
    ],
    {{1, 4}, True},
    TestID -> "Add_ChainOfAdds"
]

(* Slot order matters: {3, 2} is the transpose of {2, 3} *)
VerificationTest[
    TensorNetworkContract[TensorNetworkAdd[TensorNetwork[{ma}, {{1, 2}}, {1, 2}], mb, {3, 2}]],
    Table[Sum[ma[[i, j]] mb[[k, j]], {j, 3}], {i, 3}, {k, 3}],
    TestID -> "Add_SlotOrderIsKept"
]

(* Automatic output stays Automatic and lists the free labels in order *)
VerificationTest[
    With[{added = TensorNetworkAdd[TensorNetwork[{pm}, {{1, 2}}], qm, {2, 3}]},
        {added["Output"], TensorNetworkContract[added]}
    ],
    {Automatic, Table[Sum[pm[[i, j]] qm[[j, k]], {j, 3}], {i, 2}, {k, 4}]},
    TestID -> "Add_AutomaticOutputPropagates"
]

(* Pairing every leg leaves a scalar: the full inner product *)
VerificationTest[
    With[{t = ri[2, 3]},
        TensorNetworkContract[TensorNetworkAdd[TensorNetwork[{pm}, {{1, 2}}, {1, 2}], t, {1, 2}]] ===
            Sum[pm[[i, j]] t[[i, j]], {i, 2}, {j, 3}]
    ],
    True,
    TestID -> "Add_FullContraction_Scalar"
]

VerificationTest[
    TensorNetworkAdd[swappedPair, ri[2, 2], {7}],
    $Failed,
    {TensorNetworkAdd::rank},
    TestID -> "Add_RankMismatch_Fails"
]

(* Three vectors under output Cycles[{{1, 3}}]: labels {1, 2, 3} read as {3, 2, 1} *)
threeVectors = TensorNetwork[{uv, vv, wv}, {{1}, {2}, {3}}, Cycles[{{1, 3}}]];

VerificationTest[
    With[{deleted = TensorNetworkDelete[threeVectors, 2]},
        {deleted["FreeIndices"], TensorNetworkContract[deleted]}
    ],
    {{3, 1}, Table[wv[[k]] uv[[i]], {k, 4}, {i, 2}]},
    TestID -> "Delete_Middle"
]

VerificationTest[
    With[{deleted = TensorNetworkDelete[threeVectors, 1]},
        {deleted["FreeIndices"], TensorNetworkContract[deleted]}
    ],
    {{3, 2}, Table[wv[[k]] vv[[j]], {k, 4}, {j, 3}]},
    TestID -> "Delete_First"
]

(* Deleting the default, last tensor *)
VerificationTest[
    With[{deleted = TensorNetworkDelete[threeVectors]},
        {deleted["FreeIndices"], TensorNetworkContract[deleted]}
    ],
    {{2, 1}, Table[vv[[j]] uv[[i]], {j, 3}, {i, 2}]},
    TestID -> "Delete_DefaultIsLast"
]

(* Deleting the middle of a chain opens the labels it contracted *)
VerificationTest[
    With[{deleted = TensorNetworkDelete[TensorNetwork[{ma, mb, mc}, {{1, 2}, {2, 3}, {3, 4}}], 2]},
        {deleted["FreeIndices"], TensorNetworkContract[deleted]}
    ],
    {{1, 2, 3, 4}, Table[ma[[i, j]] mc[[k, l]], {i, 3}, {j, 3}, {k, 3}, {l, 3}]},
    TestID -> "Delete_ChainMiddle_OpensLabels"
]

VerificationTest[
    With[{back = TensorNetworkDelete[TensorNetworkAdd[swappedPair, ri[5, 6], {4, 5}], -1]},
        {back["FreeIndices"], TensorNetworkContract[back]}
    ],
    {{3, 1}, Table[Sum[pm[[i, j]] qm[[j, k]], {j, 3}], {k, 4}, {i, 2}]},
    TestID -> "AddThenDelete_RestoresValue"
]


(* ------------------------------------------------------------------ *)
(* Graph form                                                          *)
(* ------------------------------------------------------------------ *)

(* The graph of pm.qm has open legs: the first slot of pm and the second of qm *)
pairGraph = ToTensorNetworkGraph[TensorNetwork[{pm, qm}, {{1, 2}, {2, 3}}]];

(* Without legs, each slot takes the first open leg of its dimension: the 4 x 5 tensor joins qm *)
VerificationTest[
    With[{t = ri[4, 5]},
        With[{added = TensorNetworkAdd[pairGraph, t]},
            {VertexCount[added], TensorNetworkContract[added] === Table[Sum[pm[[i, j]] qm[[j, k]] t[[k, m]], {j, 3}, {k, 4}], {i, 2}, {m, 5}]}
        ]
    ],
    {3, True},
    TestID -> "GraphAdd_AutomaticLegs"
]

(* An explicit leg: the new tensor's first slot joins the open slot of pm; free legs keep the graph's order *)
VerificationTest[
    With[{t = ri[2, 2]},
        With[{added = TensorNetworkAdd[pairGraph, t, {Superscript[1, 1]}]},
            TensorNetworkContract[added] === Table[Sum[pm[[i, j]] qm[[j, k]] t[[i, m]], {i, 2}, {j, 3}], {k, 4}, {m, 2}]
        ]
    ],
    True,
    TestID -> "GraphAdd_ExplicitLeg"
]

VerificationTest[
    With[{back = TensorNetworkDelete[TensorNetworkAdd[pairGraph, ri[4, 5]], -1]},
        {VertexCount[back], TensorNetworkContract[back]}
    ],
    {2, Table[Sum[pm[[i, j]] qm[[j, k]], {j, 3}], {i, 2}, {k, 4}]},
    TestID -> "GraphAddThenDelete_RestoresValue"
]

(* Deleting pm leaves qm alone, with its first slot now open *)
VerificationTest[
    TensorNetworkContract[TensorNetworkDelete[pairGraph, 1]],
    qm,
    TestID -> "GraphDelete_First"
]
