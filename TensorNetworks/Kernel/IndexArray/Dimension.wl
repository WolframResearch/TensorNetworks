Package["Wolfram`TensorNetworks`IndexArray`"]

PackageExport[DimensionQ]
PackageExport[Dimension]

PackageScope[DimensionName]
PackageScope[DimensionSymbol]



(* Validation *)

DimensionName[i_Integer ? Positive, alphabet : {__}] := Block[{
    n = Length[alphabet],
    j, k
}, 
    j = Mod[i - 1, n] + 1;
    k = Quotient[i - 1, n];
    ToString[alphabet[[j]]] <> If[k > 0, ToString[k], ""]
]

DimensionName[i_, Automatic] := DimensionName[i, CharacterRange["i", "z"]]

DimensionName[i_] := DimensionName[i, Automatic]




DimensionQ[Dimension[_, _, Except[_List], ___]] := False

DimensionQ[Dimension[_, _, _, Except[_Integer], ___]] := False

DimensionQ[Dimension[_, ___]] := True

DimensionQ[___] := False



Dimension[Dimension[dim_, name_, indices_List : {}, _ : None, args___] ? DimensionQ, index_Integer] := Dimension[dim, name, indices, index, args]

Dimension[Dimension[dim_, name_, _, args___] ? DimensionQ, indices_List] := Dimension[dim, name, indices, args]

Dimension[Dimension[dim_, name_, args___] ? DimensionQ, newName_, newArgs___] :=
    Dimension[
        Replace[newName, {- _ -> -1, _ -> 1}] * dim,
        Replace[newName, {All | Inherited -> name, - x_ :> x}],
        newArgs,
        ##
    ] & @@ Drop[{args}, UpTo[Length[{newArgs}]]]

Dimension[d_Dimension ? DimensionQ] := d


(d_Dimension ? DimensionQ)[prop_String, args___] := Prop[d, prop, args]

Prop[_, "Properties"] := Dimension["Properties"]

Prop[Dimension[dim_, ___], "Dimension" | "Size"] := If[IntegerQ[dim], Abs[dim], Replace[dim, {- _ -> - dim, _ -> dim}]]

Prop[Dimension[dim_, ___], "Variance" | "Sign"] := If[IntegerQ[dim], Sign[dim], Replace[dim, {- _ -> -1, _ -> 1}]]

Prop[d_, "SignedDimension"] := If[d["FreeQ"], d["Sign"] * d["Dimension"], d["Sign"]]

Prop[Dimension[_, name_, ___], "Name"] := CanonicalSymbolName[name]

Prop[_, "Name"] := None

Prop[d_, "SignedName"] := d["Sign"] * d["Name"]

Prop[d_, "DerivativeQ"] := MatchQ[d["Name"], _PartialD]

Prop[d : Dimension[_, args___], "Lower"] := Dimension[- d["Dimension"], args]

Prop[d : Dimension[_, args___], "Upper"] := Dimension[d["Dimension"], args]

Prop[d : Dimension[_, args___], "Minus" | "Toggle"] := Dimension[- d["SignedDimension"], args]

Prop[d_, "LowerQ"] := d["Sign"] < 0

Prop[d_, "UpperQ"] := d["Sign"] >= 0

Prop[Dimension[_, _, indices : {___} : {}, ___], "Indices"] := indices

Prop[Dimension[_], "Indices"] := {}


Prop[d_, "Range", limit_Integer : 10] := With[{dim = d["Dimension"], name = d["IndexName"], indices = d["Indices"]},
    If[ IntegerQ[dim],
        Take[Join[indices, Array[Subscript[name, #] &, Max[0, Abs[dim] - Length[indices]], Length[indices] + 1]], UpTo[Min[limit, Abs[dim]]]],
        indices
    ]
]

Prop[Dimension[_, _, _, index_, ___], "Index"] := index

Prop[_, "Index"] := Missing["Index"]

Prop[d_, "FreeQ"] := MissingQ[d["Index"]]


DimensionSymbol[sign_, name_] :=
    Which[sign > 0, OverBar[name], sign < 0, UnderBar[name], True, Style[name, Opacity[.3]]]

Prop[d_, "IndexName"] := With[{index = d["Index"], indices = d["Indices"]},
    If[MissingQ[index], Replace[d["Name"], None -> "i"], If[IntegerQ[index] && 0 < index <= Length[indices], indices[[index]], index]]
]

Prop[d_, "Symbol"] := DimensionSymbol[d["Sign"], d["IndexName"]]

Prop[d_, "View", limit_Integer : 10] := With[{dim = d["Dimension"], range = d["Range", limit]},
    Row[{
        If[d["UpperQ"], Superscript, Subscript][d["IndexName"], dim],
        If[ Length[range] > 0,
            Splice[{" : ", Row[range, ","], If[IntegerQ[dim] && Length[range] < dim, "\[Ellipsis]", Nothing]}],
            Nothing
        ]
    }]
]


Prop[_, prop_String, ___] := Missing[prop]


Dimension["Properties"] = Sort @ Cases[DownValues[Prop], HoldPattern[_[Prop[_, prop_String, ___]] :> _] :> prop]


(* UpValues *)

Dimension /: - (d_Dimension ? DimensionQ) := d["Minus"]

Dimension /: PartialD[d_Dimension] := Dimension[d, PartialD[d["Name"]]]

Dimension /: Equal[ds__Dimension ? DimensionQ] := SameQ @@ Through[{ds}["Indices"]]


(* Formatting *)

Dimension /: MakeBoxes[d_Dimension ? DimensionQ, form_] := With[{
    box = ToBoxes[d["Symbol"], form],
    tooltip = ToBoxes[d["View"], form]
},
    InterpretationBox[box, d, Tooltip -> tooltip]
]

PartialD[PartialD[x_, n_Integer : 1]] := PartialD[x, n + 1]

PartialD /: MakeBoxes[pd : PartialD[x_, n_Integer : 1], form_] := With[{
    box = ToBoxes[OverDot[x, n], form]
},
    InterpretationBox[box, pd]
]

