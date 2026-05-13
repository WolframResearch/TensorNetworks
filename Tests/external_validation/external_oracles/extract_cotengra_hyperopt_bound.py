#!/usr/bin/env python3
"""Offline extractor for the HyperOptimizer-vs-exhaustive cost bound test.

Original B8 was an "exact path match" test — infeasible because cotengra's
HyperOptimizer is stochastic (KaHyPar + cmaes/optuna RNG). The reframed
assertion: on a moderate-size random regular network, the paclet's
exhaustive OptimalContractionPath must find a cost <= any heuristic.

We extract cotengra HyperOptimizer's best cost on a randreg(n=12, reg=3)
network with seed=11; save (inputs, output, size_dict, hyperopt_cost) to a
fixture. The WL test runs OptimalContractionPath on the same network and
asserts paclet_cost <= hyperopt_cost.

Run once:
    .venv/bin/python extract_cotengra_hyperopt_bound.py

Output: fixtures/cotengra_hyperopt_bound.json
"""
import json
import sys
from pathlib import Path

import cotengra as ctg


def main() -> int:
    inputs, output, _, size_dict = ctg.utils.randreg_equation(
        n=12, reg=3, d_min=2, d_max=3, seed=11,
    )
    inputs = [list(t) for t in inputs]
    output = list(output)
    size_dict = {str(k): int(v) for k, v in size_dict.items()}

    # HyperOptimizer with deterministic backends — no KaHyPar (not always available);
    # rely on greedy + reconfigure which are stable enough for a cost upper bound.
    opt = ctg.HyperOptimizer(
        methods=["greedy"], max_repeats=64, parallel=False, progbar=False
    )
    path = opt(inputs, output, size_dict)
    tree = ctg.ContractionTree.from_path(inputs, output, size_dict, path=path)
    hyperopt_cost = int(tree.contraction_cost())

    payload = {
        "source": "cotengra tests/test_optimizers.py:139-167 (reframed: cost upper bound from HyperOptimizer)",
        "cotengra_version": ctg.__version__,
        "network_builder": "randreg_equation(n=12, reg=3, d_min=2, d_max=3, seed=11)",
        "extraction_optimizer": "HyperOptimizer(methods=['greedy'], max_repeats=64)",
        "n_tensors": len(inputs),
        "n_legs": len(size_dict),
        "inputs": inputs,
        "output": output,
        "size_dict": size_dict,
        "hyperopt_cost": hyperopt_cost,
        "note": "Paclet's exhaustive OptimalContractionPath must find cost <= this bound.",
    }

    fixture_path = Path(__file__).parent / "fixtures" / "cotengra_hyperopt_bound.json"
    fixture_path.parent.mkdir(parents=True, exist_ok=True)
    fixture_path.write_text(json.dumps(payload, indent=2))
    print(f"wrote {fixture_path}")
    print(f"  n_tensors    : {payload['n_tensors']}")
    print(f"  n_legs       : {payload['n_legs']}")
    print(f"  hyperopt cost: {hyperopt_cost:,d}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
