#!/usr/bin/env python3
"""Offline extractor for the cotengra lattice[4,5] d_max=3 seed=42 fixture.

Reference: cotengra tests/test_paths_basic.py:194-205, which asserts
optimize_optimal cost == 1464 for this network.

Run once:
    .venv/bin/python extract_cotengra_lattice45.py

Output: fixtures/cotengra_lattice45_seed42.json
"""
import json
import sys
from pathlib import Path

import cotengra as ctg


def main() -> int:
    inputs, output, _, size_dict = ctg.utils.lattice_equation(
        [4, 5], d_max=3, seed=42,
    )
    inputs_list = [list(t) for t in inputs]
    output_list = list(output)
    size_dict_plain = {str(k): int(v) for k, v in size_dict.items()}

    payload = {
        "source": "cotengra tests/test_paths_basic.py:194-205",
        "cotengra_version": ctg.__version__,
        "seed": 42,
        "lattice_shape": [4, 5],
        "d_min_d_max": [2, 3],
        "inputs": inputs_list,
        "output": output_list,
        "size_dict": size_dict_plain,
        "expected_optimal_flops": 1464,
        "expected_optimal_width": 5.584962500721156,
    }

    fixture_path = Path(__file__).parent / "fixtures" / "cotengra_lattice45_seed42.json"
    fixture_path.parent.mkdir(parents=True, exist_ok=True)
    fixture_path.write_text(json.dumps(payload, indent=2))
    print(f"wrote {fixture_path}")
    print(f"  tensors: {len(inputs_list)}")
    print(f"  legs   : {len(size_dict_plain)}")
    print(f"  d=2 legs: {sum(1 for v in size_dict_plain.values() if v == 2)}")
    print(f"  d=3 legs: {sum(1 for v in size_dict_plain.values() if v == 3)}")
    print(f"  expected optimal flops: {payload['expected_optimal_flops']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
