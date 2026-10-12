#!/usr/bin/env python3
"""Verify the shipped token metadata and unchanged official logo, offline."""

import hashlib
import json
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    expected = {
        "name": "IMDog",
        "symbol": "IMDOG",
        "decimals": 18,
        "description": "IMDog meme token on IdentityMD.",
        "image": "ipfs://bafybeie5pg3kfdo6fl7dllampv44j2bymf46j554n5ehdmsryl5ejbrdre",
    }
    metadata = json.loads((root / "metadata/IMDog.json").read_text(encoding="utf-8"))
    if metadata != expected:
        raise SystemExit("FAIL: token metadata differs from the approved identity/image")

    logo = (root / "metadata/logo.png").read_bytes()
    expected_sha256 = "598a473eb52fa3e075f10b5785564e698d684b7b8cf52ecfa7c57c4657c0d628"
    if len(logo) != 1_916_448 or hashlib.sha256(logo).hexdigest() != expected_sha256:
        raise SystemExit("FAIL: official logo bytes have changed")

    print("PASS: IMDog metadata uses the exact IPFS URI; original logo bytes are unchanged.")


if __name__ == "__main__":
    main()
