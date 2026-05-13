#!/usr/bin/env python3
"""Offline extractor for the quimb 3x3 PEPS local-expectation fixture.

The original T6 ('quimb 5x5 PEPS local_expectation = 0.000487') was infeasible
to validate directly because (a) 5x5 PEPS exceeds exact contraction and
(b) the value was specific to quimb's RNG seed. We promote it to a direct
test by:

  - Dropping to 3x3 PEPS where exact contraction is tractable (Bond_dim=2 -> 9
    tensors, max rank 5; contraction width small).
  - Extracting quimb's actual PEPS site tensors (with leg labels preserved
    verbatim) into a fixture.
  - Computing reference scalars in quimb: norm-squared and per-site <Z>.

The WL test reconstructs the same TN (same arrays, same leg labels), contracts
via paclet TensorNetwork/TensorNetworkContract, and verifies all 10 reference
scalars within tolerance.

Run once:
    .venv/bin/python extract_quimb_peps_3x3.py

Output: fixtures/quimb_peps_3x3_seed42.json
"""
import json
import sys
from pathlib import Path

import numpy as np
import quimb
import quimb.tensor as qtn


def main() -> int:
    Lx, Ly, D, d = 3, 3, 2, 2
    peps = qtn.PEPS.rand(Lx, Ly, bond_dim=D, phys_dim=d, seed=42)

    # ----- Capture tensor data + leg labels verbatim from quimb -----
    site_tensors = []
    for site in [(i, j) for i in range(Lx) for j in range(Ly)]:
        t = peps[site]
        arr = np.asarray(t.data, dtype=np.float64).tolist()
        legs = list(t.inds)
        site_tensors.append({"site": list(site), "legs": legs, "data": arr})

    # ----- Reference scalars -----
    norm_sq = float((peps.H & peps).contract(all))

    sz = np.diag([1.0, -1.0]).tolist()
    z_expecs = {}
    for (i, j) in [(i, j) for i in range(Lx) for j in range(Ly)]:
        ket = peps.copy()
        ket.gate_(np.diag([1.0, -1.0]), where=(i, j), contract=True)
        z_expecs[f"{i},{j}"] = float((peps.H & ket).contract(all))

    # ----- Physical-leg names per site (for the WL gate test) -----
    phys_legs = {f"{i},{j}": peps.site_ind(i, j)
                 for i in range(Lx) for j in range(Ly)}

    payload = {
        "source": "quimb PEPS.rand 3x3 seed=42 (reframed T6, was '5x5 PEPS local_expectation')",
        "quimb_version": quimb.__version__,
        "rng_seed": 42,
        "Lx": Lx,
        "Ly": Ly,
        "bond_dim": D,
        "phys_dim": d,
        "site_tensors": site_tensors,
        "phys_legs": phys_legs,
        "z_matrix": sz,
        "expected_norm_sq": norm_sq,
        "expected_z_expectations": z_expecs,
        "note": "site_tensors carries quimb's verbatim leg labels; WL must use the same labels when reconstructing the TN.",
    }

    fixture_path = Path(__file__).parent / "fixtures" / "quimb_peps_3x3_seed42.json"
    fixture_path.parent.mkdir(parents=True, exist_ok=True)
    fixture_path.write_text(json.dumps(payload, indent=2))
    print(f"wrote {fixture_path}")
    print(f"  norm^2 = {norm_sq:.6f}")
    print(f"  <Z_(1,1)> = {z_expecs['1,1']:.6f}")
    print(f"  9 expectation values total")
    return 0


if __name__ == "__main__":
    sys.exit(main())
