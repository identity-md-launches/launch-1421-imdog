// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDog} from "../src/IMDog.sol";

/// @dev Closed set of actors permits exact balance conservation checks after arbitrary call sequences.
contract IMDogHandler is Test {
    IMDog public immutable token;
    address[4] public actors;
    mapping(address owner => mapping(address spender => uint256 value)) public expectedAllowance;

    constructor(IMDog token_) {
        token = token_;
        actors = [makeAddr("actor 0"), makeAddr("actor 1"), makeAddr("actor 2"), makeAddr("actor 3")];
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 rawAmount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 fromBefore = token.balanceOf(from);
        uint256 toBefore = token.balanceOf(to);
        uint256 amount = bound(rawAmount, 0, fromBefore);
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        assertEq(token.balanceOf(from), from == to ? fromBefore : fromBefore - amount);
        assertEq(token.balanceOf(to), from == to ? toBefore : toBefore + amount);
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        expectedAllowance[owner][spender] = amount;
    }

    function transferFrom(uint256 fromSeed, uint256 toSeed, uint256 spenderSeed, uint256 rawAmount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        uint256 fromBefore = token.balanceOf(from);
        uint256 toBefore = token.balanceOf(to);
        uint256 allowanceBefore = expectedAllowance[from][spender];
        uint256 limit = fromBefore < allowanceBefore ? fromBefore : allowanceBefore;
        uint256 amount = bound(rawAmount, 0, limit);
        vm.prank(spender);
        assertTrue(token.transferFrom(from, to, amount));
        if (allowanceBefore != type(uint256).max) {
            expectedAllowance[from][spender] = allowanceBefore - amount;
        }
        assertEq(token.balanceOf(from), from == to ? fromBefore : fromBefore - amount);
        assertEq(token.balanceOf(to), from == to ? toBefore : toBefore + amount);
    }

    function rejectOverspending(uint256 fromSeed, uint256 toSeed) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 fromBefore = token.balanceOf(from);
        uint256 toBefore = token.balanceOf(to);
        vm.prank(from);
        (bool success,) = address(token).call(abi.encodeCall(token.transfer, (to, fromBefore + 1)));
        assertFalse(success);
        assertEq(token.balanceOf(from), fromBefore);
        assertEq(token.balanceOf(to), toBefore);
    }
}

contract IMDogInvariantTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000 * 1e18;
    IMDog internal token;
    IMDogHandler internal handler;
    bytes32 internal metadataHash;

    function setUp() public {
        token = new IMDog();
        handler = new IMDogHandler(token);
        for (uint256 i; i < 4; ++i) {
            token.transfer(handler.actors(i), SUPPLY / 4);
        }
        metadataHash = keccak256(bytes(token.contractURI()));
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = handler.transfer.selector;
        selectors[1] = handler.approve.selector;
        selectors[2] = handler.transferFrom.selector;
        selectors[3] = handler.rejectOverspending.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_supplyIsFixedAndEveryTokenIsAccountedFor() public view {
        uint256 sum;
        for (uint256 i; i < 4; ++i) {
            sum += token.balanceOf(handler.actors(i));
        }
        assertEq(sum, SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function invariant_allowancesMatchTheIndependentModel() public view {
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j < 4; ++j) {
                address owner = handler.actors(i);
                address spender = handler.actors(j);
                assertEq(token.allowance(owner, spender), handler.expectedAllowance(owner, spender));
            }
        }
    }

    function invariant_identityAndLogoNeverChange() public view {
        assertEq(token.name(), "IMDog");
        assertEq(token.symbol(), "IMDOG");
        assertEq(token.decimals(), 18);
        assertEq(keccak256(bytes(token.contractURI())), metadataHash);
        assertEq(token.LOGO_URI(), "ipfs://bafybeie5pg3kfdo6fl7dllampv44j2bymf46j554n5ehdmsryl5ejbrdre");
    }
}
