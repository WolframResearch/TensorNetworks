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
| key.total | 1 | 10.1 [9.68, 11.9] |
| key.leaf_signatures | 1 | 11.3 [9.63, 43] |
| key.mask_and_hash | 1 | 2 [1.62, 2.79] |
| key.unitize | 1 | 1.34 [0.866, 5.86] |
| key.hash_precomputed_masks | 1 | 0.954 [0.796, 1.06] |
| key.hash_fresh_masks | 1 | 3 [2, 7] |
| key.dimensions | 1 | 1.26 [1.18, 1.68] |
| key.precision | 1 | 0.815 [0.709, 0.903] |
| key.numeric_leaf | 1 | 6.59 [6.05, 8.11] |
| key.arrayq_numeric | 1 | 1.46 [1.32, 1.68] |
| key.sparse_full | 1 | 13.6 [11.2, 16.2] |
| key.cache_lookup_precomputed | 1 | 0.427 [0.426, 0.47] |
| execute.direct_dot | 1 | 1.01 [0.794, 1.19] |
| prepare.data | 1 | 54.7 [44.2, 56.9] |
| prepare.tree_predicate | 1 | 9.03 [7.74, 11.6] |
| prepare.tree_steps | 1 | 25.5 [22.4, 31.4] |
| prepare.label_dimensions | 1 | 22.8 [21.3, 26] |
| prepare.convert_leaves | 1 | 8.01 [7.21, 10.2] |
| prepare.computable_leaves | 1 | 9.57 [7.38, 11.3] |
| prepare.machine_precision_leaves | 1 | 9.3 [8.7, 11.5] |
| prepare.integer_scaled_leaves | 1 | 8.79 [7.79, 10.8] |
| prepare.represent_leaves | 1 | 6.15 [5.99, 6.5] |
| prepare.holder_counts | 1 | 3.28 [3.05, 3.74] |
| prepare.leaf_association | 1 | 2.02 [1.71, 3.07] |
| execute.total.Dot | 1 | 599 [421, 702] |
| execute.build_inactive.Dot | 1 | 531 [462, 668] |
| execute.activate_prebuilt.Dot | 1 | 1.14 [0.945, 1.39] |
| pair.Dot.symmetric_difference | 1 | 67.9 [60.6, 86.4] |
| pair.Dot.contracted_labels | 1 | 125 [110, 160] |
| pair.Dot.ordered_label_candidate | 1 | 6.91 [5.84, 8.37] |
| pair.Dot.delete_elements_single | 1 | 42.5 [35.8, 100] |
| pair.Dot.remaining_labels | 1 | 87.2 [74, 105] |
| pair.Dot.position_indices | 1 | 3.5 [2.92, 5.08] |
| pair.Dot.symbolic_dimensions | 1 | 14.3 [13.7, 21.2] |
| pair.Dot.tensor_dimensions | 1 | 17 [15.2, 19.3] |
| pair.Dot.permutations | 1 | 3.21 [2.85, 3.53] |
| pair.Dot.numeric_dot | 1 | 1.45 [1.31, 2.35] |
| pair.Dot.numeric_arraydot | 1 | 5.37 [4.99, 6.65] |
| replay.Dot.contractTreePath | 1 | 418 [324, 462] |
| replay.Dot.contractStep | 1 | 267 [231, 322] |
| replay.Dot.contractTensorPair | 1 | 239 [216, 275] |
| replay.Dot.einsumDot | 1 | 310 [226, 399] |
| replay.Dot.settleLeaf | 2 | 16.6 [13.9, 21.9] |
| harness.replay_dispatch.Dot | 6 | 3.27 [2.45, 3.58] |
| execute.total.ArrayDot | 1 | 624 [415, 1.11e+03] |
| execute.build_inactive.ArrayDot | 1 | 537 [387, 676] |
| execute.activate_prebuilt.ArrayDot | 1 | 5.87 [5.17, 7.84] |
| pair.ArrayDot.symmetric_difference | 1 | 59.7 [54.9, 69.8] |
| pair.ArrayDot.contracted_labels | 1 | 132 [101, 146] |
| pair.ArrayDot.ordered_label_candidate | 1 | 6.57 [6.41, 7.6] |
| pair.ArrayDot.delete_elements_single | 1 | 42.3 [34.9, 50] |
| pair.ArrayDot.remaining_labels | 1 | 77.9 [68.5, 94.1] |
| pair.ArrayDot.position_indices | 1 | 4.27 [2.95, 5.24] |
| pair.ArrayDot.symbolic_dimensions | 1 | 15.4 [13.7, 18.5] |
| pair.ArrayDot.tensor_dimensions | 1 | 18.1 [15, 24.7] |
| pair.ArrayDot.permutations | 1 | 3.43 [2.74, 6.16] |
| pair.ArrayDot.numeric_dot | 1 | 1.82 [1.31, 1.88] |
| pair.ArrayDot.numeric_arraydot | 1 | 7.17 [5.31, 8.57] |
| replay.ArrayDot.contractTreePath | 1 | 360 [310, 433] |
| replay.ArrayDot.contractStep | 1 | 234 [206, 288] |
| replay.ArrayDot.contractTensorPair | 1 | 269 [203, 337] |
| replay.ArrayDot.einsumArrayDot | 1 | 223 [198, 243] |
| replay.ArrayDot.settleLeaf | 2 | 15.8 [14, 19.3] |
| harness.replay_dispatch.ArrayDot | 6 | 3.02 [2.43, 4.4] |
| automatic.cached_plan | 1 | 19.4 [18, 20.4] |
| automatic.warm_execute | 1 | 644 [459, 689] |

## chain-n2-d16-real

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 15.3 [13.3, 17] |
| key.leaf_signatures | 1 | 14.5 [11.7, 15.1] |
| key.mask_and_hash | 1 | 4.7 [4.38, 6.44] |
| key.unitize | 1 | 0.991 [0.918, 1.36] |
| key.hash_precomputed_masks | 1 | 1.03 [0.809, 1.14] |
| key.hash_fresh_masks | 1 | 4 [3, 5] |
| key.dimensions | 1 | 1.75 [1.17, 2.13] |
| key.precision | 1 | 0.673 [0.665, 0.844] |
| key.numeric_leaf | 1 | 6.75 [5.59, 8.35] |
| key.arrayq_numeric | 1 | 1.46 [1.26, 1.91] |
| key.sparse_full | 1 | 10.9 [10.1, 13.7] |
| key.cache_lookup_precomputed | 1 | 0.42 [0.42, 0.786] |
| execute.direct_dot | 1 | 1.27 [1.15, 1.53] |
| prepare.data | 1 | 66.5 [56.8, 97.8] |
| prepare.tree_predicate | 1 | 12.4 [7.74, 23.4] |
| prepare.tree_steps | 1 | 26.5 [24.2, 32.7] |
| prepare.label_dimensions | 1 | 27.8 [23.7, 32.8] |
| prepare.convert_leaves | 1 | 8.59 [7.3, 10.2] |
| prepare.computable_leaves | 1 | 9.72 [7.92, 11.3] |
| prepare.machine_precision_leaves | 1 | 10.8 [9.41, 12.7] |
| prepare.integer_scaled_leaves | 1 | 8.14 [7.77, 10] |
| prepare.represent_leaves | 1 | 7.15 [6.18, 23.9] |
| prepare.holder_counts | 1 | 4.66 [3.98, 5.36] |
| prepare.leaf_association | 1 | 2.34 [1.71, 2.55] |
| execute.total.Dot | 1 | 580 [473, 651] |
| execute.build_inactive.Dot | 1 | 747 [427, 901] |
| execute.activate_prebuilt.Dot | 1 | 1.41 [1.21, 1.76] |
| pair.Dot.symmetric_difference | 1 | 65.2 [53.4, 80.9] |
| pair.Dot.contracted_labels | 1 | 139 [105, 186] |
| pair.Dot.ordered_label_candidate | 1 | 11.1 [9.54, 14.4] |
| pair.Dot.delete_elements_single | 1 | 126 [89, 210] |
| pair.Dot.remaining_labels | 1 | 132 [106, 174] |
| pair.Dot.position_indices | 1 | 5.93 [4.16, 18.6] |
| pair.Dot.symbolic_dimensions | 1 | 26.3 [16, 43.8] |
| pair.Dot.tensor_dimensions | 1 | 25.8 [17.2, 45.7] |
| pair.Dot.permutations | 1 | 4.28 [2.98, 6] |
| pair.Dot.numeric_dot | 1 | 12.2 [3.54, 21.5] |
| pair.Dot.numeric_arraydot | 1 | 35.5 [9.88, 124] |
| replay.Dot.contractTreePath | 1 | 745 [382, 2.17e+03] |
| replay.Dot.contractStep | 1 | 294 [226, 572] |
| replay.Dot.contractTensorPair | 1 | 234 [208, 323] |
| replay.Dot.einsumDot | 1 | 231 [202, 394] |
| replay.Dot.settleLeaf | 2 | 18.5 [15.2, 28] |
| harness.replay_dispatch.Dot | 6 | 7.83 [3.97, 27.4] |
| execute.total.ArrayDot | 1 | 1.99e+03 [791, 2.88e+03] |
| execute.build_inactive.ArrayDot | 1 | 722 [394, 1.55e+03] |
| execute.activate_prebuilt.ArrayDot | 1 | 10.6 [8.97, 14.4] |
| pair.ArrayDot.symmetric_difference | 1 | 67.4 [54.1, 101] |
| pair.ArrayDot.contracted_labels | 1 | 127 [105, 183] |
| pair.ArrayDot.ordered_label_candidate | 1 | 7.25 [5.72, 8.1] |
| pair.ArrayDot.delete_elements_single | 1 | 42.6 [35, 56.1] |
| pair.ArrayDot.remaining_labels | 1 | 97.3 [70.4, 130] |
| pair.ArrayDot.position_indices | 1 | 4.04 [3.43, 5.75] |
| pair.ArrayDot.symbolic_dimensions | 1 | 19.1 [14.4, 20.8] |
| pair.ArrayDot.tensor_dimensions | 1 | 24 [18.8, 84.3] |
| pair.ArrayDot.permutations | 1 | 3.83 [3.07, 4.85] |
| pair.ArrayDot.numeric_dot | 1 | 3.12 [2.75, 4.39] |
| pair.ArrayDot.numeric_arraydot | 1 | 11.4 [9.75, 12.6] |
| replay.ArrayDot.contractTreePath | 1 | 568 [417, 782] |
| replay.ArrayDot.contractStep | 1 | 328 [264, 492] |
| replay.ArrayDot.contractTensorPair | 1 | 313 [300, 607] |
| replay.ArrayDot.einsumArrayDot | 1 | 312 [231, 324] |
| replay.ArrayDot.settleLeaf | 2 | 17.4 [14.9, 21.9] |
| harness.replay_dispatch.ArrayDot | 6 | 2.76 [2.45, 3.34] |
| automatic.cached_plan | 1 | 21.2 [19.2, 27.4] |
| automatic.warm_execute | 1 | 631 [468, 782] |

## chain-n4-d8-real

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 20.3 [17.7, 21.9] |
| key.leaf_signatures | 1 | 17.5 [15.2, 20.8] |
| key.mask_and_hash | 1 | 7.4 [3.88, 13.5] |
| key.unitize | 1 | 1.7 [1.26, 2.11] |
| key.hash_precomputed_masks | 1 | 1.17 [1.05, 1.61] |
| key.hash_fresh_masks | 1 | 3 [2, 6] |
| key.dimensions | 1 | 2.03 [1.88, 2.51] |
| key.precision | 1 | 0.976 [0.877, 1.26] |
| key.numeric_leaf | 1 | 8.17 [7.19, 10.1] |
| key.arrayq_numeric | 1 | 2.28 [2.03, 3.38] |
| key.sparse_full | 1 | 20.2 [16.8, 24.5] |
| key.cache_lookup_precomputed | 1 | 0.785 [0.432, 1.52] |
| execute.direct_dot | 1 | 1.77 [1.48, 1.97] |
| prepare.data | 1 | 76.7 [63, 106] |
| prepare.tree_predicate | 1 | 18.5 [14.7, 21.9] |
| prepare.tree_steps | 1 | 44.6 [37.7, 51.1] |
| prepare.label_dimensions | 1 | 43.5 [38.2, 55.1] |
| prepare.convert_leaves | 1 | 10.5 [7.96, 35.2] |
| prepare.computable_leaves | 1 | 11.4 [9.87, 12.3] |
| prepare.machine_precision_leaves | 1 | 12.8 [12.4, 14.6] |
| prepare.integer_scaled_leaves | 1 | 12.2 [9.96, 17.9] |
| prepare.represent_leaves | 1 | 7.37 [6.53, 8.04] |
| prepare.holder_counts | 1 | 5.92 [4.42, 7.01] |
| prepare.leaf_association | 1 | 2.26 [2.02, 2.56] |
| execute.total.Dot | 1 | 1.07e+03 [954, 1.51e+03] |
| execute.build_inactive.Dot | 1 | 1.35e+03 [1.19e+03, 1.69e+03] |
| execute.activate_prebuilt.Dot | 1 | 1.87 [1.63, 3.01] |
| pair.Dot.symmetric_difference | 3 | 166 [145, 224] |
| pair.Dot.contracted_labels | 3 | 373 [284, 432] |
| pair.Dot.ordered_label_candidate | 3 | 20.2 [16.7, 26] |
| pair.Dot.delete_elements_single | 3 | 133 [102, 162] |
| pair.Dot.remaining_labels | 3 | 285 [209, 339] |
| pair.Dot.position_indices | 3 | 8.62 [7.69, 12.4] |
| pair.Dot.symbolic_dimensions | 3 | 46.8 [39.9, 63.3] |
| pair.Dot.tensor_dimensions | 3 | 53 [50, 59.9] |
| pair.Dot.permutations | 3 | 9.1 [7.33, 10.3] |
| pair.Dot.numeric_dot | 3 | 4.72 [3.3, 5.15] |
| pair.Dot.numeric_arraydot | 3 | 21.4 [15.8, 25.3] |
| replay.Dot.contractTreePath | 1 | 1.19e+03 [885, 2.09e+03] |
| replay.Dot.contractStep | 3 | 889 [742, 1.22e+03] |
| replay.Dot.contractTensorPair | 3 | 856 [618, 970] |
| replay.Dot.einsumDot | 3 | 662 [571, 793] |
| replay.Dot.settleLeaf | 4 | 31 [28, 38.8] |
| harness.replay_dispatch.Dot | 14 | 5.02 [4.99, 5.81] |
| execute.total.ArrayDot | 1 | 1.19e+03 [972, 1.44e+03] |
| execute.build_inactive.ArrayDot | 1 | 966 [912, 1.18e+03] |
| execute.activate_prebuilt.ArrayDot | 1 | 17.7 [15, 21.7] |
| pair.ArrayDot.symmetric_difference | 3 | 195 [159, 214] |
| pair.ArrayDot.contracted_labels | 3 | 375 [333, 513] |
| pair.ArrayDot.ordered_label_candidate | 3 | 18.1 [16.8, 27.3] |
| pair.ArrayDot.delete_elements_single | 3 | 169 [124, 189] |
| pair.ArrayDot.remaining_labels | 3 | 268 [232, 322] |
| pair.ArrayDot.position_indices | 3 | 10.3 [7.72, 11.8] |
| pair.ArrayDot.symbolic_dimensions | 3 | 46 [42, 55.8] |
| pair.ArrayDot.tensor_dimensions | 3 | 45.2 [42.8, 57.6] |
| pair.ArrayDot.permutations | 3 | 8.25 [7.1, 9.54] |
| pair.ArrayDot.numeric_dot | 3 | 3.62 [3.12, 4.7] |
| pair.ArrayDot.numeric_arraydot | 3 | 20.5 [17.3, 22.5] |
| replay.ArrayDot.contractTreePath | 1 | 987 [793, 1.22e+03] |
| replay.ArrayDot.contractStep | 3 | 841 [630, 1.02e+03] |
| replay.ArrayDot.contractTensorPair | 3 | 779 [608, 855] |
| replay.ArrayDot.einsumArrayDot | 3 | 601 [570, 741] |
| replay.ArrayDot.settleLeaf | 4 | 28.6 [25.7, 34.9] |
| harness.replay_dispatch.ArrayDot | 14 | 6.09 [5.03, 8.5] |
| automatic.cached_plan | 1 | 20.5 [20.4, 23.8] |
| automatic.warm_execute | 1 | 1.19e+03 [1.11e+03, 1.7e+03] |

## chain-n12-d16-real

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 52.5 [48.7, 53.8] |
| key.leaf_signatures | 1 | 53.3 [49.5, 70.2] |
| key.mask_and_hash | 1 | 34.5 [24.6, 52.6] |
| key.unitize | 1 | 5.05 [3.3, 5.79] |
| key.hash_precomputed_masks | 1 | 2.53 [2.17, 2.81] |
| key.hash_fresh_masks | 1 | 19 [19, 20] |
| key.dimensions | 1 | 4.9 [4.57, 6.37] |
| key.precision | 1 | 1.8 [1.52, 2.28] |
| key.numeric_leaf | 1 | 12.1 [11.7, 13.7] |
| key.arrayq_numeric | 1 | 5.68 [4.43, 6.12] |
| key.sparse_full | 1 | 37.3 [33.7, 49.5] |
| key.cache_lookup_precomputed | 1 | 0.427 [0.425, 0.689] |
| execute.direct_dot | 1 | 7.6 [7.14, 10.9] |
| prepare.data | 1 | 209 [143, 279] |
| prepare.tree_predicate | 1 | 37.4 [33.9, 43.1] |
| prepare.tree_steps | 1 | 91.8 [85.3, 108] |
| prepare.label_dimensions | 1 | 115 [105, 123] |
| prepare.convert_leaves | 1 | 7.36 [7.12, 9.25] |
| prepare.computable_leaves | 1 | 17.9 [15.4, 22.4] |
| prepare.machine_precision_leaves | 1 | 20.1 [18.1, 25.7] |
| prepare.integer_scaled_leaves | 1 | 17.7 [15.4, 26.2] |
| prepare.represent_leaves | 1 | 10.6 [9.99, 15.3] |
| prepare.holder_counts | 1 | 9.26 [8.71, 11.6] |
| prepare.leaf_association | 1 | 4.09 [3.37, 5.2] |
| execute.total.Dot | 1 | 3.37e+03 [3.13e+03, 4.25e+03] |
| execute.build_inactive.Dot | 1 | 7.81e+03 [6e+03, 9.01e+03] |
| execute.activate_prebuilt.Dot | 1 | 8.5 [7.92, 8.96] |
| pair.Dot.symmetric_difference | 11 | 584 [524, 748] |
| pair.Dot.contracted_labels | 11 | 1.13e+03 [1.03e+03, 1.36e+03] |
| pair.Dot.ordered_label_candidate | 11 | 64.2 [59.5, 71.3] |
| pair.Dot.delete_elements_single | 11 | 524 [421, 880] |
| pair.Dot.remaining_labels | 11 | 1e+03 [865, 1.32e+03] |
| pair.Dot.position_indices | 11 | 31.4 [26.6, 46.3] |
| pair.Dot.symbolic_dimensions | 11 | 189 [143, 213] |
| pair.Dot.tensor_dimensions | 11 | 177 [163, 220] |
| pair.Dot.permutations | 11 | 29.8 [26, 39] |
| pair.Dot.numeric_dot | 11 | 16.9 [13.3, 17.6] |
| pair.Dot.numeric_arraydot | 11 | 94.4 [82.4, 107] |
| replay.Dot.contractTreePath | 1 | 3.44e+03 [2.79e+03, 5.42e+03] |
| replay.Dot.contractStep | 11 | 2.69e+03 [2.36e+03, 3.37e+03] |
| replay.Dot.contractTensorPair | 11 | 2.39e+03 [2.16e+03, 2.79e+03] |
| replay.Dot.einsumDot | 11 | 2.5e+03 [2.23e+03, 3.86e+03] |
| replay.Dot.settleLeaf | 12 | 96 [73.5, 110] |
| harness.replay_dispatch.Dot | 46 | 18.8 [16.7, 20.6] |
| execute.total.ArrayDot | 1 | 4.02e+03 [3.35e+03, 5.05e+03] |
| execute.build_inactive.ArrayDot | 1 | 3.92e+03 [3.23e+03, 4.44e+03] |
| execute.activate_prebuilt.ArrayDot | 1 | 81.6 [74.3, 100] |
| pair.ArrayDot.symmetric_difference | 11 | 659 [596, 959] |
| pair.ArrayDot.contracted_labels | 11 | 1.4e+03 [1.08e+03, 1.66e+03] |
| pair.ArrayDot.ordered_label_candidate | 11 | 73.3 [58.8, 95.3] |
| pair.ArrayDot.delete_elements_single | 11 | 526 [429, 634] |
| pair.ArrayDot.remaining_labels | 11 | 852 [753, 1.1e+03] |
| pair.ArrayDot.position_indices | 11 | 27.9 [26.2, 34.9] |
| pair.ArrayDot.symbolic_dimensions | 11 | 183 [146, 219] |
| pair.ArrayDot.tensor_dimensions | 11 | 186 [165, 214] |
| pair.ArrayDot.permutations | 11 | 30 [26.9, 31.3] |
| pair.ArrayDot.numeric_dot | 11 | 16.9 [14.4, 19.4] |
| pair.ArrayDot.numeric_arraydot | 11 | 89.7 [79.8, 98] |
| replay.ArrayDot.contractTreePath | 1 | 3.96e+03 [3.12e+03, 4.55e+03] |
| replay.ArrayDot.contractStep | 11 | 2.96e+03 [2.35e+03, 3.77e+03] |
| replay.ArrayDot.contractTensorPair | 11 | 2.4e+03 [2.13e+03, 2.47e+03] |
| replay.ArrayDot.einsumArrayDot | 11 | 3.21e+03 [2.53e+03, 3.55e+03] |
| replay.ArrayDot.settleLeaf | 12 | 100 [89, 119] |
| harness.replay_dispatch.ArrayDot | 46 | 17.5 [15.2, 21.9] |
| automatic.cached_plan | 1 | 70.4 [59.6, 76] |
| automatic.warm_execute | 1 | 4.31e+03 [3.59e+03, 4.86e+03] |

## chain-n12-d64-real

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 322 [302, 448] |
| key.leaf_signatures | 1 | 330 [297, 499] |
| key.mask_and_hash | 1 | 369 [346, 803] |
| key.unitize | 1 | 23.3 [15.3, 34.2] |
| key.hash_precomputed_masks | 1 | 4.97 [3.72, 11.5] |
| key.hash_fresh_masks | 1 | 1.3e+03 [286, 2.56e+03] |
| key.dimensions | 1 | 15.9 [5.45, 123] |
| key.precision | 1 | 2.4 [2, 12.6] |
| key.numeric_leaf | 1 | 16 [12.6, 18.4] |
| key.arrayq_numeric | 1 | 5.12 [4.7, 6.58] |
| key.sparse_full | 1 | 50.2 [38.9, 67.6] |
| key.cache_lookup_precomputed | 1 | 0.528 [0.425, 0.83] |

## chain-n12-d256-real

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 4.65e+03 [4.02e+03, 5.57e+03] |
| key.leaf_signatures | 1 | 5.44e+03 [4.11e+03, 6.24e+03] |
| key.mask_and_hash | 1 | 4.1e+03 [4.01e+03, 5.19e+03] |
| key.unitize | 1 | 404 [363, 746] |
| key.hash_precomputed_masks | 1 | 2.5 [2.2, 3.96] |
| key.hash_fresh_masks | 1 | 6.84e+03 [3.9e+03, 9.91e+03] |
| key.dimensions | 1 | 6.42 [5.74, 8.26] |
| key.precision | 1 | 2.27 [1.65, 5.01] |
| key.numeric_leaf | 1 | 16.5 [14.4, 46.1] |
| key.arrayq_numeric | 1 | 6.6 [4.44, 9.79] |
| key.sparse_full | 1 | 70.3 [40.6, 96] |
| key.cache_lookup_precomputed | 1 | 0.534 [0.448, 0.585] |

## chain-n12-d16-complex

| Component | Calls per replay | Median [min, max], us |
|---|---:|---:|
| key.total | 1 | 63.1 [53, 70.1] |
| key.leaf_signatures | 1 | 74.6 [48.8, 158] |
| key.mask_and_hash | 1 | 30.1 [26.7, 37.1] |
| key.unitize | 1 | 4.13 [3.62, 5.97] |
| key.hash_precomputed_masks | 1 | 2.22 [2.14, 3.11] |
| key.hash_fresh_masks | 1 | 20 [19, 21] |
| key.dimensions | 1 | 5.25 [5.04, 6.22] |
| key.precision | 1 | 2.04 [1.65, 2.76] |
| key.numeric_leaf | 1 | 13.5 [13, 15.3] |
| key.arrayq_numeric | 1 | 5.85 [4.91, 7.12] |
| key.sparse_full | 1 | 46.7 [34.5, 54.3] |
| key.cache_lookup_precomputed | 1 | 0.647 [0.426, 0.889] |
| execute.direct_dot | 1 | 22.7 [15.8, 30.8] |
| prepare.data | 1 | 191 [167, 229] |
| prepare.tree_predicate | 1 | 37.8 [35.8, 49.8] |
| prepare.tree_steps | 1 | 111 [84.3, 127] |
| prepare.label_dimensions | 1 | 127 [93.7, 181] |
| prepare.convert_leaves | 1 | 8.64 [7.2, 10.6] |
| prepare.computable_leaves | 1 | 18.4 [15.2, 23.3] |
| prepare.machine_precision_leaves | 1 | 21.6 [18.3, 27] |
| prepare.integer_scaled_leaves | 1 | 19.3 [16.4, 26.8] |
| prepare.represent_leaves | 1 | 12.3 [10.5, 15.7] |
| prepare.holder_counts | 1 | 13.1 [10.1, 14.6] |
| prepare.leaf_association | 1 | 4.47 [3.49, 5.2] |
| execute.total.Dot | 1 | 4.13e+03 [3.37e+03, 4.74e+03] |
| execute.build_inactive.Dot | 1 | 6.72e+03 [6.05e+03, 8.89e+03] |
| execute.activate_prebuilt.Dot | 1 | 26.9 [22.8, 40.5] |
| pair.Dot.symmetric_difference | 11 | 808 [619, 889] |
| pair.Dot.contracted_labels | 11 | 1.27e+03 [1.07e+03, 1.81e+03] |
| pair.Dot.ordered_label_candidate | 11 | 101 [59.4, 113] |
| pair.Dot.delete_elements_single | 11 | 530 [393, 636] |
| pair.Dot.remaining_labels | 11 | 1.19e+03 [847, 1.69e+03] |
| pair.Dot.position_indices | 11 | 34.4 [30, 49.8] |
| pair.Dot.symbolic_dimensions | 11 | 209 [168, 251] |
| pair.Dot.tensor_dimensions | 11 | 186 [163, 285] |
| pair.Dot.permutations | 11 | 32.7 [26.9, 34.2] |
| pair.Dot.numeric_dot | 11 | 25.6 [22.7, 31.4] |
| pair.Dot.numeric_arraydot | 11 | 99.4 [89.7, 123] |
| replay.Dot.contractTreePath | 1 | 3.76e+03 [3.43e+03, 4.98e+03] |
| replay.Dot.contractStep | 11 | 3.13e+03 [2.87e+03, 4.65e+03] |
| replay.Dot.contractTensorPair | 11 | 2.84e+03 [2.19e+03, 3.93e+03] |
| replay.Dot.einsumDot | 11 | 2.37e+03 [2.14e+03, 2.81e+03] |
| replay.Dot.settleLeaf | 12 | 93.9 [73.8, 112] |
| harness.replay_dispatch.Dot | 46 | 18.3 [16.2, 22.4] |
| execute.total.ArrayDot | 1 | 3.93e+03 [3.3e+03, 5.67e+03] |
| execute.build_inactive.ArrayDot | 1 | 4.41e+03 [3.4e+03, 5.16e+03] |
| execute.activate_prebuilt.ArrayDot | 1 | 93.6 [84.8, 123] |
| pair.ArrayDot.symmetric_difference | 11 | 720 [534, 754] |
| pair.ArrayDot.contracted_labels | 11 | 1.41e+03 [1.04e+03, 1.8e+03] |
| pair.ArrayDot.ordered_label_candidate | 11 | 70.6 [57.3, 84.4] |
| pair.ArrayDot.delete_elements_single | 11 | 442 [378, 500] |
| pair.ArrayDot.remaining_labels | 11 | 919 [807, 1.14e+03] |
| pair.ArrayDot.position_indices | 11 | 38.8 [29.5, 42.8] |
| pair.ArrayDot.symbolic_dimensions | 11 | 166 [144, 179] |
| pair.ArrayDot.tensor_dimensions | 11 | 184 [169, 211] |
| pair.ArrayDot.permutations | 11 | 28.8 [27, 32.5] |
| pair.ArrayDot.numeric_dot | 11 | 28.7 [23, 43.3] |
| pair.ArrayDot.numeric_arraydot | 11 | 105 [96.2, 134] |
| replay.ArrayDot.contractTreePath | 1 | 3.57e+03 [2.86e+03, 4.23e+03] |
| replay.ArrayDot.contractStep | 11 | 3.21e+03 [2.55e+03, 3.72e+03] |
| replay.ArrayDot.contractTensorPair | 11 | 3.16e+03 [2.24e+03, 3.53e+03] |
| replay.ArrayDot.einsumArrayDot | 11 | 2.9e+03 [2.07e+03, 3.26e+03] |
| replay.ArrayDot.settleLeaf | 12 | 99 [74.8, 118] |
| harness.replay_dispatch.ArrayDot | 46 | 22.1 [19.2, 29.2] |
| automatic.cached_plan | 1 | 79.1 [61.4, 114] |
| automatic.warm_execute | 1 | 4.34e+03 [3.92e+03, 5.39e+03] |
