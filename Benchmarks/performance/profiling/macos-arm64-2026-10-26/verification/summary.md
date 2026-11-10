# TN component profile

Status: **ok**

Measurements are untraced per-call batch means, reported as median [minimum, maximum].
Replay rows sum one call per distinct captured input for the named helper. Timings are inclusive and overlap: they are not additive phase shares.
The capture pass is outside timing. Duplicate TraceScan evaluation events are removed; these corpus inputs have distinct operands at each step.
Frozen intermediate replays omit dependency formation and can change cache locality; use them to locate costs, not to claim exact end-to-end savings.
Fresh-mask hashing prepares a new Unitize result outside each timed sample, then hashes it once, without calibration. Repeated precomputed-mask hashing can reuse internal state and is not a first-use hash measurement.
The ordered-label candidate is a standalone profiling function tested on unique labels, including unsorted multiple shared axes, disjoint/full overlap, and empty sets. No kernel implementation was replaced.
Activating a prebuilt expression embeds the original tensor values. It is a diagnostic lower bound, not a reusable execution API for changed values.

Kernel source unchanged: True. Suite source unchanged: True.
Corpus SHA256: `64743c53267b0e82ae9c78e20851ac9e0b009ecbf4f9a55e5fd30519ba9382fc`.

## chain-n2-d2-real

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 11.7 [10.6, 15.9] |
| key.leaf_signatures | 1 | 11.1 [9.78, 14.3] |
| key.mask_and_hash | 1 | 1.77 [1.59, 2.54] |
| key.unitize | 1 | 1.32 [0.875, 1.39] |
| key.hash_precomputed_masks | 1 | 0.892 [0.771, 1.29] |
| key.hash_fresh_masks | 1 | 1 [1, 2] |
| key.dimensions | 1 | 1.7 [1.56, 1.99] |
| key.precision | 1 | 0.972 [0.732, 1.53] |
| key.numeric_leaf | 1 | 8.31 [5.76, 10.4] |
| key.arrayq_numeric | 1 | 1.37 [1.32, 1.68] |
| key.sparse_full | 1 | 13.1 [10.3, 15.6] |
| key.cache_lookup_precomputed | 1 | 0.643 [0.425, 9.19] |
| execute.direct_dot | 1 | 0.829 [0.781, 1.14] |
| prepare.data | 1 | 59.6 [56.5, 68.1] |
| prepare.tree_predicate | 1 | 10.2 [7.71, 11.5] |
| prepare.tree_steps | 1 | 31.7 [27.4, 68] |
| prepare.label_dimensions | 1 | 29.8 [24.4, 37.5] |
| prepare.convert_leaves | 1 | 9.97 [8.87, 13.9] |
| prepare.computable_leaves | 1 | 9.76 [7.41, 20.6] |
| prepare.machine_precision_leaves | 1 | 10.4 [9.74, 16.5] |
| prepare.integer_scaled_leaves | 1 | 9.83 [7.65, 13.5] |
| prepare.represent_leaves | 1 | 7.7 [6.82, 10.1] |
| prepare.holder_counts | 1 | 3.98 [3.04, 5.62] |
| prepare.leaf_association | 1 | 1.89 [1.72, 2.51] |
| execute.total.Dot | 1 | 542 [480, 737] |
| execute.build_inactive.Dot | 1 | 526 [442, 709] |
| execute.activate_prebuilt.Dot | 1 | 1.1 [0.79, 1.32] |
| pair.Dot.symmetric_difference | 1 | 71.9 [52.8, 97.1] |
| pair.Dot.contracted_labels | 1 | 132 [113, 170] |
| pair.Dot.ordered_label_candidate | 1 | 7.42 [5.76, 9.53] |
| pair.Dot.delete_elements_single | 1 | 40.8 [34.6, 50.9] |
| pair.Dot.remaining_labels | 1 | 97 [78.1, 101] |
| pair.Dot.position_indices | 1 | 3.45 [3.09, 4.64] |
| pair.Dot.symbolic_dimensions | 1 | 16 [13.7, 20.7] |
| pair.Dot.tensor_dimensions | 1 | 22.3 [20.9, 35.4] |
| pair.Dot.permutations | 1 | 3.2 [2.79, 3.63] |
| pair.Dot.numeric_dot | 1 | 1.57 [1.28, 2.1] |
| pair.Dot.numeric_arraydot | 1 | 6.47 [5.36, 6.56] |
| replay.Dot.contractTreePath | 1 | 386 [360, 490] |
| replay.Dot.contractStep | 1 | 269 [220, 404] |
| replay.Dot.contractTensorPair | 1 | 271 [240, 368] |
| replay.Dot.einsumDot | 1 | 240 [200, 308] |
| replay.Dot.settleLeaf | 2 | 16.9 [14, 20.5] |
| harness.replay_dispatch.Dot | 6 | 2.8 [2.49, 3.73] |
| execute.total.ArrayDot | 1 | 477 [414, 677] |
| execute.build_inactive.ArrayDot | 1 | 435 [393, 606] |
| execute.activate_prebuilt.ArrayDot | 1 | 5.99 [5.1, 7.06] |
| pair.ArrayDot.symmetric_difference | 1 | 55.9 [49.2, 108] |
| pair.ArrayDot.contracted_labels | 1 | 158 [122, 184] |
| pair.ArrayDot.ordered_label_candidate | 1 | 7.39 [6.13, 11.9] |
| pair.ArrayDot.delete_elements_single | 1 | 59.4 [42.9, 81.2] |
| pair.ArrayDot.remaining_labels | 1 | 96.8 [82.9, 131] |
| pair.ArrayDot.position_indices | 1 | 4.13 [3.17, 5.73] |
| pair.ArrayDot.symbolic_dimensions | 1 | 15.5 [13.6, 19.2] |
| pair.ArrayDot.tensor_dimensions | 1 | 17.2 [14.9, 21.1] |
| pair.ArrayDot.permutations | 1 | 3.65 [2.72, 3.88] |
| pair.ArrayDot.numeric_dot | 1 | 1.55 [1.34, 2.25] |
| pair.ArrayDot.numeric_arraydot | 1 | 6.82 [5.6, 9.92] |
| replay.ArrayDot.contractTreePath | 1 | 548 [417, 618] |
| replay.ArrayDot.contractStep | 1 | 266 [207, 386] |
| replay.ArrayDot.contractTensorPair | 1 | 223 [191, 383] |
| replay.ArrayDot.einsumArrayDot | 1 | 227 [204, 327] |
| replay.ArrayDot.settleLeaf | 2 | 14.2 [13.8, 17.9] |
| harness.replay_dispatch.ArrayDot | 6 | 2.78 [2.43, 3.31] |
| automatic.cached_plan | 1 | 19.6 [15.1, 22.5] |
| automatic.warm_execute | 1 | 557 [485, 701] |

## chain-n2-d16-real

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 15.8 [14.1, 19.5] |
| key.leaf_signatures | 1 | 14 [12.9, 17.4] |
| key.mask_and_hash | 1 | 5.28 [4.4, 7.82] |
| key.unitize | 1 | 0.922 [0.919, 1.34] |
| key.hash_precomputed_masks | 1 | 0.99 [0.769, 1.16] |
| key.hash_fresh_masks | 1 | 10 [10, 12] |
| key.dimensions | 1 | 1.61 [1.19, 1.92] |
| key.precision | 1 | 0.802 [0.667, 1.31] |
| key.numeric_leaf | 1 | 6.19 [5.59, 6.99] |
| key.arrayq_numeric | 1 | 1.5 [1.39, 1.8] |
| key.sparse_full | 1 | 11.8 [10.4, 12.7] |
| key.cache_lookup_precomputed | 1 | 0.452 [0.424, 0.767] |
| execute.direct_dot | 1 | 1.16 [1.15, 1.39] |
| prepare.data | 1 | 72.3 [57.7, 91.7] |
| prepare.tree_predicate | 1 | 9.59 [7.64, 11] |
| prepare.tree_steps | 1 | 25.6 [24.3, 30.9] |
| prepare.label_dimensions | 1 | 25.8 [21.2, 29.3] |
| prepare.convert_leaves | 1 | 8.4 [7.52, 9.07] |
| prepare.computable_leaves | 1 | 8.45 [7.38, 9.74] |
| prepare.machine_precision_leaves | 1 | 9.64 [8.66, 11.8] |
| prepare.integer_scaled_leaves | 1 | 7.6 [7.29, 9.57] |
| prepare.represent_leaves | 1 | 5.92 [5.39, 7.49] |
| prepare.holder_counts | 1 | 3.71 [2.87, 5.19] |
| prepare.leaf_association | 1 | 1.89 [1.68, 2.61] |
| execute.total.Dot | 1 | 562 [508, 794] |
| execute.build_inactive.Dot | 1 | 433 [391, 503] |
| execute.activate_prebuilt.Dot | 1 | 1.28 [1.16, 1.69] |
| pair.Dot.symmetric_difference | 1 | 59.3 [53.9, 76.1] |
| pair.Dot.contracted_labels | 1 | 108 [99.4, 128] |
| pair.Dot.ordered_label_candidate | 1 | 7.47 [5.68, 8.1] |
| pair.Dot.delete_elements_single | 1 | 43.3 [37.8, 57.5] |
| pair.Dot.remaining_labels | 1 | 81.5 [67.8, 99.5] |
| pair.Dot.position_indices | 1 | 3.59 [3, 4.16] |
| pair.Dot.symbolic_dimensions | 1 | 17.5 [15.1, 18.9] |
| pair.Dot.tensor_dimensions | 1 | 23.2 [15.5, 26.4] |
| pair.Dot.permutations | 1 | 3.26 [3.15, 4.12] |
| pair.Dot.numeric_dot | 1 | 2.08 [1.68, 2.44] |
| pair.Dot.numeric_arraydot | 1 | 10.7 [7.78, 11.1] |
| replay.Dot.contractTreePath | 1 | 449 [392, 483] |
| replay.Dot.contractStep | 1 | 289 [236, 304] |
| replay.Dot.contractTensorPair | 1 | 235 [197, 301] |
| replay.Dot.einsumDot | 1 | 247 [216, 293] |
| replay.Dot.settleLeaf | 2 | 19.1 [13.8, 20.9] |
| harness.replay_dispatch.Dot | 6 | 3.04 [2.75, 3.13] |
| execute.total.ArrayDot | 1 | 513 [408, 612] |
| execute.build_inactive.ArrayDot | 1 | 498 [416, 608] |
| execute.activate_prebuilt.ArrayDot | 1 | 8.64 [7.45, 11.1] |
| pair.ArrayDot.symmetric_difference | 1 | 61.4 [55.7, 68.4] |
| pair.ArrayDot.contracted_labels | 1 | 136 [97.8, 217] |
| pair.ArrayDot.ordered_label_candidate | 1 | 6.69 [5.69, 7.91] |
| pair.ArrayDot.delete_elements_single | 1 | 41.7 [35, 60.8] |
| pair.ArrayDot.remaining_labels | 1 | 102 [76.9, 117] |
| pair.ArrayDot.position_indices | 1 | 2.9 [2.89, 3.87] |
| pair.ArrayDot.symbolic_dimensions | 1 | 22.7 [15, 98.7] |
| pair.ArrayDot.tensor_dimensions | 1 | 108 [53.1, 140] |
| pair.ArrayDot.permutations | 1 | 11.4 [5.03, 16.8] |
| pair.ArrayDot.numeric_dot | 1 | 2.3 [1.89, 5.48] |
| pair.ArrayDot.numeric_arraydot | 1 | 8.4 [7.81, 10.6] |
| replay.ArrayDot.contractTreePath | 1 | 369 [320, 399] |
| replay.ArrayDot.contractStep | 1 | 237 [209, 309] |
| replay.ArrayDot.contractTensorPair | 1 | 227 [217, 314] |
| replay.ArrayDot.einsumArrayDot | 1 | 230 [212, 290] |
| replay.ArrayDot.settleLeaf | 2 | 19.9 [14.8, 24.4] |
| harness.replay_dispatch.ArrayDot | 6 | 2.85 [2.43, 3.47] |
| automatic.cached_plan | 1 | 24.6 [20.4, 29.8] |
| automatic.warm_execute | 1 | 638 [466, 1.02e+03] |

## chain-n4-d8-real

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 20.1 [16.3, 28.3] |
| key.leaf_signatures | 1 | 18 [16.7, 19.4] |
| key.mask_and_hash | 1 | 4.78 [3.89, 5.45] |
| key.unitize | 1 | 1.57 [1.24, 2.27] |
| key.hash_precomputed_masks | 1 | 1.04 [1.04, 1.87] |
| key.hash_fresh_masks | 1 | 3 [2, 3] |
| key.dimensions | 1 | 2.24 [1.85, 2.51] |
| key.precision | 1 | 0.993 [0.847, 1.61] |
| key.numeric_leaf | 1 | 8.95 [6.83, 10.9] |
| key.arrayq_numeric | 1 | 2.68 [2.16, 3.16] |
| key.sparse_full | 1 | 18.2 [15.5, 21.6] |
| key.cache_lookup_precomputed | 1 | 0.488 [0.422, 0.83] |
| execute.direct_dot | 1 | 1.85 [1.47, 2.58] |
| prepare.data | 1 | 81 [64.8, 103] |
| prepare.tree_predicate | 1 | 15.5 [13.3, 17.7] |
| prepare.tree_steps | 1 | 36.1 [33.1, 54.8] |
| prepare.label_dimensions | 1 | 42.6 [38.9, 50.7] |
| prepare.convert_leaves | 1 | 9.22 [7.69, 10.2] |
| prepare.computable_leaves | 1 | 11.3 [10.2, 14.2] |
| prepare.machine_precision_leaves | 1 | 12.2 [10.5, 14.8] |
| prepare.integer_scaled_leaves | 1 | 11.6 [9.78, 14.1] |
| prepare.represent_leaves | 1 | 6.8 [6.2, 8.57] |
| prepare.holder_counts | 1 | 5.38 [4.73, 7.01] |
| prepare.leaf_association | 1 | 2.3 [2.19, 4.01] |
| execute.total.Dot | 1 | 1.36e+03 [1.06e+03, 1.56e+03] |
| execute.build_inactive.Dot | 1 | 1.55e+03 [1.19e+03, 1.77e+03] |
| execute.activate_prebuilt.Dot | 1 | 1.72 [1.65, 2.23] |
| pair.Dot.symmetric_difference | 3 | 186 [147, 211] |
| pair.Dot.contracted_labels | 3 | 345 [312, 399] |
| pair.Dot.ordered_label_candidate | 3 | 18.4 [16, 28.8] |
| pair.Dot.delete_elements_single | 3 | 128 [118, 168] |
| pair.Dot.remaining_labels | 3 | 263 [221, 361] |
| pair.Dot.position_indices | 3 | 9.75 [7.95, 14.2] |
| pair.Dot.symbolic_dimensions | 3 | 60 [57, 65.8] |
| pair.Dot.tensor_dimensions | 3 | 61.1 [57.5, 69.4] |
| pair.Dot.permutations | 3 | 9.38 [8.23, 14.1] |
| pair.Dot.numeric_dot | 3 | 3.85 [3.18, 5.3] |
| pair.Dot.numeric_arraydot | 3 | 19.1 [17.1, 25.8] |
| replay.Dot.contractTreePath | 1 | 1.03e+03 [809, 1.45e+03] |
| replay.Dot.contractStep | 3 | 870 [745, 1.17e+03] |
| replay.Dot.contractTensorPair | 3 | 782 [623, 913] |
| replay.Dot.einsumDot | 3 | 800 [684, 898] |
| replay.Dot.settleLeaf | 4 | 36.2 [28.2, 44.5] |
| harness.replay_dispatch.Dot | 14 | 5.64 [4.97, 6.99] |
| execute.total.ArrayDot | 1 | 1.35e+03 [963, 1.67e+03] |
| execute.build_inactive.ArrayDot | 1 | 1.11e+03 [901, 1.57e+03] |
| execute.activate_prebuilt.ArrayDot | 1 | 17.5 [15.2, 19.7] |
| pair.ArrayDot.symmetric_difference | 3 | 204 [159, 294] |
| pair.ArrayDot.contracted_labels | 3 | 341 [287, 557] |
| pair.ArrayDot.ordered_label_candidate | 3 | 23.4 [18.8, 28.3] |
| pair.ArrayDot.delete_elements_single | 3 | 139 [110, 194] |
| pair.ArrayDot.remaining_labels | 3 | 283 [204, 568] |
| pair.ArrayDot.position_indices | 3 | 11.9 [7.68, 18.4] |
| pair.ArrayDot.symbolic_dimensions | 3 | 63.8 [39.7, 76.2] |
| pair.ArrayDot.tensor_dimensions | 3 | 61 [43.3, 83.2] |
| pair.ArrayDot.permutations | 3 | 10.6 [7.67, 13.1] |
| pair.ArrayDot.numeric_dot | 3 | 4.85 [3.99, 5.32] |
| pair.ArrayDot.numeric_arraydot | 3 | 19.1 [15.9, 37.4] |
| replay.ArrayDot.contractTreePath | 1 | 1.41e+03 [898, 2.41e+03] |
| replay.ArrayDot.contractStep | 3 | 943 [723, 1.14e+03] |
| replay.ArrayDot.contractTensorPair | 3 | 722 [682, 1.05e+03] |
| replay.ArrayDot.einsumArrayDot | 3 | 682 [595, 973] |
| replay.ArrayDot.settleLeaf | 4 | 31.8 [26.2, 48.8] |
| harness.replay_dispatch.ArrayDot | 14 | 6.84 [6, 7.79] |
| automatic.cached_plan | 1 | 28.3 [23.7, 38.7] |
| automatic.warm_execute | 1 | 1.41e+03 [1.08e+03, 2.02e+03] |

## chain-n12-d16-real

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 69.5 [55.9, 85.6] |
| key.leaf_signatures | 1 | 62.5 [53.8, 74.8] |
| key.mask_and_hash | 1 | 26.6 [24.6, 35.7] |
| key.unitize | 1 | 3.44 [3, 4.14] |
| key.hash_precomputed_masks | 1 | 2.61 [2.38, 3.03] |
| key.hash_fresh_masks | 1 | 56 [55, 58] |
| key.dimensions | 1 | 6.23 [4.81, 7.75] |
| key.precision | 1 | 1.99 [1.66, 2.06] |
| key.numeric_leaf | 1 | 15.4 [12.8, 19.6] |
| key.arrayq_numeric | 1 | 6.81 [4.33, 7.7] |
| key.sparse_full | 1 | 42.9 [38.3, 53.7] |
| key.cache_lookup_precomputed | 1 | 0.423 [0.422, 0.436] |
| execute.direct_dot | 1 | 8.11 [6.82, 9.38] |
| prepare.data | 1 | 195 [160, 235] |
| prepare.tree_predicate | 1 | 40.4 [33.7, 56.5] |
| prepare.tree_steps | 1 | 85.9 [78.7, 130] |
| prepare.label_dimensions | 1 | 132 [128, 168] |
| prepare.convert_leaves | 1 | 9.72 [8.18, 10.2] |
| prepare.computable_leaves | 1 | 17.4 [14.9, 20.7] |
| prepare.machine_precision_leaves | 1 | 22.6 [19.3, 34] |
| prepare.integer_scaled_leaves | 1 | 15.5 [15.4, 22.2] |
| prepare.represent_leaves | 1 | 12.8 [10.2, 15.1] |
| prepare.holder_counts | 1 | 11.6 [8.47, 17.3] |
| prepare.leaf_association | 1 | 6.91 [3.82, 7.39] |
| execute.total.Dot | 1 | 4.06e+03 [3.28e+03, 4.55e+03] |
| execute.build_inactive.Dot | 1 | 8.36e+03 [6.7e+03, 1.13e+04] |
| execute.activate_prebuilt.Dot | 1 | 9.78 [8.14, 10.7] |
| pair.Dot.symmetric_difference | 11 | 681 [536, 870] |
| pair.Dot.contracted_labels | 11 | 1.34e+03 [1.17e+03, 1.82e+03] |
| pair.Dot.ordered_label_candidate | 11 | 71.5 [57.2, 83.4] |
| pair.Dot.delete_elements_single | 11 | 490 [378, 606] |
| pair.Dot.remaining_labels | 11 | 1.08e+03 [764, 1.65e+03] |
| pair.Dot.position_indices | 11 | 46.5 [29.8, 61.3] |
| pair.Dot.symbolic_dimensions | 11 | 192 [147, 352] |
| pair.Dot.tensor_dimensions | 11 | 261 [172, 316] |
| pair.Dot.permutations | 11 | 36.5 [24.6, 43.8] |
| pair.Dot.numeric_dot | 11 | 17.8 [15.7, 25.4] |
| pair.Dot.numeric_arraydot | 11 | 105 [78.6, 150] |
| replay.Dot.contractTreePath | 1 | 4.46e+03 [2.8e+03, 4.89e+03] |
| replay.Dot.contractStep | 11 | 3.45e+03 [2.58e+03, 4.35e+03] |
| replay.Dot.contractTensorPair | 11 | 3.46e+03 [2.8e+03, 3.93e+03] |
| replay.Dot.einsumDot | 11 | 2.61e+03 [2.11e+03, 4.83e+03] |
| replay.Dot.settleLeaf | 12 | 120 [76.3, 176] |
| harness.replay_dispatch.Dot | 46 | 22.8 [18.9, 27.9] |
| execute.total.ArrayDot | 1 | 4.45e+03 [3.23e+03, 5.31e+03] |
| execute.build_inactive.ArrayDot | 1 | 4.28e+03 [3.27e+03, 5.2e+03] |
| execute.activate_prebuilt.ArrayDot | 1 | 119 [94.2, 149] |
| pair.ArrayDot.symmetric_difference | 11 | 650 [540, 858] |
| pair.ArrayDot.contracted_labels | 11 | 1.8e+03 [1.4e+03, 2.76e+03] |
| pair.ArrayDot.ordered_label_candidate | 11 | 86.1 [66.3, 109] |
| pair.ArrayDot.delete_elements_single | 11 | 544 [420, 666] |
| pair.ArrayDot.remaining_labels | 11 | 1.01e+03 [838, 1.25e+03] |
| pair.ArrayDot.position_indices | 11 | 39.9 [36.4, 60.1] |
| pair.ArrayDot.symbolic_dimensions | 11 | 249 [219, 292] |
| pair.ArrayDot.tensor_dimensions | 11 | 206 [158, 238] |
| pair.ArrayDot.permutations | 11 | 29.4 [24.6, 30.8] |
| pair.ArrayDot.numeric_dot | 11 | 14.2 [13.7, 14.5] |
| pair.ArrayDot.numeric_arraydot | 11 | 97.1 [83.1, 111] |
| replay.ArrayDot.contractTreePath | 1 | 3.39e+03 [2.68e+03, 3.81e+03] |
| replay.ArrayDot.contractStep | 11 | 3.41e+03 [3.02e+03, 4.53e+03] |
| replay.ArrayDot.contractTensorPair | 11 | 2.35e+03 [2.1e+03, 3.5e+03] |
| replay.ArrayDot.einsumArrayDot | 11 | 2.42e+03 [2.16e+03, 3.47e+03] |
| replay.ArrayDot.settleLeaf | 12 | 95.7 [87, 115] |
| harness.replay_dispatch.ArrayDot | 46 | 21.2 [15.4, 26.7] |
| automatic.cached_plan | 1 | 72.9 [57.2, 87.1] |
| automatic.warm_execute | 1 | 3.86e+03 [3.15e+03, 5.34e+03] |

## chain-n12-d64-real

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 290 [288, 593] |
| key.leaf_signatures | 1 | 376 [287, 445] |
| key.mask_and_hash | 1 | 315 [261, 429] |
| key.unitize | 1 | 13.6 [10.3, 16.4] |
| key.hash_precomputed_masks | 1 | 2.14 [2.1, 2.86] |
| key.hash_fresh_masks | 1 | 248 [247, 251] |
| key.dimensions | 1 | 5.26 [5.23, 5.92] |
| key.precision | 1 | 1.82 [1.52, 2.55] |
| key.numeric_leaf | 1 | 12.2 [11.8, 16.4] |
| key.arrayq_numeric | 1 | 5.47 [5.01, 6.3] |
| key.sparse_full | 1 | 39.2 [38.1, 48.7] |
| key.cache_lookup_precomputed | 1 | 0.484 [0.421, 0.673] |

## chain-n12-d256-real

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 4.09e+03 [4.01e+03, 6.68e+03] |
| key.leaf_signatures | 1 | 5.16e+03 [4.01e+03, 5.78e+03] |
| key.mask_and_hash | 1 | 4.5e+03 [3.98e+03, 6.54e+03] |
| key.unitize | 1 | 426 [324, 449] |
| key.hash_precomputed_masks | 1 | 2.49 [2.1, 2.91] |
| key.hash_fresh_masks | 1 | 3.87e+03 [3.85e+03, 6.28e+03] |
| key.dimensions | 1 | 5.67 [4.52, 7.07] |
| key.precision | 1 | 1.77 [1.69, 2.07] |
| key.numeric_leaf | 1 | 18.3 [11.9, 20.9] |
| key.arrayq_numeric | 1 | 5.06 [4.71, 6.28] |
| key.sparse_full | 1 | 38.3 [35.3, 48.5] |
| key.cache_lookup_precomputed | 1 | 0.589 [0.45, 0.74] |

## chain-n12-d16-complex

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 61 [51.4, 75.6] |
| key.leaf_signatures | 1 | 57.7 [48.8, 75.7] |
| key.mask_and_hash | 1 | 29.4 [25.3, 37.6] |
| key.unitize | 1 | 3.63 [3.55, 4.63] |
| key.hash_precomputed_masks | 1 | 2.48 [2.18, 3.34] |
| key.hash_fresh_masks | 1 | 19 [19, 21] |
| key.dimensions | 1 | 5.09 [4.6, 6.02] |
| key.precision | 1 | 1.77 [1.62, 1.95] |
| key.numeric_leaf | 1 | 14.6 [12, 18.8] |
| key.arrayq_numeric | 1 | 5.08 [4.45, 5.67] |
| key.sparse_full | 1 | 41.8 [33.9, 63.9] |
| key.cache_lookup_precomputed | 1 | 0.578 [0.475, 0.875] |
| execute.direct_dot | 1 | 19.6 [17.1, 21.1] |
| prepare.data | 1 | 189 [160, 239] |
| prepare.tree_predicate | 1 | 46 [34, 59.1] |
| prepare.tree_steps | 1 | 97.8 [79.6, 115] |
| prepare.label_dimensions | 1 | 116 [96.7, 143] |
| prepare.convert_leaves | 1 | 8.56 [7.82, 10.8] |
| prepare.computable_leaves | 1 | 19.8 [15.5, 21.2] |
| prepare.machine_precision_leaves | 1 | 23.7 [18, 26.8] |
| prepare.integer_scaled_leaves | 1 | 20.7 [17.4, 24] |
| prepare.represent_leaves | 1 | 10.5 [10.1, 14] |
| prepare.holder_counts | 1 | 9.94 [8.88, 12.1] |
| prepare.leaf_association | 1 | 3.75 [3.57, 3.96] |
| execute.total.Dot | 1 | 4.21e+03 [3.51e+03, 4.95e+03] |
| execute.build_inactive.Dot | 1 | 8.1e+03 [6.51e+03, 9.61e+03] |
| execute.activate_prebuilt.Dot | 1 | 21.3 [17.7, 25.6] |
| pair.Dot.symmetric_difference | 11 | 605 [533, 719] |
| pair.Dot.contracted_labels | 11 | 1.34e+03 [1.12e+03, 1.49e+03] |
| pair.Dot.ordered_label_candidate | 11 | 68.4 [58.4, 78.7] |
| pair.Dot.delete_elements_single | 11 | 384 [375, 550] |
| pair.Dot.remaining_labels | 11 | 1.11e+03 [871, 1.55e+03] |
| pair.Dot.position_indices | 11 | 30.1 [26.5, 31.8] |
| pair.Dot.symbolic_dimensions | 11 | 168 [144, 197] |
| pair.Dot.tensor_dimensions | 11 | 178 [155, 202] |
| pair.Dot.permutations | 11 | 29.7 [26.8, 33.7] |
| pair.Dot.numeric_dot | 11 | 25.6 [23.1, 35.4] |
| pair.Dot.numeric_arraydot | 11 | 104 [93.2, 134] |
| replay.Dot.contractTreePath | 1 | 3.27e+03 [3.06e+03, 3.54e+03] |
| replay.Dot.contractStep | 11 | 3.01e+03 [2.46e+03, 3.68e+03] |
| replay.Dot.contractTensorPair | 11 | 2.84e+03 [2.19e+03, 4.44e+03] |
| replay.Dot.einsumDot | 11 | 2.87e+03 [2.61e+03, 3.52e+03] |
| replay.Dot.settleLeaf | 12 | 101 [84, 147] |
| harness.replay_dispatch.Dot | 46 | 20.2 [17.2, 23.5] |
| execute.total.ArrayDot | 1 | 4.14e+03 [3.81e+03, 5.09e+03] |
| execute.build_inactive.ArrayDot | 1 | 3.31e+03 [2.84e+03, 4.96e+03] |
| execute.activate_prebuilt.ArrayDot | 1 | 102 [91.5, 108] |
| pair.ArrayDot.symmetric_difference | 11 | 631 [530, 789] |
| pair.ArrayDot.contracted_labels | 11 | 1.2e+03 [1.06e+03, 1.5e+03] |
| pair.ArrayDot.ordered_label_candidate | 11 | 59.7 [57.2, 75.8] |
| pair.ArrayDot.delete_elements_single | 11 | 531 [398, 646] |
| pair.ArrayDot.remaining_labels | 11 | 917 [790, 1.14e+03] |
| pair.ArrayDot.position_indices | 11 | 34.4 [26.3, 37.2] |
| pair.ArrayDot.symbolic_dimensions | 11 | 182 [150, 205] |
| pair.ArrayDot.tensor_dimensions | 11 | 179 [157, 251] |
| pair.ArrayDot.permutations | 11 | 32.3 [29.8, 39.9] |
| pair.ArrayDot.numeric_dot | 11 | 28 [24.1, 33.6] |
| pair.ArrayDot.numeric_arraydot | 11 | 109 [88.3, 114] |
| replay.ArrayDot.contractTreePath | 1 | 3.43e+03 [2.81e+03, 3.78e+03] |
| replay.ArrayDot.contractStep | 11 | 2.77e+03 [2.63e+03, 4.52e+03] |
| replay.ArrayDot.contractTensorPair | 11 | 2.52e+03 [2.15e+03, 3.21e+03] |
| replay.ArrayDot.einsumArrayDot | 11 | 2.42e+03 [2.07e+03, 3.04e+03] |
| replay.ArrayDot.settleLeaf | 12 | 78.9 [73.7, 96.4] |
| harness.replay_dispatch.ArrayDot | 46 | 18.9 [15.5, 25.7] |
| automatic.cached_plan | 1 | 64.8 [55.9, 90.5] |
| automatic.warm_execute | 1 | 4.33e+03 [3.1e+03, 5.28e+03] |
