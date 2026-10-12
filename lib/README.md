# Vendored Solidity dependencies

All dependency files are ordinary, unmodified source files, with their upstream
licenses. No installation, git submodule or network resolution is needed.

## OpenZeppelin Contracts v5.0.2

- Source: <https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v5.0.2>
- Archive: <https://codeload.github.com/OpenZeppelin/openzeppelin-contracts/tar.gz/refs/tags/v5.0.2>
- Archive SHA-256: `18c7b7e949b9a82dcd8cd394426c9c2636dfc263aa2317d4749dbfa0c7b3925a`
- License: [`openzeppelin-contracts/LICENSE`](openzeppelin-contracts/LICENSE) (MIT).
- Included: `ERC20`, `IERC20`, `IERC20Metadata`, `IERC20Errors` (in
  `draft-IERC6093.sol`), `Context`, and `Base64`, with their original paths.
  `Base64.sol` was retrieved from the same tag's raw source path.
- Used for the production ERC-20 implementation and on-chain metadata encoding.
  There are no external library link references.

## forge-std v1.9.7

- Source: <https://github.com/foundry-rs/forge-std/tree/v1.9.7>
- Archive: <https://codeload.github.com/foundry-rs/forge-std/tar.gz/refs/tags/v1.9.7>
- Archive SHA-256: `45157353ab49eab01d294565866731e599b32401757229689ee459aa26b7ee94`
- Licenses: [`forge-std/LICENSE-MIT`](forge-std/LICENSE-MIT) and
  [`forge-std/LICENSE-APACHE`](forge-std/LICENSE-APACHE).
- Included: upstream `src/` and license files only. Used only in tests.

Per-file SHA-256 hashes are in `SHA256SUMS`. Check them from the repository root
with `sha256sum -c lib/SHA256SUMS`.
