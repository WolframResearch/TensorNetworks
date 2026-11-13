(* Ten targeted regressions from the literature catalogue.
   Formulas come from the cited books. Most fixtures are newly chosen;
   CVT-006 retains the book's seven-box dimension checkpoint.
   Oracles are literal rational values, explicit sums, or closed-form spectra.
   No book files, QF, or external helper packages are required at test time. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];
Needs["Wolfram`TensorNetworks`Symmetry`"];

Begin["TensorNetworksLiteratureTests`"];

(* BOC-004: Bocci & Chiantini, An Introduction to Algebraic Statistics
   with Tensors (2019), sec. 5.2, Definition 5.2.1 and Example 5.2.2,
   printed p. 66 (PDF p. 79). The new asymmetric chain has sizes 2 -> 3 -> 4;
   symmetric transition matrices would hide transpose mistakes. *)
litRegInitial = {1/3, 2/3};
litRegTransitionM = {{1/2, 1/3, 1/6}, {1/5, 3/10, 1/2}};
litRegTransitionN = {{1/2, 1/4, 1/8, 1/8}, {1/10, 1/5, 3/10, 2/5}, {1/4, 1/4, 1/4, 1/4}};
litRegJointReference = {
    {{1/12, 1/24, 1/48, 1/48}, {1/90, 1/45, 1/30, 2/45}, {1/72, 1/72, 1/72, 1/72}},
    {{1/15, 1/30, 1/60, 1/60}, {1/50, 1/25, 3/50, 2/25}, {1/12, 1/12, 1/12, 1/12}}
};
litRegMarkovNetwork[output_List] := TensorNetwork[
    {litRegInitial, litRegTransitionM, litRegTransitionN},
    {{"i"}, {"i", "j"}, {"j", "k"}}, output];

VerificationTest[
    Normal[TensorNetworkContract[litRegMarkovNetwork[{"i", "j", "k"}]]],
    litRegJointReference,
    TestID -> "Literature_BOC004_AsymmetricMarkovJoint"
]

(* BOC-002/004: same book, sec. 8.1, Definitions 8.1.1-8.1.2,
   printed pp. 117-118 (PDF pp. 127-128), and sec. 5.2 above.
   Omitted labels must be summed; retained shared labels must not be summed.
   The three-cycle output order distinguishes a permutation from its inverse. *)
VerificationTest[
    {
        Normal[TensorNetworkContract[litRegMarkovNetwork[{"i"}]]],
        Normal[TensorNetworkContract[litRegMarkovNetwork[{"j"}]]],
        Normal[TensorNetworkContract[litRegMarkovNetwork[{"k"}]]],
        TensorNetworkContract[litRegMarkovNetwork[{}]],
        Normal[TensorNetworkContract[litRegMarkovNetwork[{"k", "i", "j"}]]]
    },
    {
        {1/3, 2/3}, {3/10, 14/45, 7/18}, {167/600, 211/900, 821/3600, 311/1200}, 1,
        Table[litRegJointReference[[i, j, k]], {k, 4}, {i, 2}, {j, 3}]
    },
    TestID -> "Literature_BOC002_MarkovMarginalsAndOutputOrder"
]

(* BOC-005: Bocci & Chiantini, sec. 5.3, Remark 5.3.1 and
   Definition 5.3.2, printed p. 71 (PDF p. 84).
   FAV-005: Favier, Matrix and Tensor Decompositions in Signal Processing
   (2021), sec. 5.2.5.1, equations [5.26]-[5.27], printed p. 252
   (PDF p. 277). Nonuniform weights and nonidentity conditional factors
   make latent-index permutations and duplicated/missing weights observable. *)
litRegMixtureWeights = {1/3, 2/3};
litRegFactorA = {{2/3, 1/4}, {1/3, 3/4}};
litRegFactorB = {{1/2, 1/5}, {1/3, 3/10}, {1/6, 1/2}};
litRegFactorC = {{1/2, 1/10}, {1/4, 1/5}, {1/8, 3/10}, {1/8, 2/5}};
litRegMixtureReference = Table[
    Sum[litRegMixtureWeights[[h]] litRegFactorA[[i, h]] litRegFactorB[[j, h]] litRegFactorC[[k, h]], {h, 2}],
    {i, 2}, {j, 3}, {k, 4}];
litRegMixtureNetwork[output_List] := TensorNetwork[
    {litRegMixtureWeights, litRegFactorA, litRegFactorB, litRegFactorC},
    {{"h"}, {"i", "h"}, {"j", "h"}, {"k", "h"}}, output];

VerificationTest[
    Normal[TensorNetworkContract[litRegMixtureNetwork[{"i", "j", "k"}]]],
    litRegMixtureReference,
    TestID -> "Literature_BOC005_NonuniformLatentMixture"
]

(* FAV-005, sec. 5.2.5.1 [5.26]-[5.27], cited above.
   Compare binarization with an independent explicit latent sum, not with
   another paclet contraction of the original network. Cover eager and inert
   execution on the binarized network's own path and noncanonical outputs. *)
VerificationTest[
    With[{binary = BinaryTensorNetwork[litRegMixtureNetwork[{"k", "i", "j"}]]},
        {
            BinaryTensorNetworkQ[binary],
            Normal[TensorNetworkContract[binary]],
            Normal[ActivateTensors[TensorNetworkContraction[binary,
                GreedyContractionPath[binary], Method -> "TensorContract"]]]
        }
    ],
    With[{reference = Table[litRegMixtureReference[[i, j, k]], {k, 4}, {i, 2}, {j, 3}]},
        {True, reference, reference}],
    TestID -> "Literature_FAV005_WeightedCopyCoreAndPermutedOutput"
]

(* FAV-006: Favier (2021), sec. 3.13.5.1, equation [3.147],
   printed p. 179 (PDF p. 205). Rectangular 6x8 and 8x10 unfoldings,
   complex coefficients and a symbolic parameter expose slot grouping and
   accidental adjoints that the diagonal book checkpoint cannot detect. *)
litRegOperatorA = Table[(2 i - 3 j + 5 k - l)/7 + I (i + 2 j - k + 3 l)/11 + litRegZ i l,
    {i, 2}, {j, 3}, {k, 2}, {l, 4}];
litRegOperatorB = Table[(3 k + l - 2 m + n)/5 + I (k - 4 l + m + 2 n)/13,
    {k, 2}, {l, 4}, {m, 5}, {n, 2}];
litRegProductReference = Table[
    Sum[litRegOperatorA[[i, j, k, l]] litRegOperatorB[[k, l, m, n]], {k, 2}, {l, 4}],
    {i, 2}, {j, 3}, {m, 5}, {n, 2}];
litRegProductNetwork[output_List] := TensorNetwork[{litRegOperatorA, litRegOperatorB},
    {{"i", "j", "k", "l"}, {"k", "l", "m", "n"}}, output];

VerificationTest[
    With[{actual = Normal[TensorNetworkContract[litRegProductNetwork[{"i", "j", "m", "n"}]]]},
        {Dimensions[actual], Expand[actual - litRegProductReference]}
    ],
    {{2, 3, 5, 2}, ConstantArray[0, {2, 3, 5, 2}]},
    TestID -> "Literature_FAV006_RectangularSymbolicEinsteinProduct"
]

(* FAV-006, sec. 3.13.5.1 [3.147], cited above.
   A three-cycle of unequal output dimensions and a deferred execution route;
   the oracle indexes the desired output directly, without Transpose helpers. *)
VerificationTest[
    With[{actual = Normal[ActivateTensors[TensorNetworkContraction[
        litRegProductNetwork[{"m", "i", "j", "n"}], {{1, 2}}, Method -> "TensorContract"]]]},
        {Dimensions[actual], Expand[actual - Table[litRegProductReference[[i, j, m, n]],
            {m, 5}, {i, 2}, {j, 3}, {n, 2}]]}
    ],
    {{5, 2, 3, 2}, ConstantArray[0, {5, 2, 3, 2}]},
    TestID -> "Literature_FAV006_ThreeCycleOutputInert"
]

(* RAN-001: Ran et al., Tensor Network Contractions (2020), sec. 2.2.1,
   equation (2.4) and entropy discussion, printed pp. 27-28 (PDF p. 40).
   New fixture: (|100> + 2|010> + 3 I |001>)/Sqrt[14]. Its two cuts have
   different spectra. Overlap with the real-coefficient state is phase-sensitive;
   entropy or self-overlap alone would miss conjugating the entire state. *)
VerificationTest[
    Module[{bulk, weighted, realWeighted},
        bulk = {{{1, 0}, {0, 2}}, {{0, 0}, {1, 0}}};
        weighted = TensorNetwork[{IdentityMatrix[2]/Sqrt[14], bulk, {{0, 3 I}, {1, 0}}},
            {{1, 4}, {1, 2, 5}, {2, 6}}, {4, 5, 6}];
        realWeighted = TensorNetwork[{IdentityMatrix[2]/Sqrt[14], bulk, {{0, 3}, {1, 0}}},
            {{1, 4}, {1, 2, 5}, {2, 6}}, {4, 5, 6}];
        {
            Flatten[Normal[TensorNetworkContract[weighted]]],
            Sort[FullSimplify[MPSSchmidtValues[weighted, 1]^2], Greater],
            Sort[FullSimplify[MPSSchmidtValues[weighted, 2]^2], Greater],
            FullSimplify[MPSEntanglementEntropy[weighted, 1] + (13/14) Log[13/14] + (1/14) Log[1/14]],
            FullSimplify[MPSEntanglementEntropy[weighted, 2] + (9/14) Log[9/14] + (5/14) Log[5/14]],
            FullSimplify[MPSOverlap[weighted, realWeighted]]
        }
    ],
    {{0, 3 I, 2, 0, 1, 0, 0, 0}/Sqrt[14], {13/14, 1/14}, {9/14, 5/14}, 0, 0, (5 + 9 I)/14},
    TestID -> "Literature_RAN001_WeightedWExactCutsAndPhase"
]

(* Independent reconstruction by sums, never by TensorNetworkContract or MPSOverlap. *)
litRegDenseThreeSites[network_] := With[{sites = network["Tensors"]},
    Table[Sum[sites[[1, a, i]] sites[[2, a, b, j]] sites[[3, b, k]],
        {a, Dimensions[sites[[1]]][[1]]}, {b, Dimensions[sites[[3]]][[1]]}],
        {i, Dimensions[sites[[1]]][[-1]]}, {j, Dimensions[sites[[2]]][[-1]]}, {k, Dimensions[sites[[3]]][[-1]]}]];
litRegThreeLevelGHZ[coefficients_] := TensorNetwork[
    {IdentityMatrix[3], Table[Boole[i == j == k], {i, 3}, {j, 3}, {k, 3}], DiagonalMatrix[coefficients]},
    {{1, 4}, {1, 2, 5}, {2, 6}}, {4, 5, 6}];
litRegGHZReference[coefficients_] := Table[If[i == j == k, coefficients[[i]], 0], {i, 3}, {j, 3}, {k, 3}];

(* HAC-004: Hackbusch, Tensor Spaces and Numerical Tensor Calculus (2019),
   sec. 12.3.7, printed p. 462 (PDF p. 482): the right-isometric variant
   places V-dagger in the core and absorbs U Sigma left.
   RAN-002: Ran et al., sec. 2.2.1, equations (2.6)-(2.7), printed p. 28.
   The book supplies truncation identities, not the WL option semantics:
   this paclet's Tolerance is an absolute singular-value cutoff, retaining s>tol.
   An exact threshold at 2 distinguishes > from >= without roundoff ambiguity. *)
VerificationTest[
    Map[Function[cutoff, With[{canonical = MPSCanonicalForm[
        litRegThreeLevelGHZ[{4, 2 I, -1}], "Right", "Tolerance" -> cutoff]},
        {FullSimplify[litRegDenseThreeSites[canonical]], Dimensions /@ canonical["Tensors"]}
    ]], {199/100, 2, 201/100}],
    {
        {litRegGHZReference[{4, 2 I, 0}], {{2, 3}, {2, 2, 3}, {2, 3}}},
        {litRegGHZReference[{4, 0, 0}], {{1, 3}, {1, 1, 3}, {1, 3}}},
        {litRegGHZReference[{4, 0, 0}], {{1, 3}, {1, 1, 3}, {1, 3}}}
    },
    TestID -> "Literature_HAC004_AbsoluteCutoffBoundary"
]

(* HAC-004 / RAN-002, sections and equations cited immediately above.
   Scaling by two changes what survives a fixed absolute cutoff. A relative
   cutoff would retain the same ranks. Full amplitudes also catch silent
   normalization, lost complex phase, or incorrect residual absorption. *)
VerificationTest[
    Map[Function[scale, With[{canonical = MPSCanonicalForm[
        litRegThreeLevelGHZ[scale {4, 2 I, -1}], "Right", "Tolerance" -> 2]},
        {FullSimplify[litRegDenseThreeSites[canonical]], Dimensions /@ canonical["Tensors"]}
    ]], {1, 2}],
    {
        {litRegGHZReference[{4, 0, 0}], {{1, 3}, {1, 1, 3}, {1, 3}}},
        {litRegGHZReference[{8, 4 I, 0}], {{2, 3}, {2, 2, 3}, {2, 3}}}
    },
    TestID -> "Literature_HAC004_CutoffIsNotScaleInvariant"
]

(* CVT-006: Cvitanovic, Group Theory: Birdtracks, Lie's, and Exceptional
   Groups (2008 draft), sec. 9.4.3, equations (9.27)-(9.30), printed p. 96
   (PDF p. 107). The book's seven-box, three-row checkpoint extends the existing smaller
   symbolic checks. This independent polynomial is not recomputed with hooks.
   Dimension 2 must vanish; dimensions 3 and 4 give 15 and 140. *)
VerificationTest[
    {
        Expand[144 SchurDimension[{4, 2, 1}, litRegD] -
            litRegD^2 (litRegD^2 - 1) (litRegD^2 - 4) (litRegD + 3)],
        SchurDimension[{4, 2, 1}, #] & /@ {2, 3, 4}
    },
    {0, {0, 15, 140}},
    TestID -> "Literature_CVT006_SevenBoxDimensionPolynomial"
]

End[];
