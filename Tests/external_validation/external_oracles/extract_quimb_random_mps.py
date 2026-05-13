#!/usr/bin/env python3
"""Offline extractor for the quimb random MPS cross-language fixture.

Reference: replaces the F7 'random PEPS norm ~0.5078' skip. The original test
asked for an RNG-tied scalar that nothing else could reproduce. Here we go the
other direction: build an *unnormalized* random MPS in quimb, write the exact
site-tensor arrays to a fixture, and compute reference scalars
(norm-squared and per-site <Z_i>) in quimb. The WL test loads the same arrays,
reconstructs the bra-ket TN, contracts via paclet primitives, and matches.

Run once:
    .venv/bin/python extract_quimb_random_mps.py

Output: fixtures/quimb_random_mps_seed42.json
"""
import json
import sys
from pathlib import Path

import numpy as np
import quimb
import quimb.tensor as qtn


def main() -> int:
    L, D, d = 6, 4, 2
    rng = np.random.default_rng(42)
    # First site: (D, d) = (right-bond, phys). Last site: (D, d) = (left-bond, phys).
    # Interior: (D, D, d) = (left, right, phys).
    shapes = [(D, d)] + [(D, D, d)] * (L - 2) + [(D, d)]
    arrs = [rng.standard_normal(s) for s in shapes]

    mps = qtn.MatrixProductState(arrs, shape="lrp")
    norm_sq = float((mps.H & mps).contract(all))

    sz = np.diag([1.0, -1.0])
    zexp = []
    for site in range(L):
        ket = mps.copy()
        ket.gate_(sz, site, contract=True)
        zexp.append(float((mps.H & ket).contract(all)))

    payload = {
        "source": "quimb MatrixProductState + manual Z-sandwich (reframed F7)",
        "quimb_version": quimb.__version__,
        "rng_seed": 42,
        "L": L,
        "bond_dim": D,
        "phys_dim": d,
        "leg_convention": "first/last sites: (bond, phys); interior: (left, right, phys)",
        "tensors": [a.tolist() for a in arrs],
        "expected_norm_sq": norm_sq,
        "expected_z_expectations": zexp,
        "note": "Tensors are unnormalized; reference scalars include both norm-squared and per-site <Z> with no normalization.",
    }

    fixture_path = Path(__file__).parent / "fixtures" / "quimb_random_mps_seed42.json"
    fixture_path.parent.mkdir(parents=True, exist_ok=True)
    fixture_path.write_text(json.dumps(payload, indent=2))
    print(f"wrote {fixture_path}")
    print(f"  norm^2 = {norm_sq:.16f}")
    print(f"  <Z_0> .. <Z_{L-1}> = {[f'{z:.4f}' for z in zexp]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
