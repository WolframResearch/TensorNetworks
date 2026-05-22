Package["Wolfram`TensorNetworks`IndexArray`"]

PackageExport[MetricTensorQ]
PackageExport[MetricTensor]



(* Validation *)

metricTensorQ[MetricTensor[it_IndexTensor]] :=
    IndexTensorQ[it] && it["MetricQ"] && it["Rank"] == 2

metricTensorQ[___] := False


MetricTensorQ[mt_MetricTensor] := System`Private`HoldValidQ[mt] || metricTensorQ[Unevaluated[mt]]

MetricTensorQ[___] := False


(* Built-in metrics *)

MetricTensor[] := {
    "Symmetric", "SymmetricField", "Asymmetric", "AsymmetricField",
    "Euclidean", "Minkowski", 
    "Schwarzschild", "IsotropicSchwarzschild",
    "EddingtonFinkelstein", "IngoingEddingtonFinkelstein", "OutgoingEddingtonFinkelstein",
    "GullstrandPainleve", "IngoingGullstrandPainleve", "OutgoingGullstrandPainleve", 
    "KruskalSzekeres", "Kerr", "ReissnerNordstrom", "KerrNewman", "Godel", "FLRW"
}

t = \[FormalT]
x = \[FormalX]
y = \[FormalY]
z = \[FormalZ]
r = \[FormalR]
T = \[FormalCapitalT]
X = \[FormalCapitalX]
theta = \[FormalTheta]
phi = \[FormalPhi]
M = \[FormalCapitalM]
Q = \[FormalCapitalQ]
J = \[FormalCapitalJ]
k = \[FormalK]
a = \[FormalA]
sqrt2 = \[Sqrt]2
omega = \[FormalOmega]
u = \[FormalU]
v = \[FormalV]

g = \[FormalG]
mu = \[FormalMu]
nu = \[FormalNu]


padCoordinates[coordinates_List, d_Integer ? Positive] := PadRight[Join[coordinates, Superscript[x, #] & /@ Range[d - Length[coordinates]]], d]

padCoordinates[Automatic, d_] := padCoordinates[{}, d]

(* Symmetric *)

MetricTensor["Symmetric"[d : _Integer ? Positive : 4, g_ : g], args___] := 
    MetricTensor[
        SymmetrizedArray[(# -> Subscript[g, Sequence @@ #] &) /@ Select[Tuples[Range[d], 2], OrderedQ], {d, d}, Symmetric[{1, 2}]],
        args
    ]


(* SymmetricField *)

MetricTensor["SymmetricField"[d : _Integer ? Positive : 4, g_ : g], coordinates_ : Automatic, args___] := With[{
    xs = padCoordinates[coordinates, d]
},
    MetricTensor[
        SymmetrizedArray[(# -> Subscript[g, Sequence @@ #] @@ xs &) /@ Select[Tuples[Range[d], 2], OrderedQ], {d, d}, Symmetric[{1, 2}]],
        xs,
        args
    ]
]


(* Asymmetric *)

MetricTensor["Asymmetric"[d : _Integer ? Positive : 4, g_ : g], args___] := 
    MetricTensor[
        SymmetrizedArray[(# -> Subscript[g, Sequence @@ #] &) /@ Subsets[Range[d], {2}], {d, d}, Antisymmetric[{1, 2}]],
        args
    ]


(* AsymmetricField *)

MetricTensor["AsymmetricField"[d : _Integer ? Positive : 4, g_ : g], coordinates_ : Automatic, args___] :=  With[{
    xs = padCoordinates[coordinates, d]
},
    MetricTensor[
        SymmetrizedArray[(# -> Subscript[g, Sequence @@ #] @@ xs &) /@ Subsets[Range[d], {2}], {d, d}, Antisymmetric[{1, 2}]],
        xs,
        args
    ]
]

(* Euclidean *)

MetricTensor["Euclidean"[d : _Integer ? Positive : 3], args___] := 
    MetricTensor[DiagonalMatrix[ConstantArray[1, d]], args]


(* Minkowski *)

MetricTensor["Minkowski"[d : _Integer ? Positive : 4], coordinates_ : Automatic, args___] := 
    MetricTensor[
        DiagonalMatrix[Join[{-1}, ConstantArray[1, d - 1]]],
        Replace[coordinates, Automatic :> Join[{t}, Superscript[x, #] & /@ Range[d - 1]]],
        args
    ]


(* Schwarzschild *)

MetricTensor["Schwarzschild"[M_ : M], {t_ : t, r_ : r, theta_ : theta, phi_ : phi}, args___] := 
    MetricTensor[
        DiagonalMatrix[{ - (1 - (2 * M) / r), 1 / (1 - (2 * M) / r), r ^ 2, r ^ 2 * Sin[theta] ^ 2}],
        {t, r, theta, phi},
        {r > 0, M > 2 r, 0 < theta < Pi},
        args
    ]


(* IsotropicSchwarzschild *)

MetricTensor["IsotropicSchwarzschild"[M_ : M], {t_ : t, x_ : x, y_ : y, z_ : z}, args___] := With[{
    r = Sqrt[x ^ 2 + y ^ 2 + z ^ 2]
},
    MetricTensor[
        DiagonalMatrix[Prepend[ - (1 - M / 2 / r) ^ 2 / (1 + M / 2 / r) ^ 2] @ ConstantArray[(1 + M / 2 / r) ^ 4, 3]],
        {t, x, y, z},
        {r > 0, M > 2 r},
        args
    ]
]


(* EddingtonFinkelstein *)

MetricTensor["EddingtonFinkelstein"[M_ : M], {t_ : t, r_ : r, theta_ : theta, phi_ : phi}, args___] := 
    MetricTensor[
        {
            {- (1 - (2 * M) / r), \[PlusMinus]1, 0, 0},
            {\[PlusMinus]1, 0, 0, 0},
            {0, 0, r ^ 2, 0},
            {0, 0, 0, r ^ 2 * Sin[theta] ^ 2}
        },
        {t, r, theta, phi},
        args
    ]


(* IngoingEddingtonFinkelstein *)

MetricTensor["IngoingEddingtonFinkelstein"[M_ : M], {v_ : v, r_ : r, theta_ : theta, phi_ : phi}, args___] := 
    MetricTensor[
        {
            {- (1 - (2 * M) / r), 1, 0, 0},
            {1, 0, 0, 0},
            {0, 0, r ^ 2, 0},
            {0, 0, 0, r ^ 2 * Sin[theta] ^ 2}
        },
        {v, r, theta, phi},
        args
    ]


(* OutgoingEddingtonFinkelstein *)

MetricTensor["OutgoingEddingtonFinkelstein"[M_ : M], {u_ : u, r_ : r, theta_ : theta, phi_ : phi}, args___] := 
    MetricTensor[
        {
            {- (1 - (2 * M) / r), -1, 0, 0},
            {-1, 0, 0, 0},
            {0, 0, r ^ 2, 0},
            {0, 0, 0, r ^ 2 * Sin[theta] ^ 2}
        },
        {u, r, theta, phi},
        args
    ]


(* GullstrandPainleve *)

MetricTensor["GullstrandPainleve"[M_ : M], {t_ : t, r_ : r, theta_ : theta, phi_ : phi}, args___] := 
    MetricTensor[
        {
            {- (1 - (2 * M) / r), \[PlusMinus]Sqrt[2 * M / r], 0, 0},
            {\[PlusMinus]Sqrt[2 * M / r], 1, 0, 0},
            {0, 0, r ^ 2, 0},
            {0, 0, 0, r ^ 2 * Sin[theta] ^ 2}
        },
        {t, r, theta, phi},
        args
    ]


(* IngoingGullstrandPainleve *)

MetricTensor["IngoingGullstrandPainleve"[M_ : M], {t_ : t, r_ : r, theta_ : theta, phi_ : phi}, args___] := 
    MetricTensor[
        {
            {- (1 - (2 * M) / r), Sqrt[2 * M / r], 0, 0},
            {Sqrt[2 * M / r], 1, 0, 0},
            {0, 0, r ^ 2, 0},
            {0, 0, 0, r ^ 2 * Sin[theta] ^ 2}
        },
        {t, r, theta, phi},
        args
    ]

(* OutgoingGullstrandPainleve *)

MetricTensor["OutgoingGullstrandPainleve"[M_ : M], {t_ : t, r_ : r, theta_ : theta, phi_ : phi}, args___] := 
    MetricTensor[
        {
            {- (1 - (2 * M) / r), - Sqrt[2 * M / r], 0, 0},
            {- Sqrt[2 * M / r], 1, 0, 0},
            {0, 0, r ^ 2, 0},
            {0, 0, 0, r ^ 2 * Sin[theta] ^ 2}
        },
        {t, r, theta, phi},
        args
    ]


(* KruskalSzekeres *)

MetricTensor["KruskalSzekeres"[M_ : M], {T_ : T, X_ : X, theta_ : theta, phi_ : phi}, args___] := With[{
    r = 1 + ProductLog[(X ^ 2 - T ^ 2) / E] 
},
    MetricTensor[
        {
            {- (16 * M ^ 2 * Exp[- r]) / r, 0, 0, 0},
            {0, (16 * M ^ 2 * Exp[-r]) / r, 0, 0},
            {0, 0, 4 M ^ 2 r ^ 2, 0},
            {0, 0, 0, 4 M ^ 2 r ^ 2 * Sin[theta] ^ 2}
        },
        {T, X, theta, phi},
        args
    ]
]


(* Kerr *)

MetricTensor["Kerr"[M_ : M, J_ : J], {t_ : t, r_ : r, theta_ : theta, phi_ : phi}, args___] := With[{
    rho = r ^ 2 + (J * Cos[theta]) ^ 2 / M ^ 2, delta = r ^ 2 - (2 * M * r) + J ^ 2 / M ^ 2
},
    MetricTensor[
        {
            {- 1 + (2 * M * r) / rho, 0, 0, - (2 * r * J * Sin[theta] ^ 2) / rho},
            {0, rho / delta, 0, 0},
            {0, 0, rho, 0},
            {- (2 * r * J * Sin[theta] ^ 2) / rho, 0, 0, 
                (r ^ 2 + J ^ 2 / M ^ 2 + (2 * r * J ^ 2 * Sin[theta] ^ 2) / rho / M) * Sin[theta] ^ 2}
        },
        {t, r, theta, phi},
        {M > 0, J > 0, r > 0, rho > 0, 0 < theta < Pi / 2},
        args
    ]
]

(* KerrNewman *)

MetricTensor["KerrNewman"[M_ : M, Q_ : Q, J_ : J], {t_ : t, r_ : r, theta_ : theta, phi_ : phi}, args___] := With[{
    rho = r ^ 2 + J ^ 2 / M ^ 2,
    rhoCos = r ^ 2 + (J * Cos[theta]) ^ 2 / M ^ 2,
    delta = r ^ 2 - (2 * M * r) + J ^ 2 / M ^ 2 + Q ^ 2 / (4 Pi)
},
    MetricTensor[
        {
            {(- delta + (J * Sin[theta]) ^ 2 / M ^ 2) / rhoCos, 0, 0, J / M (delta - rho) Sin[theta] ^ 2 / rhoCos},
            {0, rhoCos / delta, 0, 0},
            {0, 0, rhoCos, 0},
            {J / M (delta - rho) Sin[theta] ^ 2 / rhoCos, 0, 0, (rho ^ 2 - J ^ 2 / M ^ 2 delta Sin[theta] ^ 2) Sin[theta] ^ 2 / rhoCos}
        },
        {t, r, theta, phi},
        args
    ]
]


(* ReissnerNordstrom *)

MetricTensor["ReissnerNordstrom"[M_ : M, Q_ : Q], {t_ : t, r_ : r, theta_ : theta, phi_ : phi}, args___] := With[{
    f = 1 - (2 * M) / r + (Q ^ 2) / (4 Pi r ^ 2)
},
    MetricTensor[
        DiagonalMatrix[{- f, 1 / f, r ^ 2, r ^ 2 * Sin[theta] ^ 2}],
        {t, r, theta, phi},
        args
    ]
]


(* Godel *)

MetricTensor["Godel"[omega_ : omega], {t_ : t, x_ : x, y_ : y, z_ : z}, args___] := 
    MetricTensor[
        {
            {- 1 / 2 / omega ^ 2, 0, - Exp[x] / 2 / omega ^ 2, 0},
            {0, 1 / 2 / omega ^ 2, 0, 0},
            {- Exp[x] / 2 / omega ^ 2, 0, - Exp[2 x] / 4 / omega ^ 2, 0},
            {0, 0, 0, 1 / 2 / omega ^ 2}
        },
        {t, x, y, z},
        args
    ]


(* FLRW *)

MetricTensor["FLRW"[k_ : k, a_ : a], {t_ : t, r_ : r, theta_ : theta, phi_ : phi}, args___] := With[{
    at = a[t]
},
    MetricTensor[
        DiagonalMatrix[{- 1, at ^ 2 / (1 - k * r ^ 2), at ^ 2 * r ^ 2, at ^ 2 * r ^ 2 * Sin[theta] ^ 2}],
        {t, r, theta, phi},
        {at > 0, r > 0, 0 < theta < Pi, k r ^ 2 < 1},
        args
    ]
]


(* Mutation *)

MetricTensor[mt_MetricTensor, coordinates_List, {i_ ? BooleanQ, j_ ? BooleanQ}, assumptions_List, name_] :=
    MetricTensor[IndexTensor[MetricTensor[mt["Matrix"], padCoordinates[coordinates, mt["Dimension"]], i, j, assumptions, name]["IndexTensor"], mt["IndexArray"]["Indices"]]]

MetricTensor[mt_MetricTensor, coordinates_List, args___] := MetricTensor[MetricTensor[mt, coordinates, mt["Indices"], mt["Assumptions"], mt["Name"]], args]

MetricTensor[mt_MetricTensor, coordinates_List, assumptions_List, args___] := MetricTensor[MetricTensor[mt, coordinates, mt["Indices"], assumptions, mt["Name"]], args]

MetricTensor[mt_MetricTensor, i_ ? BooleanQ, args___] := MetricTensor[MetricTensor[mt, mt["Coordinates"], ReplacePart[mt["Indices"], 1 -> i], mt["Assumptions"], mt["Name"]], args]

MetricTensor[mt_MetricTensor, i_ ? BooleanQ, j_ ? BooleanQ, args___] := MetricTensor[MetricTensor[mt, mt["Coordinates"], {i, j}, mt["Assumptions"], mt["Name"]], args]

MetricTensor[mt_MetricTensor, coordinates_List, i_ ? BooleanQ, j_ ? BooleanQ, args___] := MetricTensor[MetricTensor[mt, mt["Coordinates"], {i, j}, mt["Assumptions"], mt["Name"]], args]

MetricTensor[mt_MetricTensor, name_, args___] := MetricTensor[MetricTensor[mt, mt["Coordinates"], mt["Indices"], mt["Assumptions"], name], args]

MetricTensor[mt_MetricTensor] := mt


(* General constructors *)

MetricTensor[name_String, args___] := MetricTensor[name[], args]

MetricTensor[name : _String[___]] := MetricTensor[name, {}]

MetricTensor[{name_String, params___}, args___] := MetricTensor[name[params], args]

MetricTensor[matrix_ ? squareMatrixQ] := MetricTensor[matrix, Superscript[x, #] & /@ Range[ArrayDimensions[matrix][[1]]]]

MetricTensor[vector_ ? VectorQ] := MetricTensor[DiagonalMatrix[vector]]


MetricTensor[matrix_, coordinates_List, i : _ ? BooleanQ : False, j : _ ? BooleanQ : False, assumptions_List : {}, name_ : "g"] := With[{
    st = IndexArray[matrix, {i, j}, coordinates, assumptions, name]
},
    MetricTensor[IndexTensor[IndexArray[st, Shape @@ MapThread[Dimension[#1, #2, coordinates] &, {st["Indices"], {mu, nu}}]]]]
]

mt_MetricTensor /; System`Private`HoldNotValidQ[mt] && metricTensorQ[Unevaluated[mt]] :=
    System`Private`SetNoEntry[System`Private`HoldSetValid[mt]]


(* Properties *)

(mt_MetricTensor ? MetricTensorQ)[prop_String | prop_String[args___]] := Prop[mt, prop, args] = Prop[mt, prop, args]

MetricTensor["Properties"] = {
    "IndexTensor",
    "MatrixRepresentation", "ReducedMatrixRepresentation", "Coordinates", "CoordinateOneForms", "Indices", "CovariantQ", 
    "ContravariantQ", "MixedQ", "Symbol", "Dimensions", "SymmetricQ", "DiagonalQ", "Signature", "RiemannianQ", 
    "PseudoRiemannianQ", "LorentzianQ", "RiemannianConditions", "PseudoRiemannianConditions", "LorentzianConditions", 
    "MetricSingularities", "Determinant", "ReducedDeterminant", "Trace", "ReducedTrace", "Eigenvalues", 
    "ReducedEigenvalues", "Eigenvectors", "ReducedEigenvectors", "MetricTensor", "InverseMetricTensor", "LineElement", 
    "ReducedLineElement", "VolumeForm", "ReducedVolumeForm", "TimelikeQ", "LightlikeQ", "SpacelikeQ", 
    "LengthPureFunction", "AnglePureFunction", "Properties"
}

Prop[_, "Properties"] := MetricTensor["Properties"]

Prop[MetricTensor[it_] ? MetricTensorQ, "IndexTensor"] := it


Prop[mt_, "Matrix"] := mt["Tensor"]

Prop[mt_, "Variables" | "Coordinates"] := mt["Parameters"]

Prop[mt_, "Indices"] := mt["Variance"]


Prop[mt_, prop_String /; StringStartsQ[prop, "Reduced"]] := FullSimplify[mt[StringDelete[prop, "Reduced"]]]

Prop[mt_, "Dimension" | "Dimensions"] := Length[mt["Coordinates"]]

Prop[mt_, "MatrixRepresentation"] :=
    Switch[mt["Indices"],
        {True, True}, mt["Matrix"],
        {False, False}, Inverse[mt["Matrix"]],
        _, IdentityMatrix[mt["Dimension"]]
    ]

Prop[mt_, "CoordinateOneForms"] := DifferentialD /@ mt["Coordinates"]

Prop[mt_, "Determinant"] := Det[mt["Matrix"]]

Prop[mt_, "Eigenvalues"] := Eigenvalues[mt["Matrix"]]

Prop[mt_, "Trace"] := Tr[mt["Matrix"]]

Prop[mt_, "VolumeForm"] := Sqrt[Abs[Det[mt["Matrix"]]]] * (Wedge @@ mt["CoordinateOneForms"])

Prop[mt_, "LineElement"] := Total[Flatten[mt["Matrix"] * Outer[Times, mt["CoordinateOneForms"], mt["CoordinateOneForms"]]]]

Prop[mt_, "SignatureVector"] := Block[{
    eigenvalues = Re[Eigenvalues[mt["MatrixRepresentation"]]],
    assumptions = mt["Assumptions"],
    positive, negative, zero
},
    positive = Simplify[Thread[eigenvalues > 0], assumptions];
    negative = Simplify[Thread[eigenvalues < 0], assumptions];
    zero = Simplify[Thread[eigenvalues == 0], assumptions];
    Replace[
        Thread[{positive, negative, zero, Thread[Nor[positive, negative, zero]]}],
        {
            {True, __} -> 1,
            {_, True, __} -> -1,
            {_, _, True, __} -> 0,
            _ -> Indeterminate
        },
        1
    ]
]

Prop[mt_, "FullSignature"] := Lookup[Counts[mt["SignatureVector"]], {1, -1, 0, Indeterminate}, 0]

Prop[mt_, "Signature"] := Most[mt["FullSignature"]]

Prop[mt_, "SignatureSigns"] := Replace[mt["SignatureVector"], {1 -> "+", -1 -> "-", 0 -> "0", _ -> "?"}, 1]

Prop[mt_, "Type"] := Switch[
    mt["Indices"]
    ,
    {True, True},
    "Contravariant"
    ,
    {False, False},
    "Covariant"
    ,
    _,
    "Mixed"
]

Prop[mt_, "CovariantQ"] := mt["Type"] === "Covariant"

Prop[mt_, "ContravariantQ"] := mt["Type"] === "Contravariant"

Prop[mt_, "MixedQ"] := mt["Type"] === "Mixed"

Prop[mt_, "SignatyreType"] := Switch[
    mt["FullSignature"],
    {0, 0, 0, _}, "Unknown",
    {p_, 0, 0, 0} | {0, q_, 0, 0}, "Riemannian",
    {1, _, 0, 0} | {_, 1, 0, 0}, "Lorentzian",
    {_, _, 0, 0}, "Pseudo-Riemannian",
    _, "General"
]

Prop[mt_, "RiemannianQ"] := mt["SignatyreType"] === "Riemannian"

Prop[mt_, "PseudoRiemannianQ"] := mt["SignatyreType"] === "Pseudo-Riemannian"

Prop[mt_, "LorentzianQ"] := mt["SignatyreType"] === "Lorentzian"


Prop[mt_, "SymmetricQ"] := mt["Symmetry"] === Symmetric[{1, 2}]

Prop[mt_, "DiagonalQ"] := DiagonalMatrixQ[mt["MatrixRepresentation"]]


Prop[mt_, "Inverse" | "InverseMetricTensor"] := MetricTensor[mt, False, False]


Prop[mt_, prop_String, args___] /; MemberQ[IndexTensor["Properties"], prop] := mt["IndexTensor"][prop, args]


Prop[_, prop_String, ___] := Missing[prop]


(* General fallback constructor *)

MetricTensor[arg_, args__] /; ! MetricTensorQ[Unevaluated[mt]] := With[{mt = MetricTensor[arg]},
    Which[
        ! MetricTensorQ[mt],
        Failure["IndexArray", <|"MessageTemplate" -> "Badly specified metric tensor: ``", "MessageParameters" -> {arg}|>]
        ,
        True,
        MetricTensor[mt, args]
    ]
]


(* Index juggling *)

mt_MetricTensor[is___] := With[{newTensor = MetricTensor[mt["IndexTensor"][is]]},
    If[MetricTensorQ[newTensor], newTensor, First[newTensor]]
]


(* UpValues *)

Scan[
    Function[f,
        MetricTensor /: f[mt_MetricTensor ? MetricTensorQ, args___] := f[mt["IndexTensor"], args]
    ],
    {Normal, Dimensions, SquareMatrixQ, D}
]

Scan[
    Function[f,
        MetricTensor /: f[mt_MetricTensor ? MetricTensorQ, args___] := MetricTensor[f[mt["IndexTensor"], args]]
    ],
    {Inverse}
]

(* Formatting *)

MetricTensor /: MakeBoxes[mt_MetricTensor /; MetricTensorQ[Unevaluated[mt]], TraditionalForm] := With[{
    boxes = ToBoxes[Normal[mt["MatrixRepresentation"]], TraditionalForm]
},
    InterpretationBox[
        boxes,
        mt
    ]
]
    

MetricTensor /: MakeBoxes[mt_MetricTensor /; MetricTensorQ[Unevaluated[mt]], form_] :=
    BoxForm`ArrangeSummaryBox["MetricTensor", mt, mt["Icon"],
        {
            {
                BoxForm`SummaryItem[{"Type: ", mt["Type"]}],
                BoxForm`SummaryItem[{"Symbol: ", mt["Symbol"]}]
            },
            {
                BoxForm`SummaryItem[{"Dimension: ", mt["Dimension"]}], 
                BoxForm`SummaryItem[{"Coordinates: ", mt["Coordinates"]}]   
            }
        },
        {
            {
                BoxForm`SummaryItem[{"Signature: ", TimeConstrained[Row[{mt["SignatyreType"], ": ", Row[mt["SignatureSigns"]]}], .25]}]
            },
            {
                BoxForm`SummaryItem[{"Symmetry: ", mt["Symmetry"]}],
                BoxForm`SummaryItem[{"Assumptions: ", mt["Assumptions"]}]
            }
        },
        form,
        "Interpretable" -> Automatic
    ]


If[ $FrontEnd =!= Null,
    ResourceFunction["AddCodeCompletion"]["MetricTensor"][MetricTensor[]]
]

