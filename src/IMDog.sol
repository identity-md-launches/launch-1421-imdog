// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/// @title IMDog (IMDOG)
/// @notice Fixed-supply token with a permanent link to the requester's official logo.
/// @dev IdentityMD's factory is msg.sender during launch and receives the entire supply.
contract IMDog is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    string public constant LOGO_URI = "ipfs://bafybeie5pg3kfdo6fl7dllampv44j2bymf46j554n5ehdmsryl5ejbrdre";

    constructor() ERC20("IMDog", "IMDOG") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /// @notice Immutable token metadata; the image URI identifies the original, unmodified logo.
    function metadataJSON() public pure returns (string memory) {
        return string.concat(
            '{"name":"IMDog","symbol":"IMDOG","decimals":18,"description":"IMDog meme token on IdentityMD.","image":"',
            LOGO_URI,
            '"}'
        );
    }

    /// @notice Self-contained contract metadata for indexers supporting contractURI().
    /// @dev ERC-20 does not require logo discovery; launch registries can also read LOGO_URI().
    function contractURI() external pure returns (string memory) {
        return string.concat("data:application/json;base64,", Base64.encode(bytes(metadataJSON())));
    }
}
