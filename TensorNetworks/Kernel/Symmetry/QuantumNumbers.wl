(* ::Package:: *)

Package["Wolfram`TensorNetworks`Symmetry`"]

(* Quantum Numbers for tensor symmetry operations *)
(* Enables symmetry-filtered tensor contractions that skip zero blocks *)

PackageExport[ChargeVector]
PackageExport[ChargeVectorQ]
PackageExport[AllowedContractions]
PackageExport[ChargesConservedQ]
PackageExport[IndicesWithCharge]


(* ============================================ *)
(* ChargeVector Data Structure                  *)
(* ============================================ *)

(* ChargeVector[{q1, q2, ...}] stores the quantum number (charge) for each index value.
   Example: ChargeVector[{0, 1, -1, 0, 1}] for a 5-dimensional index
   where index 1 has charge 0, index 2 has charge 1, etc.

   For U(1) symmetry (particle number conservation):
   - Charges are integers representing particle number
   - Contraction conserves charge: qA + qB = 0 for contracted indices

   For Z_N symmetry:
   - Charges are integers mod N
   - Conservation: (qA + qB) mod N = 0 *)


(* ============================================ *)
(* Validation                                   *)
(* ============================================ *)

chargeVectorQ[ChargeVector[charges_List]] := AllTrue[charges, IntegerQ]
chargeVectorQ[_] := False

ChargeVectorQ[cv_ChargeVector] := System`Private`HoldValidQ[cv] || chargeVectorQ[Unevaluated[cv]]
ChargeVectorQ[_] := False

(* Auto-validate on construction - use same pattern as TensorNetwork.wl *)
cv_ChargeVector /; System`Private`HoldNotValidQ[cv] && chargeVectorQ[Unevaluated[cv]] := (
    System`Private`HoldSetValid[cv];
    System`Private`HoldSetNoEntry[cv];
    cv
)

(* Part accessor for ChargeVector - needed because SetNoEntry makes expression atomic *)
ChargeVector /: Part[cv_ChargeVector ? ChargeVectorQ, 1] :=
    Replace[cv, HoldPattern[ChargeVector[charges_]] :> charges]


(* ============================================ *)
(* Charge Conservation                          *)
(* ============================================ *)

(* Check if two charge lists satisfy conservation (sum to zero element-wise) *)
ChargesConservedQ[qA_List, qB_List] /; Length[qA] == Length[qB] :=
    qA + qB === ConstantArray[0, Length[qA]]

ChargesConservedQ[cvA_ChargeVector ? ChargeVectorQ, cvB_ChargeVector ? ChargeVectorQ] :=
    ChargesConservedQ[cvA[[1]], cvB[[1]]]

ChargesConservedQ::length = "Charge vectors must have the same length.";
ChargesConservedQ[_, _] := (Message[ChargesConservedQ::length]; False)


(* ============================================ *)
(* Allowed Contractions                         *)
(* ============================================ *)

(* Find all index pairs (i, j) where qA[i] + qB[j] = 0 *)
(* These are the only pairs that contribute to the contraction *)

AllowedContractions[cvA_ChargeVector ? ChargeVectorQ, cvB_ChargeVector ? ChargeVectorQ] :=
Module[{qA = cvA[[1]], qB = cvB[[1]], pairs},
    pairs = Tuples[{Range[Length[qA]], Range[Length[qB]]}];
    Select[pairs, qA[[#[[1]]]] + qB[[#[[2]]]] == 0 &]
]

(* Variant that takes raw charge lists *)
AllowedContractions[qA_List, qB_List] /; AllTrue[qA, IntegerQ] && AllTrue[qB, IntegerQ] :=
Module[{pairs},
    pairs = Tuples[{Range[Length[qA]], Range[Length[qB]]}];
    Select[pairs, qA[[#[[1]]]] + qB[[#[[2]]]] == 0 &]
]

AllowedContractions::invalid = "AllowedContractions requires ChargeVector or integer list arguments.";
AllowedContractions[_, _] := (Message[AllowedContractions::invalid]; {})


(* ============================================ *)
(* Index Selection by Charge                    *)
(* ============================================ *)

(* Get all indices where the charge equals the target value *)
IndicesWithCharge[cv_ChargeVector ? ChargeVectorQ, targetCharge_Integer] :=
    Flatten[Position[cv[[1]], targetCharge]]

IndicesWithCharge[charges_List, targetCharge_Integer] /; AllTrue[charges, IntegerQ] :=
    Flatten[Position[charges, targetCharge]]

IndicesWithCharge::invalid = "IndicesWithCharge requires a ChargeVector or integer list.";
IndicesWithCharge[_, _] := (Message[IndicesWithCharge::invalid]; {})


(* ============================================ *)
(* Charge Arithmetic                            *)
(* ============================================ *)

(* Negate charges (for dual/conjugate indices) *)
(* Note: -cv is represented as Times[-1, cv] in Wolfram Language, so we define upvalue for Times *)
ChargeVector /: Times[-1, cv_ChargeVector ? ChargeVectorQ] := ChargeVector[-cv[[1]]]
ChargeVector /: Times[cv_ChargeVector ? ChargeVectorQ, -1] := ChargeVector[-cv[[1]]]

(* Get unique charges present in a ChargeVector *)
UniqueCharges[cv_ChargeVector ? ChargeVectorQ] := Union[cv[[1]]]
UniqueCharges[charges_List] /; AllTrue[charges, IntegerQ] := Union[charges]


(* ============================================ *)
(* Formatting                                   *)
(* ============================================ *)

ChargeVector /: MakeBoxes[cv : ChargeVector[charges_List] /; ChargeVectorQ[Unevaluated[cv]], fmt_] :=
    With[{
        dim = Length[charges],
        unique = Union[charges],
        nUnique = Length[Union[charges]]
    },
        BoxForm`ArrangeSummaryBox[
            ChargeVector,
            cv,
            (* Icon *)
            Graphics[{
                EdgeForm[Gray],
                Table[{Hue[0.6 + 0.1 * charges[[i]]], Rectangle[{i - 1, 0}, {i, 1}]}, {i, Min[dim, 10]}]
            }, ImageSize -> 32, AspectRatio -> 0.5],
            (* Always shown *)
            {
                {BoxForm`SummaryItem[{"Dimension: ", dim}]},
                {BoxForm`SummaryItem[{"Sectors: ", nUnique}]}
            },
            (* Expanded *)
            {
                BoxForm`SummaryItem[{"Charges: ", If[dim <= 20, charges, Short[charges, 2]]}],
                BoxForm`SummaryItem[{"Unique: ", unique}]
            },
            fmt
        ]
    ]
