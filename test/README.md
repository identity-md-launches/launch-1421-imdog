# IMDog test coverage

Run `forge build` and `forge test` from the repository root. The suite uses only
the already-vendored dependencies; it requires no RPC, network access, environment
variables, FFI, or filesystem cheatcode permissions. Fuzz and invariant run counts
are set in the Solidity test files.

| Suite | Properties checked |
| --- | --- |
| `IMDog.t.sol` | Exact identity, constructor allocation, fixed supply, official IPFS image and Base64 data URI, transfers/events, approval spending, atomic failures, absence of administrative entry points |
| `IMDogAdversarial.t.sol` | One-base-unit round trip, maximum finite versus infinite allowance, zero-source/recipient failures, self-spending rules, funding after a failed spend, revocation of infinite approvals, owner/spender isolation, approval replacement and idempotence, split-versus-single transfers, constructor caller versus transaction origin |
| `IMDogLaunch.t.sol` | Existing CREATE2 deployment and token-side factory/distributor/pool transfer models, logo read from the predicted deployed address, independent deployment supplies |
| `IMDogInvariant.t.sol` | Random sequences of successful and rejected operations, individual balances, total supply, all allowance pairs, full-balance transfer liveness, immutable identity and logo |

Each stateless fuzz property runs 1,000 cases. The stateful suite runs 256 sequences
of 64 handler calls with unexpected handler reverts treated as failures.

The invariant handler maintains a closed set of four holders, initially funded
with equal quarters of the specified supply. Its expected balances start from
that allocation and change only by successfully requested transfers; they are
never resynchronized from contract balances. An independent allowance ledger
tracks every owner/spender pair, including self-approval. Initial finite and
infinite approvals allow delegated spending immediately.

The eight handler entry points exercise transfers, approvals, delegated transfers,
direct overspending, delegated overspending, zero recipients, revocation followed
by attempted spending, and full-balance round trips. Approval generation explicitly
includes zero, unlimited, bounded finite, and unrestricted uint256 values. Rejected
operations must return the expected custom error and preserve balances and
allowances. The global properties compare all four balances and all sixteen
allowance pairs after generated actions, not just the accounts touched by a call.
No token balances or storage slots are fabricated with cheatcodes.

The fixed-supply and official-image expectations come from the assignment. The
transfer, allowance, and revert properties exercise the accepted OpenZeppelin
ERC-20 behavior. Known boundaries (zero, one, full supply, uint256 maximum and
maximum minus one) have explicit examples alongside bounded fuzz inputs.

The launch model checks token transfer behavior only. It does not execute
`ProjectFactory.launchCustom`, a real Uniswap pool, or a Merkle distributor. The
provided protected integration suite depends on launch-system contracts and
resolved deployment settings that are not in this repository. External token
registration and wallet logo rendering are also outside these offline tests.
The tests verify the exact on-chain IPFS URI; they do not download or alter the
official image.
