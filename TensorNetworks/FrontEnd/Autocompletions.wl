(* ::Package:: *)

(* Autocompletions for TensorNetworks package *)
(* This file is loaded by the FrontEnd extension *)

If[$FrontEnd =!= Null,
    
    (* RandomTensorNetwork: first argument is TN type *)
    FE`Evaluate[FEPrivate`AddSpecialArgCompletion[
        "RandomTensorNetwork" -> {
            {"\"MPS\"", "\"TT\"", "\"MPO\"", "\"PEPS\"", "\"TTN\"", "\"MERA\""}
        }
    ]];
    
    (* MPSCanonicalForm: second argument is canonical form type *)
    FE`Evaluate[FEPrivate`AddSpecialArgCompletion[
        "MPSCanonicalForm" -> {
            0,  (* First arg: no completion *)
            {"\"Left\"", "\"Right\"", "{\"Mixed\", k}"}
        }
    ]];
    
    (* MPSCanonicalQ: second argument is canonical form type *)
    FE`Evaluate[FEPrivate`AddSpecialArgCompletion[
        "MPSCanonicalQ" -> {
            0,  (* First arg: no completion *)
            {"\"Left\"", "\"Right\"", "{\"Mixed\", k}"}
        }
    ]];
    
]
