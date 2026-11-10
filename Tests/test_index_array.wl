(* The IndexArray sub-context: named-index contraction, index juggling with a metric, and the
   MetricTensor catalog. Every value is checked against an answer built here, outside the
   paclet: explicit Sum/Table over components, plain Inverse/Det/Dot, and textbook metric
   components. Sections E and F hold the cases of bugs that were found and fixed; each one fails
   on the code before its fix. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* The sub-context is not put on $ContextPath, so that this file's names cannot shadow symbols
   in the other test files sharing the kernel: its functions are reached through these aliases. *)
Block[{$ContextPath}, Needs["Wolfram`TensorNetworks`IndexArray`"]];
iaIndexArray = Wolfram`TensorNetworks`IndexArray`IndexArray;
iaIndexTensor = Wolfram`TensorNetworks`IndexArray`IndexTensor;
iaIndexTensorQ = Wolfram`TensorNetworks`IndexArray`IndexTensorQ;
iaIndexContract = Wolfram`TensorNetworks`IndexArray`IndexContract;
iaMetricTensor = Wolfram`TensorNetworks`IndexArray`MetricTensor;
iaMetricTensorQ = Wolfram`TensorNetworks`IndexArray`MetricTensorQ;
iaShape = Wolfram`TensorNetworks`IndexArray`Shape;
iaDimension = Wolfram`TensorNetworks`IndexArray`Dimension;

(* Contracted results are inactive expressions; this is the evaluated array *)
iaValue[x_] := Activate[x["Tensor"]];

(* True when every entry of a symbolic difference simplifies to zero *)
iaZeroQ[d_] := AllTrue[Flatten[{Simplify[d]}], TrueQ[# == 0] &];

(* A random integer array; the seed fixes it *)
iaRandom[seed_, dims_] := BlockRandom[SeedRandom[seed]; RandomInteger[{-9, 9}, dims]];

(* A non-diagonal metric whose components depend on the coordinates iaX, iaY *)
iaFieldMetric = {{2 + iaX^2, iaX iaY}, {iaX iaY, 3 + iaY^2}};
iaFieldMetricArray := iaMetricTensor[iaFieldMetric, {iaX, iaY}]["IndexArray"];


(* ------------------------------------------------------------------ *)
(* A. IndexContract on IndexArrays against explicit sums               *)
(* ------------------------------------------------------------------ *)

(* A^{p}_{q}^{r} B_{r}^{q}^{s}, dimensions {2,3,4} and {4,3,5}: sum over q and r *)
VerificationTest[
    With[{a = iaRandom[101, {2, 3, 4}], b = iaRandom[102, {4, 3, 5}]},
        With[{c = iaIndexContract[{
                iaIndexArray[a, iaShape[{2, 3, 4}, {iaP, -iaQ, iaR}]],
                iaIndexArray[b, iaShape[{4, 3, 5}, {-iaR, iaQ, iaS}]]
            }]},
            {c["Names"], c["Signs"], iaValue[c] === Table[Sum[a[[p, q, r]] b[[r, q, s]], {q, 3}, {r, 4}], {p, 2}, {s, 5}]}
        ]
    ],
    {{"iaP", "iaS"}, {1, 1}, True},
    TestID -> "IndexContract_TwoArraysMixedVariance"
]

(* The same contraction with the output order forced to {s, p} *)
VerificationTest[
    With[{a = iaRandom[101, {2, 3, 4}], b = iaRandom[102, {4, 3, 5}]},
        With[{c = iaIndexContract[{
                iaIndexArray[a, iaShape[{2, 3, 4}, {iaP, -iaQ, iaR}]],
                iaIndexArray[b, iaShape[{4, 3, 5}, {-iaR, iaQ, iaS}]]
            }, {"iaS", "iaP"}]},
            {c["Names"], iaValue[c] === Table[Sum[a[[p, q, r]] b[[r, q, s]], {q, 3}, {r, 4}], {s, 5}, {p, 2}]}
        ]
    ],
    {{"iaS", "iaP"}, True},
    TestID -> "IndexContract_ExplicitOutputOrder"
]

(* A chain of three arrays, A^{i}_{j} B^{j k}_{l} C^{l m}_{k}: sum over j, k, l *)
VerificationTest[
    With[{a = iaRandom[111, {2, 3}], b = iaRandom[112, {3, 4, 5}], c = iaRandom[113, {5, 2, 4}]},
        With[{r = iaIndexContract[{
                iaIndexArray[a, iaShape[{2, 3}, {iaI, -iaJ}]],
                iaIndexArray[b, iaShape[{3, 4, 5}, {iaJ, iaK, -iaL}]],
                iaIndexArray[c, iaShape[{5, 2, 4}, {iaL, iaM, -iaK}]]
            }]},
            {r["Names"], iaValue[r] === Table[Sum[a[[i, j]] b[[j, k, l]] c[[l, m, k]], {j, 3}, {k, 4}, {l, 5}], {i, 2}, {m, 2}]}
        ]
    ],
    {{"iaI", "iaM"}, True},
    TestID -> "IndexContract_ThreeArrayChain"
]

(* A trace inside one array, T^{i j}_{i}, dimensions {3,4,3} *)
VerificationTest[
    With[{t = iaRandom[121, {3, 4, 3}]},
        With[{r = iaIndexContract[iaIndexArray[t, iaShape[{3, 4, 3}, {iaI, iaJ, -iaI}]]]},
            {r["Names"], iaValue[r] === Table[Sum[t[[i, j, i]], {i, 3}], {j, 4}]}
        ]
    ],
    {{"iaJ"}, True},
    TestID -> "IndexContract_SingleArrayTrace"
]

(* No shared name: the outer product u^{i} v_{j} *)
VerificationTest[
    With[{u = iaRandom[131, {3}], v = iaRandom[132, {4}]},
        With[{r = iaIndexContract[{iaIndexArray[u, iaShape[{3}, {iaI}]], iaIndexArray[v, iaShape[{4}, {-iaJ}]]}]},
            {r["Names"], r["Signs"], iaValue[r] === Table[u[[i]] v[[j]], {i, 3}, {j, 4}]}
        ]
    ],
    {{"iaI", "iaJ"}, {1, -1}, True},
    TestID -> "IndexContract_OuterProduct"
]

(* g^{ab} g_{bc} = delta^a_c, with g not symmetric so that a transposed inverse would show *)
VerificationTest[
    With[{g = {{2, 1, 0}, {-1, 3, 1}, {0, 2, 1}}},
        With[{r = iaIndexContract[{
                Inverse[iaIndexArray[g, iaShape[{3, 3}, {-iaA, -iaB}]]],
                iaIndexArray[g, iaShape[{3, 3}, {-iaB, -iaC}]]
            }]},
            {r["Names"], r["Signs"], iaValue[r]}
        ]
    ],
    {{"iaA", "iaC"}, {1, -1}, IdentityMatrix[3]},
    TestID -> "IndexContract_InverseTimesMetricIsDelta"
]


(* ------------------------------------------------------------------ *)
(* B. Permuting, slicing and adding IndexArrays                       *)
(* ------------------------------------------------------------------ *)

(* Juggling to the order (r, p, q) keeps each sign and moves the data with its axis *)
VerificationTest[
    With[{a = iaRandom[141, {2, 3, 4}]},
        With[{j = iaIndexArray[a, iaShape[{2, 3, 4}, {iaP, -iaQ, iaR}]][iaR, iaP, -iaQ]},
            {j["Names"], j["Signs"], Normal[iaValue[j]] === Table[a[[p, q, r]], {r, 4}, {p, 2}, {q, 3}]}
        ]
    ],
    {{"iaR", "iaP", "iaQ"}, {1, 1, -1}, True},
    TestID -> "IndexJuggling_PermuteArray"
]

(* Transpose by {3, 1, 2} sends axis k to position perm[[k]]: data and names together *)
VerificationTest[
    With[{a = iaRandom[142, {2, 3, 4}]},
        With[{t = Transpose[iaIndexArray[a, iaShape[{2, 3, 4}, {iaP, -iaQ, iaR}]], {3, 1, 2}]},
            {t["Names"], t["Signs"], Normal[t["Tensor"]] === Table[a[[p, q, r]], {q, 3}, {r, 4}, {p, 2}]}
        ]
    ],
    {{"iaQ", "iaR", "iaP"}, {-1, 1, 1}, True},
    TestID -> "IndexArray_TransposeList"
]

(* Integer slices: one index fixed, then two *)
VerificationTest[
    With[{a = iaRandom[143, {2, 3, 4}]},
        With[{ia = iaIndexArray[a, iaShape[{2, 3, 4}, {iaP, -iaQ, iaR}]]},
            {
                ia[[2]]["Signs"], Normal[ia[[2]]["Tensor"]] === Table[a[[2, q, r]], {q, 3}, {r, 4}],
                ia[[1, 3]]["Signs"], Normal[ia[[1, 3]]["Tensor"]] === Table[a[[1, 3, r]], {r, 4}]
            }
        ]
    ],
    {{-1, 1}, True, {1}, True},
    TestID -> "IndexPart_IntegerSlices"
]

(* A^{p q} + B^{q p}: the second operand is permuted before adding *)
VerificationTest[
    With[{a = iaRandom[144, {2, 3}], b = iaRandom[145, {3, 2}]},
        With[{s = iaIndexArray[a, iaShape[{2, 3}, {iaP, iaQ}]] + iaIndexArray[b, iaShape[{3, 2}, {iaQ, iaP}]]},
            {s["Names"], Normal[iaValue[s]] === Table[a[[p, q]] + b[[q, p]], {p, 2}, {q, 3}]}
        ]
    ],
    {{"iaP", "iaQ"}, True},
    TestID -> "IndexArray_PlusPermutesOperand"
]


(* ------------------------------------------------------------------ *)
(* C. Raising and lowering with a non-constant, non-diagonal metric   *)
(* ------------------------------------------------------------------ *)

(* v_i = g_{ij} v^j *)
VerificationTest[
    With[{v = iaIndexTensor[iaIndexArray[{iaV1, iaV2}, iaShape[{iaDimension[2, iaI]}]], iaFieldMetricArray]},
        With[{lo = v[-iaI]},
            {lo["Signs"], iaZeroQ[iaValue[lo] - Table[Sum[iaFieldMetric[[i, j]] {iaV1, iaV2}[[j]], {j, 2}], {i, 2}]]}
        ]
    ],
    {{-1}, True},
    TestID -> "IndexJuggling_LowerVector"
]

(* w^i = g^{ij} w_j, with g^{ij} from plain Inverse *)
VerificationTest[
    With[{w = iaIndexTensor[iaIndexArray[{iaW1, iaW2}, iaShape[{iaDimension[-2, iaI]}]], iaFieldMetricArray], gInv = Inverse[iaFieldMetric]},
        With[{up = w[iaI]},
            {up["Signs"], iaZeroQ[iaValue[up] - Table[Sum[gInv[[i, j]] {iaW1, iaW2}[[j]], {j, 2}], {i, 2}]]}
        ]
    ],
    {{1}, True},
    TestID -> "IndexJuggling_RaiseCovector"
]

(* Lowering then raising gives back the original components *)
VerificationTest[
    With[{v = iaIndexTensor[iaIndexArray[{iaV1, iaV2}, iaShape[{iaDimension[2, iaI]}]], iaFieldMetricArray]},
        With[{back = v[-iaI][iaI]},
            {back["Signs"], iaZeroQ[iaValue[back] - {iaV1, iaV2}]}
        ]
    ],
    {{1}, True},
    TestID -> "IndexJuggling_LowerThenRaiseIsIdentity"
]

(* A^{a}_{b}: lower a gives g_{ac} A^{c}_{b}; raise b gives A^{a}_{c} g^{cb} *)
VerificationTest[
    With[{t = Array[Subscript[iaT, ##] &, {2, 2}], g = iaFieldMetric, gInv = Inverse[iaFieldMetric]},
        With[{m = iaIndexTensor[iaIndexArray[t, iaShape[{2, 2}, {iaA, -iaB}], {iaX, iaY}], iaFieldMetricArray]},
            {
                m[-iaA, -iaB]["Signs"],
                iaZeroQ[iaValue[m[-iaA, -iaB]] - Table[Sum[g[[a, c]] t[[c, b]], {c, 2}], {a, 2}, {b, 2}]],
                m[iaA, iaB]["Signs"],
                iaZeroQ[iaValue[m[iaA, iaB]] - Table[Sum[t[[a, c]] gInv[[c, b]], {c, 2}], {a, 2}, {b, 2}]]
            }
        ]
    ],
    {{-1, -1}, True, {1, 1}, True},
    TestID -> "IndexJuggling_RankTwoLowerAndRaise"
]

(* T^{a}_{b}^{c}, dimensions {2,3,2}, metric on slots 1 and 3 only: lower c *)
VerificationTest[
    With[{t = Array[Subscript[iaT, ##] &, {2, 3, 2}], g = iaFieldMetric},
        With[{m = iaIndexTensor[iaIndexArray[t, iaShape[{2, 3, 2}, {iaA, -iaB, iaC}], {iaX, iaY}], {{1, 3} -> iaFieldMetricArray}]},
            {
                m[iaA, -iaB, -iaC]["Signs"],
                iaZeroQ[iaValue[m[iaA, -iaB, -iaC]] - Table[Sum[g[[c, d]] t[[a, b, d]], {d, 2}], {a, 2}, {b, 3}, {c, 2}]]
            }
        ]
    ],
    {{1, -1, -1}, True},
    TestID -> "IndexJuggling_UnequalDimensionsLowerOneSlot"
]

(* u^i w^i: the metric is inserted, giving u.g.w; u_i w_i gives u.g^{-1}.w; u^i w_i needs none *)
VerificationTest[
    With[{
        uUp = iaIndexTensor[iaIndexArray[{iaU1, iaU2}, iaShape[{iaDimension[2, iaI]}]], iaFieldMetricArray],
        wUp = iaIndexTensor[iaIndexArray[{iaW1, iaW2}, iaShape[{iaDimension[2, iaI]}]], iaFieldMetricArray],
        uDn = iaIndexTensor[iaIndexArray[{iaU1, iaU2}, iaShape[{iaDimension[-2, iaI]}]], iaFieldMetricArray],
        wDn = iaIndexTensor[iaIndexArray[{iaW1, iaW2}, iaShape[{iaDimension[-2, iaI]}]], iaFieldMetricArray],
        u = {iaU1, iaU2}, w = {iaW1, iaW2}, g = iaFieldMetric, gInv = Inverse[iaFieldMetric]
    },
        {
            iaZeroQ[iaValue[iaIndexContract[{uUp, wUp}]] - Sum[u[[i]] g[[i, j]] w[[j]], {i, 2}, {j, 2}]],
            iaZeroQ[iaValue[iaIndexContract[{uDn, wDn}]] - Sum[u[[i]] gInv[[i, j]] w[[j]], {i, 2}, {j, 2}]],
            iaZeroQ[iaValue[iaIndexContract[{uUp, wDn}]] - Sum[u[[i]] w[[i]], {i, 2}]]
        }
    ],
    {True, True, True},
    TestID -> "IndexContract_MetricInsertedForEqualVariance"
]

(* The same through a catalog metric: lower a Schwarzschild 4-vector, then raise it back *)
VerificationTest[
    With[{
        sw = iaMetricTensor["Schwarzschild"[iaMass], {iaCt, iaCr, iaCth, iaCph}],
        v = {iaV1, iaV2, iaV3, iaV4},
        g = DiagonalMatrix[{-(1 - 2 iaMass / iaCr), 1 / (1 - 2 iaMass / iaCr), iaCr^2, iaCr^2 Sin[iaCth]^2}]
    },
        With[{vt = iaIndexTensor[iaIndexArray[v, iaShape[{iaDimension[4, iaMu]}], {iaCt, iaCr, iaCth, iaCph}], sw["IndexArray"]]},
            {
                iaZeroQ[iaValue[vt[-iaMu]] - Table[Sum[g[[m, n]] v[[n]], {n, 4}], {m, 4}]],
                iaZeroQ[iaValue[vt[-iaMu][iaMu]] - v]
            }
        ]
    ],
    {True, True},
    TestID -> "IndexJuggling_SchwarzschildRoundTrip"
]


(* ------------------------------------------------------------------ *)
(* D. The MetricTensor catalog against textbook formulas              *)
(* ------------------------------------------------------------------ *)

VerificationTest[
    With[{mk = iaMetricTensor["Minkowski"]},
        {iaMetricTensorQ[mk], mk["Matrix"], mk["Determinant"], mk["Signature"], mk["LorentzianQ"], Inverse[mk]["Matrix"]}
    ],
    {True, DiagonalMatrix[{-1, 1, 1, 1}], -1, {3, 1, 0}, True, DiagonalMatrix[{-1, 1, 1, 1}]},
    TestID -> "MetricTensor_Minkowski"
]

VerificationTest[
    With[{eu = iaMetricTensor["Euclidean"]},
        {eu["Matrix"], eu["Determinant"], eu["Signature"], eu["RiemannianQ"]}
    ],
    {IdentityMatrix[3], 1, {3, 0, 0}, True},
    TestID -> "MetricTensor_Euclidean"
]

(* ds^2 = -(1 - 2M/r) dt^2 + dr^2/(1 - 2M/r) + r^2 dtheta^2 + r^2 sin^2(theta) dphi^2 *)
VerificationTest[
    With[{
        sw = iaMetricTensor["Schwarzschild"[iaMass], {iaCt, iaCr, iaCth, iaCph}],
        f = 1 - 2 iaMass / iaCr
    },
        {
            iaZeroQ[sw["Matrix"] - DiagonalMatrix[{-f, 1 / f, iaCr^2, iaCr^2 Sin[iaCth]^2}]],
            iaZeroQ[sw["Determinant"] + iaCr^4 Sin[iaCth]^2],
            Inverse[sw]["Indices"],
            iaZeroQ[Inverse[sw]["Matrix"] - DiagonalMatrix[{-1 / f, f, 1 / iaCr^2, 1 / (iaCr^2 Sin[iaCth]^2)}]],
            sw["Signature"]
        }
    ],
    {True, True, {True, True}, True, {3, 1, 0}},
    TestID -> "MetricTensor_Schwarzschild"
]

(* Boyer-Lindquist Kerr with a = J/M, Sigma = r^2 + a^2 cos^2, Delta = r^2 - 2 M r + a^2 *)
VerificationTest[
    Block[{a, sig, del, r = iaCr, th = iaCth, m = iaMass},
        a = iaSpin / m;
        sig = r^2 + a^2 Cos[th]^2;
        del = r^2 - 2 m r + a^2;
        With[{kerr = iaMetricTensor["Kerr"[iaMass, iaSpin], {iaCt, iaCr, iaCth, iaCph}]},
            {
                iaZeroQ[kerr["Matrix"] - {
                    {-(1 - 2 m r / sig), 0, 0, -2 m a r Sin[th]^2 / sig},
                    {0, sig / del, 0, 0},
                    {0, 0, sig, 0},
                    {-2 m a r Sin[th]^2 / sig, 0, 0, (r^2 + a^2 + 2 m r a^2 Sin[th]^2 / sig) Sin[th]^2}
                }],
                iaZeroQ[kerr["Determinant"] + sig^2 Sin[th]^2],
                iaZeroQ[Inverse[kerr]["Matrix"] - {
                    {-((r^2 + a^2)^2 - a^2 del Sin[th]^2) / (sig del), 0, 0, -2 m a r / (sig del)},
                    {0, del / sig, 0, 0},
                    {0, 0, 1 / sig, 0},
                    {-2 m a r / (sig del), 0, 0, (del - a^2 Sin[th]^2) / (sig del Sin[th]^2)}
                }]
            }
        ]
    ],
    {True, True, True},
    TestID -> "MetricTensor_Kerr"
]

(* FLRW: -dt^2 + a(t)^2 (dr^2/(1 - k r^2) + r^2 dOmega^2) *)
VerificationTest[
    With[{fl = iaMetricTensor["FLRW"[iaCurv, iaScale], {iaCt, iaCr, iaCth, iaCph}], s = iaScale[iaCt]},
        {
            iaZeroQ[fl["Matrix"] - DiagonalMatrix[{-1, s^2 / (1 - iaCurv iaCr^2), s^2 iaCr^2, s^2 iaCr^2 Sin[iaCth]^2}]],
            iaZeroQ[fl["Determinant"] + s^6 iaCr^4 Sin[iaCth]^2 / (1 - iaCurv iaCr^2)],
            fl["Signature"]
        }
    ],
    {True, True, {3, 1, 0}},
    TestID -> "MetricTensor_FLRW"
]

(* Ingoing Eddington-Finkelstein and Gullstrand-Painleve charts of Schwarzschild, and
   Reissner-Nordstrom: all share det g = -r^4 sin^2(theta) *)
VerificationTest[
    With[{
        ef = iaMetricTensor["IngoingEddingtonFinkelstein"[iaMass], {iaCv, iaCr, iaCth, iaCph}],
        gp = iaMetricTensor["IngoingGullstrandPainleve"[iaMass], {iaCt, iaCr, iaCth, iaCph}],
        rn = iaMetricTensor["ReissnerNordstrom"[iaMass, iaCharge], {iaCt, iaCr, iaCth, iaCph}],
        f = 1 - 2 iaMass / iaCr
    },
        {
            iaZeroQ[ef["Matrix"] - {{-f, 1, 0, 0}, {1, 0, 0, 0}, {0, 0, iaCr^2, 0}, {0, 0, 0, iaCr^2 Sin[iaCth]^2}}],
            iaZeroQ[gp["Matrix"] - {{-f, Sqrt[2 iaMass / iaCr], 0, 0}, {Sqrt[2 iaMass / iaCr], 1, 0, 0}, {0, 0, iaCr^2, 0}, {0, 0, 0, iaCr^2 Sin[iaCth]^2}}],
            iaZeroQ[{ef["Determinant"], gp["Determinant"], rn["Determinant"]} + iaCr^4 Sin[iaCth]^2]
        }
    ],
    {True, True, True},
    TestID -> "MetricTensor_SchwarzschildChartsDeterminant"
]

(* A metric given as a matrix: the inverse is plain Inverse, and g^{ab} g_{bc} = delta *)
VerificationTest[
    With[{g = iaMetricTensor[iaFieldMetric, {iaX, iaY}]},
        With[{gUp = Inverse[g]},
            {
                gUp["Indices"],
                iaZeroQ[gUp["Matrix"] - Inverse[iaFieldMetric]],
                iaZeroQ[iaValue[iaIndexContract[{gUp["IndexArray"][iaA, iaB], g["IndexArray"][-iaB, -iaC]}]] - IdentityMatrix[2]]
            }
        ]
    ],
    {{True, True}, True, True},
    TestID -> "MetricTensor_FieldMetricInverse"
]


(* ------------------------------------------------------------------ *)
(* E. Kernel-audit findings F1-F8                                     *)
(* ------------------------------------------------------------------ *)

(* The loaded paclet's root directory, holding PacletInfo.wl and Kernel/ *)
iaPacletRoot := DirectoryName[FindFile["Wolfram`TensorNetworks`"], 2];

(* Full names declared by PackageExport in the kernel source, each in its file's Package context *)
iaExportedNames[root_] := Union @ Catenate @ Map[
    Function[file, With[{text = ReadString[file]},
        With[{context = First[StringCases[text, "Package[\"" ~~ c : Except["\""] .. ~~ "\"]" :> c], ""]},
            StringCases[text, StartOfLine ~~ "PackageExport[" ~~ s : Except["]"] .. ~~ "]" :> context <> s]
        ]
    ]],
    FileNames["*.wl", FileNameJoin[{root, "Kernel"}], Infinity]
];

(* The autoload list: the "Symbols" of the Kernel extension in PacletInfo.wl *)
iaAutoloadNames[root_] := Union @ First @ Cases[
    Get[FileNameJoin[{root, "PacletInfo.wl"}]]["Extensions"],
    {"Kernel", ___, "Symbols" -> s_List, ___} :> s
];

(* F1: every exported name is in the autoload list (once missing: $TensorNetworkContractionMethods,
   StandardTableauQ, SchurDimension, TableauWeylDimension) *)
VerificationTest[
    Complement[iaExportedNames[iaPacletRoot], iaAutoloadNames[iaPacletRoot]],
    {},
    TestID -> "Fixed_F1_ExportsNotAutoloaded"
]

(* F2: ContractIndices, autoloaded and documented, is exported *)
VerificationTest[
    Wolfram`TensorNetworks`ContractIndices[{1, 2}, {2, 3}],
    {2} -> {{1}, {3}},
    TestID -> "Fixed_F2_ContractIndicesNotExported"
]

(* F4: the signature type property is spelled "SignatureType" *)
VerificationTest[
    {iaMetricTensor["Minkowski"]["SignatureType"], iaMetricTensor["Euclidean"]["SignatureType"]},
    {"Lorentzian", "Riemannian"},
    TestID -> "Fixed_F4_SignatureTypeMisspelled"
]

(* F6: the stored assumptions should hold outside the horizon (r = 10, M = 1) and, for Kerr,
   in the southern hemisphere (theta = 2 Pi/3) *)
VerificationTest[
    {
        And @@ iaMetricTensor["Schwarzschild"[iaMass], {iaCt, iaCr, iaCth, iaCph}]["Assumptions"] /.
            {iaMass -> 1, iaCr -> 10, iaCth -> Pi / 3},
        And @@ iaMetricTensor["IsotropicSchwarzschild"[iaMass], {iaCt, iaX, iaY, iaZ}]["Assumptions"] /.
            {iaMass -> 1, iaX -> 6, iaY -> 8, iaZ -> 0},
        And @@ iaMetricTensor["Kerr"[iaMass, iaSpin], {iaCt, iaCr, iaCth, iaCph}]["Assumptions"] /.
            {iaMass -> 1, iaSpin -> 1 / 2, iaCr -> 10, iaCth -> 2 Pi / 3}
    },
    {True, True, True},
    TestID -> "Fixed_F6_ExteriorAssumptions"
]

(* F7: new coordinates given together with variance flags are kept *)
VerificationTest[
    iaMetricTensor[iaMetricTensor["Minkowski"[2]], {iaCu, iaCw}, True, True]["Coordinates"],
    {iaCu, iaCw},
    TestID -> "Fixed_F7_CoordinatesIgnored"
]

(* F8: the dimensions of Transpose[a, perm] with a list permutation; Transpose itself gives
   the reference *)
VerificationTest[
    TreeData[ContractionTree[Inactive[Transpose][ArraySymbol["A", {2, 3, 5}], {3, 1, 2}], "Labels" -> "Dimensions"]][[2]],
    Dimensions[Transpose[ConstantArray[0, {2, 3, 5}], {3, 1, 2}]],
    TestID -> "Fixed_F8_ListPermutationDimensions"
]


(* ------------------------------------------------------------------ *)
(* F. Metric and slicing bugs found while writing this file            *)
(* ------------------------------------------------------------------ *)

(* The inverse metric g^{mu nu}: contravariant indices and the matrix Inverse[g_{mu nu}], whether
   asked for as a property or by raising both indices *)
VerificationTest[
    With[{g = iaMetricTensor[iaFieldMetric, {iaX, iaY}]},
        {
            g["Inverse"]["Indices"],
            iaZeroQ[g["Inverse"]["Matrix"] - Inverse[iaFieldMetric]],
            g["InverseMetricTensor"]["Indices"],
            iaZeroQ[g["InverseMetricTensor"]["Matrix"] - Inverse[iaFieldMetric]],
            iaMetricTensor[g, True, True]["Indices"],
            iaZeroQ[iaMetricTensor[g, True, True]["Matrix"] - Inverse[iaFieldMetric]]
        }
    ],
    {{True, True}, True, {True, True}, True, {True, True}, True},
    TestID -> "Fixed_InverseMetricKeepsCovariantIndices"
]

(* Every name MetricTensor["Properties"] lists should give a value; the offenders are listed *)
VerificationTest[
    With[{mk = iaMetricTensor["Minkowski"]},
        Select[iaMetricTensor["Properties"], MissingQ[mk[#]] &]
    ],
    {},
    TestID -> "Fixed_ListedMetricPropertiesMissing"
]

(* Slicing with All keeps the All slots as free indices, with their names and signs *)
VerificationTest[
    With[{ia = iaIndexArray[iaRandom[143, {2, 3, 4}], iaShape[{2, 3, 4}, {iaP, -iaQ, iaR}]]},
        {
            {Through[ia[[2, All, 4]]["FreeIndices"]["Name"]], ia[[2, All, 4]]["Signs"]},
            {Through[ia[[All, 2]]["FreeIndices"]["Name"]], ia[[All, 2]]["Signs"]}
        }
    ],
    {{{"iaQ"}, {-1}}, {{"iaP", "iaR"}, {1, 1}}},
    TestID -> "Fixed_IndexPartAllNames"
]

(* The values of All slices against Part. Wolfram/Arrays 1.4.1 ArrayPart[a, {All, 3, 1}] returns
   a[[1, 3]], so an explicit array is sliced with Part *)
VerificationTest[
    With[{a = iaRandom[143, {2, 3, 4}]},
        With[{ia = iaIndexArray[a, iaShape[{2, 3, 4}, {iaP, -iaQ, iaR}]]},
            {
                Normal[ia[[All, 3, 1]]["Tensor"]] === a[[All, 3, 1]],
                Normal[ia[[2, All, 4]]["Tensor"]] === a[[2, All, 4]],
                Normal[ia[[All, 2]]["Tensor"]] === a[[All, 2]]
            }
        ]
    ],
    {True, True, True},
    TestID -> "Fixed_IndexPartAllValues"
]

(* A name not in MetricTensor[] gives a Failure, without messages *)
VerificationTest[
    {MatchQ[iaMetricTensor["NoSuchMetric"], _Failure], MatchQ[iaMetricTensor["NoSuchMetric", {iaX}], _Failure]},
    {True, True},
    TestID -> "Fixed_UnknownMetricNameFailure"
]


(* ------------------------------------------------------------------ *)
(* G. Metric properties against independent answers                   *)
(* ------------------------------------------------------------------ *)

(* Inverting twice returns the original components; the contravariant Schwarzschild metric is
   diag(-1/f, f, 1/r^2, 1/(r^2 sin^2)) and its "MetricTensor" property is covariant again *)
VerificationTest[
    With[{
        sw = iaMetricTensor["Schwarzschild"[iaMass], {iaCt, iaCr, iaCth, iaCph}],
        f = 1 - 2 iaMass / iaCr
    },
        With[{up = sw["InverseMetricTensor"]},
            {
                up["Indices"],
                iaZeroQ[up["Matrix"] - DiagonalMatrix[{-1 / f, f, 1 / iaCr^2, 1 / (iaCr^2 Sin[iaCth]^2)}]],
                up["Inverse"]["Indices"],
                iaZeroQ[up["Inverse"]["Matrix"] - DiagonalMatrix[{-f, 1 / f, iaCr^2, iaCr^2 Sin[iaCth]^2}]],
                up["MetricTensor"]["Indices"],
                iaZeroQ[up["MetricTensor"]["Matrix"] - sw["Matrix"]],
                up["Coordinates"]
            }
        ]
    ],
    {{True, True}, True, {False, False}, True, {False, False}, True, {iaCt, iaCr, iaCth, iaCph}},
    TestID -> "MetricTensor_InverseRoundTrip"
]

(* "MatrixRepresentation" is the stored components g_{mu nu} or g^{mu nu}; "LineElement" and
   "VolumeForm" are built from g_{mu nu} whichever variance the metric is stored with *)
VerificationTest[
    With[{g = iaMetricTensor[iaFieldMetric, {iaX, iaY}]},
        With[{up = g["Inverse"], dx = DifferentialD[iaX], dy = DifferentialD[iaY]},
            {
                iaZeroQ[g["MatrixRepresentation"] - iaFieldMetric],
                iaZeroQ[up["MatrixRepresentation"] - Inverse[iaFieldMetric]],
                iaZeroQ[g["LineElement"] - ((2 + iaX^2) dx^2 + 2 iaX iaY dx dy + (3 + iaY^2) dy^2)],
                iaZeroQ[up["LineElement"] - g["LineElement"]],
                iaZeroQ[up["VolumeForm"] - Sqrt[Abs[Det[iaFieldMetric]]] Wedge[dx, dy]]
            }
        ]
    ],
    {True, True, True, True, True},
    TestID -> "MetricTensor_ComponentsAndLineElement"
]

(* One raised and one lowered index is the Kronecker delta, which is not a metric: a Failure,
   without messages *)
VerificationTest[
    {
        MatchQ[iaMetricTensor[iaMetricTensor["Minkowski"], True, False], _Failure],
        MatchQ[iaMetricTensor[iaMetricTensor["Minkowski"], False, True], _Failure]
    },
    {True, True},
    TestID -> "MetricTensor_MixedVarianceFailure"
]

(* Causal character from g_{mu nu} v^mu v^nu, for both sign conventions, and for the static
   observer outside a Schwarzschild horizon *)
VerificationTest[
    With[{
        mostlyPlus = iaMetricTensor["Minkowski"],
        mostlyMinus = iaMetricTensor[DiagonalMatrix[{1, -1, -1, -1}], {iaCt, iaX, iaY, iaZ}],
        sw = iaMetricTensor["Schwarzschild"[iaMass], {iaCt, iaCr, iaCth, iaCph}],
        vs = {{1, 0, 0, 0}, {0, 1, 0, 0}, {1, 1, 0, 0}, {2, 1, 0, 0}}
    },
        {
            Table[Through[{mostlyPlus["TimelikeQ"], mostlyPlus["SpacelikeQ"], mostlyPlus["LightlikeQ"]}[v]], {v, vs}],
            Table[Through[{mostlyMinus["TimelikeQ"], mostlyMinus["SpacelikeQ"], mostlyMinus["LightlikeQ"]}[v]], {v, vs}],
            {sw["TimelikeQ"[{1, 0, 0, 0}]], sw["SpacelikeQ"[{0, 1, 0, 0}]], mostlyPlus["TimelikeQ", {1, 0, 0, 0}], mostlyMinus["SpacelikeQ", {0, 1, 0, 0}]},
            (* two dimensions, the first coordinate is time, either sign *)
            With[{m = iaMetricTensor[DiagonalMatrix[{1, -1}], {iaCt, iaX}], p = iaMetricTensor[DiagonalMatrix[{-1, 1}], {iaCt, iaX}]},
                {m["TimelikeQ"[{1, 0}]], m["SpacelikeQ"[{0, 1}]], p["TimelikeQ"[{1, 0}]], p["SpacelikeQ"[{0, 1}]]}
            ],
            (* not Lorentzian: no causal character *)
            {MissingQ[iaMetricTensor["Euclidean"]["TimelikeQ"]], MissingQ[iaMetricTensor[-IdentityMatrix[3], {iaX, iaY, iaZ}]["TimelikeQ"[{1, 0, 0}]]]}
        }
    ],
    {
        {{True, False, False}, {False, True, False}, {False, False, True}, {True, False, False}},
        {{True, False, False}, {False, True, False}, {False, False, True}, {True, False, False}},
        {True, True, True, True},
        {True, True, True, True},
        {True, True}
    },
    TestID -> "MetricTensor_CausalCharacter"
]

(* Length sqrt|g(v, v)| and angle arccos(g(u, v) / (|u| |v|)) against the explicit products *)
VerificationTest[
    With[{
        eu = iaMetricTensor["Euclidean"],
        g = iaMetricTensor[iaFieldMetric, {iaX, iaY}],
        u = {1, 2}, v = {3, -1}
    },
        {
            eu["LengthPureFunction"][{3, 4, 0}],
            eu["AnglePureFunction"][{1, 0, 0}, {1, 1, 0}],
            iaZeroQ[g["LengthPureFunction"][v] - Sqrt[Abs[v . iaFieldMetric . v]]],
            iaZeroQ[g["AnglePureFunction"][u, v] - ArcCos[u . iaFieldMetric . v / Sqrt[Abs[(u . iaFieldMetric . u) (v . iaFieldMetric . v)]]]]
        }
    ],
    {5, Pi / 4, True, True},
    TestID -> "MetricTensor_LengthAndAngle"
]

(* The signature conditions of diag(p, q, s, u), read at every sign pattern of the entries:
   Riemannian when all signs agree, Lorentzian when exactly one differs, pseudo-Riemannian (as
   "SignatureType" uses it) when none is zero and each sign appears at least twice *)
VerificationTest[
    With[{g = iaMetricTensor[DiagonalMatrix[{iaP, iaQ, iaS, iaU}], {iaCt, iaX, iaY, iaZ}]},
        With[{points = Tuples[{-2, 0, 3}, 4], at = Function[{cond, pt}, cond /. Thread[{iaP, iaQ, iaS, iaU} -> pt]]},
            {
                Table[at[g["RiemannianConditions"], pt], {pt, points}] ===
                    Table[AllTrue[pt, Positive] || AllTrue[pt, Negative], {pt, points}],
                Table[at[g["LorentzianConditions"], pt], {pt, points}] ===
                    Table[FreeQ[pt, 0] && MemberQ[{1, 3}, Count[pt, _ ? Negative]], {pt, points}],
                Table[at[g["PseudoRiemannianConditions"], pt], {pt, points}] ===
                    Table[FreeQ[pt, 0] && Count[pt, _ ? Negative] == 2, {pt, points}],
                (* the conditions agree with the "Q" properties of numeric metrics *)
                Table[With[{m = iaMetricTensor[DiagonalMatrix[pt], {iaCt, iaX, iaY, iaZ}]},
                    {m["RiemannianQ"], m["LorentzianQ"], m["PseudoRiemannianQ"]}], {pt, {{1, 1, 1, 1}, {-1, 1, 1, 1}, {-1, -1, 1, 1}}}]
            }
        ]
    ],
    {True, True, True, {{True, False, False}, {False, True, False}, {False, False, True}}},
    TestID -> "MetricTensor_SignatureConditions"
]

(* Schwarzschild is singular at r = 0, at the horizon r = 2M and on the axis sin(theta) = 0 *)
VerificationTest[
    With[{sing = iaMetricTensor["Schwarzschild"[iaMass], {iaCt, iaCr, iaCth, iaCph}]["MetricSingularities"]},
        {
            sing /. {iaMass -> 1, iaCr -> 2, iaCth -> 1},
            sing /. {iaMass -> 1, iaCr -> 0, iaCth -> 1},
            sing /. {iaMass -> 1, iaCr -> 5, iaCth -> 0},
            sing /. {iaMass -> 1, iaCr -> 5, iaCth -> 1},
            iaMetricTensor["Minkowski"]["MetricSingularities"]
        }
    ],
    {True, True, True, False, False},
    TestID -> "MetricTensor_Singularities"
]

(* Each eigenvector v of the field metric satisfies g v = lambda v for its eigenvalue *)
VerificationTest[
    With[{g = iaMetricTensor[iaFieldMetric, {iaX, iaY}]},
        iaZeroQ[MapThread[iaFieldMetric . #2 - #1 #2 &, {g["Eigenvalues"], g["Eigenvectors"]}]]
    ],
    True,
    TestID -> "MetricTensor_Eigenvectors"
]

(* A named metric with parameters that is not in the catalog *)
VerificationTest[
    MatchQ[iaMetricTensor["NoSuchMetric"[3]], _Failure],
    True,
    TestID -> "MetricTensor_UnknownParametrizedName"
]

(* Slicing a symbolic array with All keeps the free index name and sign *)
VerificationTest[
    With[{ia = iaIndexArray[ArraySymbol["A", {2, 3, 4}], iaShape[{2, 3, 4}, {iaP, -iaQ, iaR}]]},
        {Through[ia[[2, All, 4]]["FreeIndices"]["Name"]], ia[[2, All, 4]]["Signs"]}
    ],
    {{"iaQ"}, {-1}},
    TestID -> "IndexPart_SymbolicAllNames"
]

(* Transpose with a partial list permutation leaves the trailing levels in place *)
VerificationTest[
    TreeData[ContractionTree[Inactive[Transpose][ArraySymbol["A", {2, 3, 5}], {2, 1}], "Labels" -> "Dimensions"]][[2]],
    Dimensions[Transpose[ConstantArray[0, {2, 3, 5}], {2, 1}]],
    TestID -> "ContractionTree_PartialListPermutationDimensions"
]


(* The isotropic Schwarzschild chart is Lorentzian outside r = M/2 *)
VerificationTest[
    With[{g = iaMetricTensor["IsotropicSchwarzschild"[iaMass], {iaCt, iaX, iaY, iaZ}]},
        {g["SignatureVector"], g["LorentzianQ"]}
    ],
    {{-1, 1, 1, 1}, True},
    TestID -> "MetricTensor_IsotropicSchwarzschildLorentzian"
]

(* A symbolic slice with All before an integer: either the slice of the right length or left
   unevaluated, never a slice of the wrong length *)
VerificationTest[
    With[{s = iaIndexArray[ArraySymbol["A", {2, 3, 4}], iaShape[{2, 3, 4}, {iaP, -iaQ, iaR}]][[All, 3, 1]]},
        Or[
            Head[s] === Wolfram`TensorNetworks`IndexArray`IndexPart,
            Dimensions[s["Tensor"]] === {2} && Through[s["FreeIndices"]["Name"]] === {"iaP"}
        ]
    ],
    True,
    TestID -> "IndexPart_SymbolicAllBeforeInteger"
]

(* Transpose sending two levels of equal length to one takes their diagonal *)
VerificationTest[
    {
        TreeData[ContractionTree[Inactive[Transpose][ArraySymbol["A", {3, 3}], {1, 1}], "Labels" -> "Dimensions"]][[2]],
        TreeData[ContractionTree[Inactive[Transpose][ArraySymbol["A", {4, 3, 4}], {1, 2, 1}], "Labels" -> "Dimensions"]][[2]]
    },
    {Dimensions[Transpose[ConstantArray[0, {3, 3}], {1, 1}]], Dimensions[Transpose[ConstantArray[0, {4, 3, 4}], {1, 2, 1}]]},
    TestID -> "ContractionTree_DiagonalTransposeDimensions"
]

(* Causal character in two dimensions with symbolic components decided under the assumptions,
   and with the second coordinate the only one of definite sign *)
VerificationTest[
    With[{
        sw2 = iaMetricTensor[DiagonalMatrix[{-(1 - 2 iaMass / iaCr), 1 / (1 - 2 iaMass / iaCr)}], {iaCt, iaCr}, False, False, {iaMass > 0, iaCr > 2 iaMass}],
        rindler = iaMetricTensor[{{0, 1}, {1, 1}}, {iaCt, iaX}]
    },
        {sw2["LorentzianQ"], sw2["TimelikeQ", {1, 0}], sw2["SpacelikeQ", {0, 1}], rindler["SpacelikeQ", {0, 1}], rindler["TimelikeQ", {1, -1}]}
    ],
    {True, True, True, True, True},
    TestID -> "MetricTensor_TwoDimensionalCausalCharacter"
]

(* The conditions agree with the "Q" properties: a one-dimensional metric is Riemannian, never
   Lorentzian; a field metric positive for real coordinates is Riemannian *)
VerificationTest[
    With[{one = iaMetricTensor[{2}], g = iaMetricTensor[iaFieldMetric, {iaX, iaY}]},
        {one["RiemannianQ"], one["RiemannianConditions"], one["LorentzianQ"], one["LorentzianConditions"], g["RiemannianQ"], g["RiemannianConditions"]}
    ],
    {True, True, False, False, True, True},
    TestID -> "MetricTensor_ConditionsAgreeWithQ"
]

(* Null coordinates in two dimensions: Lorentzian, but no coordinate is time *)
VerificationTest[
    With[{null = iaMetricTensor[{{0, 1}, {1, 0}}, {iaCu, iaCv}]},
        {null["LorentzianQ"], null["TimelikeQ", {1, 1}]}
    ],
    {True, Missing["NoTimeCoordinate"]},
    TestID -> "MetricTensor_NullCoordinatesNoTime"
]

(* The Kerr assumptions describe the exterior: they hold at r = 3 and fail at r = 3/2, inside the
   outer horizon r+ = 1 + Sqrt[3]/2 (M = 1, J = 1/2), and they require J < M^2 *)
VerificationTest[
    With[{asm = And @@ iaMetricTensor["Kerr"[iaMass, iaSpin], {iaCt, iaCr, iaCth, iaCph}]["Assumptions"]},
        {
            asm /. {iaMass -> 1, iaSpin -> 1 / 2, iaCr -> 3, iaCth -> 2 Pi / 3},
            asm /. {iaMass -> 1, iaSpin -> 1 / 2, iaCr -> 3 / 2, iaCth -> 2 Pi / 3},
            asm /. {iaMass -> 1, iaSpin -> 2, iaCr -> 10, iaCth -> Pi / 3}
        }
    ],
    {True, False, False},
    TestID -> "MetricTensor_KerrExteriorAssumptions"
]

(* A diagonal given by a partial permutation leaves the trailing levels after the diagonal *)
VerificationTest[
    {
        TreeData[ContractionTree[Inactive[Transpose][ArraySymbol["A", {3, 3, 4}], {1, 1}], "Labels" -> "Dimensions"]][[2]],
        TreeData[ContractionTree[Inactive[Transpose][ArraySymbol["A", {3, 4, 3, 5}], {1, 2, 1}], "Labels" -> "Dimensions"]][[2]]
    },
    {Dimensions[Transpose[ConstantArray[0, {3, 3, 4}], {1, 1}]], Dimensions[Transpose[ConstantArray[0, {3, 4, 3, 5}], {1, 2, 1}]]},
    TestID -> "ContractionTree_PartialDiagonalDimensions"
]
