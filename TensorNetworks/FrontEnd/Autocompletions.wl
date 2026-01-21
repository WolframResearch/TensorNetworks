(* ::Package:: *)

(* Autocompletions for RandomTensorNetwork named types *)
(* This file is loaded by the FrontEnd extension *)

(* Add autocomplete for the first argument of RandomTensorNetwork *)
(* When user types RandomTensorNetwork[" they get suggestions for TN types *)

If[$FrontEnd =!= Null,
    FE`Evaluate[FEPrivate`AddSpecialArgCompletion[
        "RandomTensorNetwork" -> {
            {"\"MPS\"", "\"TT\"", "\"MPO\"", "\"PEPS\"", "\"TTN\"", "\"MERA\""}
        }
    ]]
]
