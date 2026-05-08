(* Tests/external_validation/baselines/state_expectations.wl

Baseline (non-paclet) validation tests for product-state expectations. These use
plain Mathematica vector arithmetic - they verify that the analytic answers
catalogued from external packages are reproducible at all, independent of any
paclet primitives.

These tests serve two purposes:
  1. Sanity baseline before extending to paclet-side TensorNetwork tests.
  2. Documentation of the analytic formulas for canonical states.

Sources:
- ITensorNetworks #15 (2x2 GHZ <Sz>=0)
- ITensorNetworks #31 (comb-tree alternating Up/Dn -> +/-0.5)
- quimb tensor-1d.ipynb (Neel state <Z_i>=(-1)^i)
- TeNPy / ITensorMPS (Heisenberg L=6 Neel state <H>=-1.25)
*)

Module[{candidates, found},
    candidates = DeleteDuplicates @ Select[{
        If[StringQ[$InputFileName] && FileExistsQ[$InputFileName],
            FileNameJoin[{DirectoryName[$InputFileName], "..", "Helpers", "ValidationHelpers.wl"}], Null],
        FileNameJoin[{Directory[], "Tests", "external_validation", "Helpers", "ValidationHelpers.wl"}],
        FileNameJoin[{Directory[], "external_validation", "Helpers", "ValidationHelpers.wl"}],
        FileNameJoin[{Directory[], "..", "Helpers", "ValidationHelpers.wl"}],
        FileNameJoin[{Directory[], "Helpers", "ValidationHelpers.wl"}]
    }, StringQ];
    found = SelectFirst[candidates, FileExistsQ, $Failed];
    If[found === $Failed,
        Print["[baseline-state] ERROR: cannot locate ValidationHelpers.wl. Tried: ", candidates];
        Abort[];
    ];
    Get[found];
];
ClearValidationRecords[];

upState = N @ {1, 0};
dnState = N @ {0, 1};
sigmaZ = N @ {{1, 0}, {0, -1}};
sigmaX = N @ {{0, 1}, {1, 0}};
Sz = N @ ({{1, 0}, {0, -1}}/2);
Sx = N @ ({{0, 1}, {1, 0}}/2);
Sy = N @ ({{0, -I}, {I, 0}}/2);

(* ----- F1: Neel state <Z_i> = (-1)^(i+1) for L=20
   quimb tensor-1d.ipynb. Pure vector arithmetic, no paclet. *)
VerificationTest[
    Module[{L, sites, observables, expected},
        L = 20;
        sites = Table[If[OddQ[i], upState, dnState], {i, L}];
        observables = Table[sites[[i]] . sigmaZ . sites[[i]], {i, L}];
        expected = Table[If[OddQ[i], 1, -1], {i, L}];
        ValidationClose[observables, N @ expected, 1.*^-12]
    ],
    True,
    TestID -> "baseline-state-F1-neel-Z-pattern"
];

(* ----- F2: 2x2 grid GHZ-like state <Sz>=0 via state-sum
   ITensorNetworks #15. *)
VerificationTest[
    Module[{L, upAll, dnAll, ghzNorm, szTotal, szAt},
        L = 4;
        upAll = Table[upState, {L}];
        dnAll = Table[dnState, {L}];
        ghzNorm = 2.;
        szAt[i_] := (
            (upAll[[i]] . Sz . upAll[[i]] + dnAll[[i]] . Sz . dnAll[[i]]) / ghzNorm
        );
        szTotal = Table[szAt[i], {i, L}];
        AllTrue[szTotal, ValidationClose[#, 0.0, 1.*^-12] &]
    ],
    True,
    TestID -> "baseline-state-F2-2x2-ghz-Sz-zero"
];

(* ----- F3: comb-tree alternating Up/Dn -> <Sz_v> = +/-0.5
   ITensorNetworks #31. *)
VerificationTest[
    Module[{L, sites, expectations, expected},
        L = 4;
        sites = Table[If[OddQ[i], upState, dnState], {i, L}];
        expectations = Table[sites[[i]] . Sz . sites[[i]], {i, L}];
        expected = Table[If[OddQ[i], 0.5, -0.5], {i, L}];
        ValidationClose[expectations, N @ expected, 1.*^-12]
    ],
    True,
    TestID -> "baseline-state-F3-comb-tree-alternating"
];

(* ----- F4: Heisenberg L=6 Neel state <H> = -5/4 = -1.25
   TeNPy/ITensorMPS reference. *)
VerificationTest[
    Module[{L, neel, bondE, totalE, expected},
        L = 6;
        neel = Table[If[OddQ[i], upState, dnState], {i, L}];
        bondE = Table[
            (neel[[i]] . Sz . neel[[i]]) (neel[[i + 1]] . Sz . neel[[i + 1]]) +
            (neel[[i]] . Sx . neel[[i]]) (neel[[i + 1]] . Sx . neel[[i + 1]]) +
            (neel[[i]] . Sy . neel[[i]]) (neel[[i + 1]] . Sy . neel[[i + 1]])
        , {i, L - 1}];
        totalE = Total[bondE];
        expected = -(L - 1)/4;
        ValidationClose[totalE, N @ expected, 1.*^-12]
    ],
    True,
    TestID -> "baseline-state-F4-heis6-neel-energy"
];
