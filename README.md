# IMDog (IMDOG)

IMDog is a fixed-supply ERC-20 for the IdentityMD custom-token launch on Ethereum
(chain ID **1**). The production contract is [`src/IMDog.sol`](src/IMDog.sol).
It mints **1,000,000,000 IMDOG**, with **18 decimals**, exactly once to its
constructor caller. During the standard launch this caller is IdentityMD's
factory. The supply in minor units is **1000000000000000000000000000**.

The deliverable contains one production token and its metadata. There are no
application contracts. Deployment, the launch manifest, liquidity creation and
external logo registration belong to IdentityMD's subsequent launch process;
this repository does not broadcast transactions or contain a deployed address.

## Build and check

Run from the repository root with Foundry and Solidity 0.8.26 installed:

```sh
forge build
forge test
forge fmt --check
python3 tools/check_metadata.py
sha256sum -c lib/SHA256SUMS
```

All Solidity dependencies are ordinary files under `lib/`. Builds and tests do
not need network access, a fork, environment variables, keys, FFI or filesystem
cheatcode permissions. `foundry.toml` pins solc 0.8.26, Cancun, the optimizer at
200 runs, and `bytecode_hash = "none"`. Dependency versions, source archive
hashes and licenses are recorded in [`lib/README.md`](lib/README.md).

The tests cover constructor minting and events, transfers, approvals, exact
allowance spending, invalid inputs, rollback on failure, the absence of
administrative powers, immutable logo metadata, CREATE2 deployment by a factory,
and launch distribution amounts. Fuzz tests use 512 inputs each. Stateful
invariants use 128 sequences of 64 calls per invariant to check balance
conservation, allowances and immutable identity.

The launch tests model token-side factory, distributor and pool transfers. They
do not implement Uniswap, price discovery, Merkle proofs or IdentityMD's factory.
The supplied protected integration suite is evaluated by the launch pipeline
against its actual launch infrastructure and resolved manifest parameters.

## Official logo and metadata

The official image is exactly the requester-provided asset:

```text
ipfs://bafybeie5pg3kfdo6fl7dllampv44j2bymf46j554n5ehdmsryl5ejbrdre
```

The token exposes three read-only metadata methods:

| Method | Result |
| --- | --- |
| `LOGO_URI()` | The exact permanent IPFS image URI above |
| `metadataJSON()` | JSON with name, symbol, decimals, description and `image` |
| `contractURI()` | A `data:application/json;base64,` URI containing that JSON |

The `image` field is the supplied **IPFS URI**, not a gateway URL or a generated
image. It is embedded in the token's code and has no setter. Reading metadata
from the deployed token address therefore binds that token to this logo without
an initialization transaction or a separately hosted metadata service.

[`metadata/IMDog.json`](metadata/IMDog.json) is the matching metadata document for
launch/indexer ingestion. [`metadata/logo.png`](metadata/logo.png) is a byte-for-byte
copy downloaded from the supplied gateway, with no generation, resizing or
other processing. Its source and checksum are in
[`metadata/README.md`](metadata/README.md).

ERC-20 does not standardize wallet logo discovery. Services that do not consume
`contractURI()` must associate the actual deployed address on chain 1 with the
same image URI in their token registry. The launch operator performs that
external registration after the factory reports the address; an on-chain
metadata method alone cannot force every wallet to display a logo.

## IdentityMD launch handoff

The separate manifest step creates `launch.json` after acceptance. These are the
parameters supplied by the assignment, recorded here for that handoff:

| Parameter | Value |
| --- | --- |
| Launch kind / entry point | `custom_token` / `ProjectFactory.launchCustom` |
| Token Solidity identifier | `IMDog` (artifact `out/IMDog.sol/IMDog.json`) |
| Name / symbol / decimals | `IMDog` / `IMDOG` / `18` |
| Constructor arguments | `[]` (no arguments or initialization calls) |
| Total supply, minor units | `1000000000000000000000000000` |
| Application contracts | `[]` |
| Chain | Ethereum, chain ID `1` |
| Pair | Native ETH; `pairedCurrency = 0x0000000000000000000000000000000000000000` is the native-currency sentinel |
| Pool fee / tick spacing | `12500` (1.25%) / `60` |
| Pool initialPrice, provenance | `"79228162514264337593543950336"` |
| `economics.poolBps` | `8800` |
| `economics.initialMarketCapWei` | `"10000000000000000000"` (10 ETH) |
| `economics.remainderTo` | `0xf2816f3f05fac35577b1930ffd09b531b62628df` |
| Official metadata image | `ipfs://bafybeie5pg3kfdo6fl7dllampv44j2bymf46j554n5ehdmsryl5ejbrdre` |

The token constructor neither allocates shares nor calls outside contracts. The
factory first holds all the tokens, sends 10% (100,000,000 IMDOG) to its
MerkleDistributor, uses the requester's 88% (880,000,000 IMDOG) pool allocation,
and forwards the remaining 2% (20,000,000 IMDOG) to the specified recipient under
the launch policy. The factory and distributor implement the contributor share:
2% of total supply for accepted contributors and 8% for connected paired seats.
The token introduces no alternative distribution or reserved balance.

The recorded one-to-one `initialPrice` is provenance. The launch computes the
actual opening pool price and liquidity from the 10 ETH initial market cap,
supply and token address, including currency ordering and liquidity rounding.
The token does not set that price or require constructor addresses for the
factory, pool manager or distributor. Every transfer delivers the exact amount.

## After launch

The IdentityMD launch operator is responsible for:

1. Running the independent review and protected launch integration checks,
   creating the final manifest, and deploying the compiled `IMDog` creation
   bytecode through the approved factory. A direct wallet deployment would mint
   to that wallet and would not perform the IdentityMD launch distributions.
2. Recording the actual factory-emitted token address and transaction on
   Ethereum, verifying its source/build settings on the explorer, and checking
   `name()`, `symbol()`, `decimals()` and `totalSupply()` against the table above.
3. Reading `LOGO_URI()`, `metadataJSON()` and `contractURI()` from that address.
   Decode the data URI and confirm `image` equals the exact IPFS URI. Register
   **chain ID 1 plus that actual token address** and this metadata/logo with
   IdentityMD and any explorer or wallet token list used for the launch. Check
   the rendered logo there after indexing; use the supplied image bytes if a
   registry requires a file upload.
4. Checking the factory's distribution and pool events, verifying claims and
   trades through the launch infrastructure, and maintaining availability of
   the original IPFS content by pinning that same CID as needed. Pinning does
   not authorize changing the image or replacing the CID.

There are no owner-settable values or ongoing token administration. No private
key, recipient placeholder, guessed infrastructure address or approval
transaction is needed to build this token.

## Design and security assumptions

- IMDog uses the vendored OpenZeppelin ERC-20 implementation. Supply is minted
  only in the constructor; there is no callable mint, burn, ownership, pause,
  blacklist, seizure, transfer tax, proxy or upgrade mechanism.
- Transfers and allowances follow ordinary ERC-20 behavior, including zero-value
  transfers, self-transfers, and an unchanged maximum allowance on spending.
  Invalid recipients, insufficient balances and insufficient approvals revert.
  Users control their own approvals; revoke unneeded allowances and account for
  the usual approval-replacement transaction ordering risk.
- Token methods make no external calls or recipient callbacks. The token has no
  oracle, randomness, time-dependent logic, hooks, pool configuration or custody
  of the paired ETH. The 1.25% fee is a pool fee, not a token transfer fee.
- Metadata is permanently fixed. IPFS content addressing fixes identity, while
  availability still depends on someone serving or pinning the content. Wallet
  display depends on each service's indexing support.
- There is no token rescue function. Tokens sent to the token contract or other
  contracts unable to send them back can remain inaccessible. Ordinary ETH
  sends revert; forcibly delivered ETH is not recoverable through this token.
- Local tests and source review are not an independent audit. Production launch
  infrastructure, integration checks, external registration and release review
  remain the launch operator's responsibility. See
  [`docs/VALIDATION.md`](docs/VALIDATION.md) for local verification scope.
