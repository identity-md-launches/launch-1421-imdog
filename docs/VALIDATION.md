# Local validation

Validation used Foundry 1.8.5 and Solidity 0.8.26 (`8a97fa7a`). The final code is
compiled with the committed root `foundry.toml` settings. No mainnet RPC, fork,
wallet, environment configuration or transaction broadcast was used.

## Results

| Check | Result |
| --- | --- |
| `forge build` | Passed with solc 0.8.26 |
| `forge test` | Passed: 35 reported test cases, 0 failed, 0 skipped |
| `forge fmt --check` | Passed |
| `python3 tools/check_metadata.py` | Exact metadata and original image checksum passed |
| `sha256sum --check --quiet lib/SHA256SUMS` | All 37 vendored files matched |
| ABI/artifact inspection | No constructor inputs, no library link references, metadata hash disabled |
| Runtime size | 2,740 bytes; creation bytecode 3,623 bytes |
| Runtime opcode test | No `DELEGATECALL`, `CALLCODE` or `SELFDESTRUCT` |

Foundry groups the three stateful invariants into one reported test case. There
are 34 unit/fuzz cases plus that invariant group. The four fuzz functions each
ran 512 cases. The invariant group executed 128 sequences of 64 calls (8,192
total handler calls), with zero unexpected reverts, checking all three
properties after generated actions.

A fresh temporary copy contained only the committed project directories and
configuration, excluding `.imd/`, `test/scratch/`, caches and build artifacts.
With only `PATH` set in the process environment, these checks also passed:

```sh
forge build --offline
forge test --offline --threads 4 --no-dynamic-test-linking
forge fmt --check
python3 tools/check_metadata.py
sha256sum --check --quiet lib/SHA256SUMS
```

The second test run exercises normal compiled deployment bytecode without
Foundry's dynamic test linking optimization. Its factory test deploys the token
through assembly `CREATE2`, checks the predicted address, verifies the full
supply belongs to that factory, and reads the logo metadata from the deployed
address. It also passed all 35 reported cases and 8,192 invariant calls.

The metadata checker was additionally run against temporary, deliberately
altered copies. It correctly rejected both a changed `image` URI and a
one-byte-truncated logo. The delivered image was never modified.

## Security review scope

Local source review used the supplied pinned security checklist. The production
code adds only a constructor mint and read-only metadata to the vendored ERC-20.
The constructor mints to `msg.sender`, makes no external calls and relies on no
preexisting contracts. The compiled ABI exposes no post-deployment mint, burn,
administration, metadata mutation or upgrade method. Library functions are
internal and leave no link placeholders.

Tests check successful transfers and delegation, return values and events,
finite/infinite/revoked approvals, unauthorized spending, zero recipients,
overspending, maximum values, self-transfers and zero-value transfers. Failed
transfers preserve balances and allowances. Factory/deployer privilege probes
cannot mint, seize, freeze or alter metadata; recipients can still transfer.
Transfers into contracts do not invoke their code. The supply and the complete
set of modeled holder balances remain equal through stateful testing.

The factory/distributor/pool tests cover **token transfer semantics** and exact
10%/88%/2% distribution accounting. They do not exercise actual Uniswap swaps,
Merkle proofs or production launch contracts. The pinned protected suite was
read and used to identify launch requirements; it was not run locally because
the supplied file depends on the launch system's contracts and resolved
deployment environment. Its full integration run belongs to that pipeline.

Slither and Mythril were not installed and were not run. This local review is
not an independent audit or an assertion that deployment has occurred. The
subsequent manifest, independent release review, protected integration run,
Ethereum deployment, explorer verification and external registry logo display
checks remain with the IdentityMD launch operator, as detailed in the README.
