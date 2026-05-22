#!/usr/bin/env python3
"""Offline extractor for the cotengra Sycamore m=20 cost-convention fixture.

The Sycamore m=20 network (381 tensors, 754 legs) is too large for any
exhaustive optimal-path search. The original cotengra docs page reports a
cost of ~10**18 found by HyperOptimizer (which the paclet does not have).

What we *can* validate cross-package: given the *same* (inputs, size_dict, path),
both cotengra and the paclet must compute the same total flops cost (opt_einsum
convention, dim-product per merged tensor). This pins the cost-counting
convention on real Sycamore-class data.

We pick a fast, deterministic path via cotengra's GreedyOptimizer with seed=0,
record both the path and the cost cotengra reports for it, and let the paclet
recompute the cost.

Run once:
    .venv/bin/python extract_cotengra_sycamore_m20.py

Output: fixtures/cotengra_sycamore_m20.json
"""
import json
import sys
from pathlib import Path

import cotengra as ctg


SYCAMORE_JSON = Path(
    "/Users/mohammadb/Documents/GitHub/TensorNetworks/tn-external/numerical/"
    "cotengra/examples/benchmarks/sycamore_n53_m20_s0_e0_pABCDCDAB.json"
)


def main() -> int:
    with open(SYCAMORE_JSON) as f:
        d = json.load(f)
    inputs = [list(t) for t in d["inputs"]]
    output = list(d["output"])
    size_dict = {str(k): int(v) for k, v in d["size_dict"].items()}

    # temperature=0 → deterministic greedy (no RNG needed); accel disabled for portability
    opt = ctg.GreedyOptimizer(temperature=0.0, accel=False)
    path = opt(inputs, output, size_dict)
    tree = ctg.ContractionTree.from_path(inputs, output, size_dict, path=path)
    cost_total = int(tree.contraction_cost())  # opt_einsum mul-count convention

    payload = {
        "source": "cotengra examples/benchmarks/sycamore_n53_m20_s0_e0_pABCDCDAB.json (Google Quantum Supremacy circuit)",
        "cotengra_version": ctg.__version__,
        "extraction_optimizer": "GreedyOptimizer(temperature=0.0, accel=False)",
        "n_tensors": len(inputs),
        "n_legs": len(size_dict),
        "inputs": inputs,
        "output": output,
        "size_dict": size_dict,
        "path": [list(map(int, step)) for step in path],
        "expected_total_flops": cost_total,
        "note": "Validates that paclet pathCost matches cotengra contraction_cost on the same (inputs, size_dict, path). This is convention-pinning, not optimality validation.",
    }

    fixture_path = Path(__file__).parent / "fixtures" / "cotengra_sycamore_m20.json"
    fixture_path.parent.mkdir(parents=True, exist_ok=True)
    fixture_path.write_text(json.dumps(payload, indent=2))
    print(f"wrote {fixture_path}")
    print(f"  n_tensors  : {payload['n_tensors']}")
    print(f"  n_legs     : {payload['n_legs']}")
    print(f"  path steps : {len(payload['path'])}")
    print(f"  total flops: {cost_total:,d}")
    print(f"  log10 flops: {cost_total ** 0 and __import__('math').log10(cost_total):.4f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
