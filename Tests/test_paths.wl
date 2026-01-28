(* Tests/test_paths.wl *)
(* Comprehensive tests for Paths.wl *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "test_setup.wl"}]];

(* ============================================ *)
(* TreePathQ Tests                             *)
(* ============================================ *)

VerificationTest[
    TreePathQ[{1}],
    True,
    TestID -> "TreePathQ_SingleElement"
]

VerificationTest[
    TreePathQ[{{1}, {2}}],
    True,
    TestID -> "TreePathQ_TwoElements"
]

VerificationTest[
    TreePathQ[{{{1}, {2}}, {3}}],
    True,
    TestID -> "TreePathQ_NestedStructure"
]

VerificationTest[
    TreePathQ[{}],
    False,
    TestID -> "TreePathQ_EmptyList"
]

VerificationTest[
    TreePathQ["not a tree path"],
    False,
    TestID -> "TreePathQ_InvalidInput_String"
]

VerificationTest[
    TreePathQ[123],
    False,
    TestID -> "TreePathQ_InvalidInput_Number"
]

(* ============================================ *)
(* PathQ Tests                                 *)
(* ============================================ *)

VerificationTest[
    PathQ[{{1, 2}}],
    True,
    TestID -> "PathQ_SinglePair"
]

VerificationTest[
    PathQ[{{1, 2}, {1, 2}}],
    True,
    TestID -> "PathQ_MultiplePairs"
]

VerificationTest[
    PathQ[{{1}, {2, 3}}],
    True,
    TestID -> "PathQ_MixedSinglesAndPairs"
]

VerificationTest[
    PathQ[{}],
    False,
    TestID -> "PathQ_EmptyList"
]

VerificationTest[
    PathQ[{{1, 2, 3}}],
    False,
    TestID -> "PathQ_InvalidTriple"
]

VerificationTest[
    PathQ["not a path"],
    False,
    TestID -> "PathQ_InvalidInput_String"
]

(* ============================================ *)
(* CanonicalPathQ Tests                        *)
(* ============================================ *)

VerificationTest[
    CanonicalPathQ[{{1, 2}}],
    True,
    TestID -> "CanonicalPathQ_SinglePair"
]

VerificationTest[
    CanonicalPathQ[{{1, 2}, {1, 2}, {1, 2}}],
    True,
    TestID -> "CanonicalPathQ_MultiplePairs"
]

VerificationTest[
    CanonicalPathQ[{{1}}],
    False,
    TestID -> "CanonicalPathQ_SingleElement"
]

VerificationTest[
    CanonicalPathQ[{}],
    False,
    TestID -> "CanonicalPathQ_EmptyList"
]

(* ============================================ *)
(* PathToTreePath Tests                        *)
(* ============================================ *)

VerificationTest[
    treePath = PathToTreePath[{{1, 2}}];
    TreePathQ[treePath],
    True,
    TestID -> "PathToTreePath_Simple"
]

VerificationTest[
    treePath = PathToTreePath[{{1, 2}, {1, 2}}];
    TreePathQ[treePath],
    True,
    TestID -> "PathToTreePath_TwoPairs"
]

VerificationTest[
    treePath = PathToTreePath[{{1, 2}, {1, 2}, {1, 2}}];
    TreePathQ[treePath],
    True,
    TestID -> "PathToTreePath_ThreePairs"
]

VerificationTest[
    treePath = PathToTreePath[{{1, 2}}, {1, 2, 3}];
    TreePathQ[treePath],
    True,
    TestID -> "PathToTreePath_WithIndices"
]

(* ============================================ *)
(* TreePathToPath Tests                        *)
(* ============================================ *)

VerificationTest[
    path = TreePathToPath[{{1}, {2}}];
    PathQ[path],
    True,
    TestID -> "TreePathToPath_Simple"
]

VerificationTest[
    path = TreePathToPath[{{{1}, {2}}, {3}}];
    PathQ[path],
    True,
    TestID -> "TreePathToPath_Nested"
]

VerificationTest[
    path = TreePathToPath[{{1}, {2}}, {1, 2}];
    PathQ[path],
    True,
    TestID -> "TreePathToPath_WithIndices"
]

(* ============================================ *)
(* CanonicalPath Tests                         *)
(* ============================================ *)

VerificationTest[
    canonical = CanonicalPath[{{1, 2}}];
    CanonicalPathQ[canonical],
    True,
    TestID -> "CanonicalPath_Simple"
]

VerificationTest[
    canonical = CanonicalPath[{{1, 2}, {1, 2}}];
    CanonicalPathQ[canonical],
    True,
    TestID -> "CanonicalPath_TwoPairs"
]

VerificationTest[
    canonical = CanonicalPath[{{1, 2}, {1, 2}, {1, 2}}];
    CanonicalPathQ[canonical],
    True,
    TestID -> "CanonicalPath_ThreePairs"
]

VerificationTest[
    canonical = CanonicalPath[{{2, 3}, {1, 2}}];
    CanonicalPathQ[canonical],
    True,
    TestID -> "CanonicalPath_OutOfOrder"
]

(* ============================================ *)
(* PathIndexContractions Tests                 *)
(* ============================================ *)

VerificationTest[
    path = {{1, 2}};
    indices = {{1, 2}, {2, 3}};
    contractions = PathIndexContractions[path, indices];
    ListQ[contractions],
    True,
    TestID -> "PathIndexContractions_Simple"
]

VerificationTest[
    path = {{1, 2}, {1, 2}};
    indices = {{1, 2}, {2, 3}, {3, 4}};
    contractions = PathIndexContractions[path, indices];
    ListQ[contractions],
    True,
    TestID -> "PathIndexContractions_ThreeTensors"
]

(* ============================================ *)
(* Round-Trip Tests                            *)
(* ============================================ *)

VerificationTest[
    (* Path -> TreePath -> Path should be canonical *)
    path = {{1, 2}};
    treePath = PathToTreePath[path];
    backToPath = TreePathToPath[treePath];
    CanonicalPathQ[backToPath],
    True,
    TestID -> "RoundTrip_PathToTreePathToPath_Simple"
]

VerificationTest[
    (* Path -> TreePath -> Path should be canonical *)
    path = {{1, 2}, {1, 2}};
    treePath = PathToTreePath[path];
    backToPath = TreePathToPath[treePath];
    CanonicalPathQ[backToPath],
    True,
    TestID -> "RoundTrip_PathToTreePathToPath_TwoPairs"
]

VerificationTest[
    (* CanonicalPath should be idempotent *)
    path = {{1, 2}, {1, 2}};
    canonical1 = CanonicalPath[path];
    canonical2 = CanonicalPath[canonical1];
    canonical1 === canonical2,
    True,
    TestID -> "CanonicalPath_Idempotent"
]

(* ============================================ *)
(* Edge Cases                                  *)
(* ============================================ *)

VerificationTest[
    (* Single contraction *)
    TreePathQ[{1}] || TreePathQ[{{1}}],
    True,
    TestID -> "TreePath_MinimalValid"
]

VerificationTest[
    (* Deeply nested tree path *)
    treePath = {{{{1}, {2}}, {3}}, {4}};
    TreePathQ[treePath],
    True,
    TestID -> "TreePathQ_DeeplyNested"
]

