// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IMDog} from "../src/IMDog.sol";

/// @dev Closed set of actors permits exact balance conservation checks after arbitrary call sequences.
contract IMDogHandler is Test {
    uint256 internal constant SUPPLY = 1_000_000_000 * 1e18;
    IMDog public immutable token;
    address[4] public actors;
    // Seeded from the specified allocation, never copied from the token's balance getter.
    mapping(address account => uint256 value) public expectedBalance;
    mapping(address owner => mapping(address spender => uint256 value)) public expectedAllowance;

    constructor(IMDog token_) {
        token = token_;
        actors = [makeAddr("actor 0"), makeAddr("actor 1"), makeAddr("actor 2"), makeAddr("actor 3")];
        for (uint256 i; i < actors.length; ++i) {
            expectedBalance[actors[i]] = SUPPLY / actors.length;
        }
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 rawAmount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 fromBefore = expectedBalance[from];
        uint256 toBefore = expectedBalance[to];
        uint256 amount = bound(rawAmount, 0, fromBefore);
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        _moveExpectedBalance(from, to, amount);
        assertEq(token.balanceOf(from), from == to ? fromBefore : fromBefore - amount);
        assertEq(token.balanceOf(to), from == to ? toBefore : toBefore + amount);
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 rawAmount, uint8 mode) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        // Exercise revocation and infinite approvals deliberately, alongside finite and unrestricted values.
        uint256 amount = mode % 4 == 0
            ? 0
            : mode % 4 == 1 ? type(uint256).max : mode % 4 == 2 ? bound(rawAmount, 0, SUPPLY) : rawAmount;
        _approve(owner, spender, amount);
    }

    function transferFrom(uint256 fromSeed, uint256 toSeed, uint256 spenderSeed, uint256 rawAmount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        uint256 fromBefore = expectedBalance[from];
        uint256 toBefore = expectedBalance[to];
        uint256 allowanceBefore = expectedAllowance[from][spender];
        uint256 limit = fromBefore < allowanceBefore ? fromBefore : allowanceBefore;
        uint256 amount = bound(rawAmount, 0, limit);
        vm.prank(spender);
        assertTrue(token.transferFrom(from, to, amount));
        if (allowanceBefore != type(uint256).max) {
            expectedAllowance[from][spender] = allowanceBefore - amount;
        }
        _moveExpectedBalance(from, to, amount);
        assertEq(token.balanceOf(from), from == to ? fromBefore : fromBefore - amount);
        assertEq(token.balanceOf(to), from == to ? toBefore : toBefore + amount);
    }

    function rejectOverspending(uint256 fromSeed, uint256 toSeed) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 fromBefore = expectedBalance[from];
        _expectFailure(
            from,
            abi.encodeCall(token.transfer, (to, fromBefore + 1)),
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, from, fromBefore, fromBefore + 1)
        );
    }

    function rejectDelegatedOverspending(uint256 fromSeed, uint256 toSeed, uint256 spenderSeed) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        uint256 balance = expectedBalance[from];
        uint256 allowed = expectedAllowance[from][spender];
        // Isolate insufficient allowance when possible; otherwise test the insufficient balance path.
        uint256 amount = (allowed < balance ? allowed : balance) + 1;
        bytes memory reason = allowed < amount
            ? abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, allowed, amount)
            : abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, from, balance, amount);
        _expectFailure(spender, abi.encodeCall(token.transferFrom, (from, to, amount)), reason);
        assertEq(token.allowance(from, spender), allowed, "revert consumed allowance");
    }

    function rejectZeroRecipient(uint256 fromSeed, uint256 spenderSeed, uint256 rawAmount, bool delegated) external {
        address from = actors[fromSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        uint256 limit = expectedBalance[from];
        uint256 allowed = expectedAllowance[from][spender];
        if (delegated && allowed < limit) limit = allowed;
        uint256 amount = bound(rawAmount, 0, limit);
        bytes memory reason = abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0));
        if (delegated) {
            _expectFailure(spender, abi.encodeCall(token.transferFrom, (from, address(0), amount)), reason);
        } else {
            _expectFailure(from, abi.encodeCall(token.transfer, (address(0), amount)), reason);
        }
        assertEq(token.allowance(from, spender), allowed, "invalid recipient consumed allowance");
    }

    function revokeAndRejectSpend(uint256 fromSeed, uint256 spenderSeed, uint256 toSeed) external {
        address from = actors[fromSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        address to = actors[toSeed % actors.length];
        _approve(from, spender, 0);
        _expectFailure(
            spender,
            abi.encodeCall(token.transferFrom, (from, to, 1)),
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1)
        );
    }

    function roundTripEntireBalance(uint256 fromSeed, uint256 toSeed) external {
        uint256 fromIndex = fromSeed % actors.length;
        // A distinct recipient ensures the entire balance actually leaves, including dust positions.
        address from = actors[fromIndex];
        address to = actors[(fromIndex + 1 + toSeed % (actors.length - 1)) % actors.length];
        uint256 amount = expectedBalance[from];
        uint256 toBefore = expectedBalance[to];
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(to), toBefore + amount);
        vm.prank(to);
        assertTrue(token.transfer(from, amount));
        assertEq(token.balanceOf(from), amount);
        assertEq(token.balanceOf(to), toBefore);
        // The round trip leaves both ghost balances unchanged.
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        expectedAllowance[owner][spender] = amount;
    }

    function _moveExpectedBalance(address from, address to, uint256 amount) internal {
        if (from != to) {
            expectedBalance[from] -= amount;
            expectedBalance[to] += amount;
        }
    }

    function _expectFailure(address caller, bytes memory data, bytes memory reason) internal {
        vm.prank(caller);
        (bool success, bytes memory result) = address(token).call(data);
        assertFalse(success, "invalid call succeeded");
        assertEq(result, reason, "unexpected revert reason");
        // Global invariants also check every allowance pair, catching writes to unrelated accounts.
        for (uint256 i; i < actors.length; ++i) {
            assertEq(token.balanceOf(actors[i]), expectedBalance[actors[i]], "failed call changed a balance");
        }
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract IMDogInvariantTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000 * 1e18;
    IMDog internal token;
    IMDogHandler internal handler;
    bytes32 internal metadataHash;

    function setUp() public {
        token = new IMDog();
        handler = new IMDogHandler(token);
        for (uint256 i; i < 4; ++i) {
            assertTrue(token.transfer(handler.actors(i), SUPPLY / 4));
            // Seed finite and infinite approvals so delegated calls can spend from the first step.
            handler.approve(i, (i + 1) % 4, SUPPLY / 4, i % 2 == 0 ? 1 : 2);
        }
        metadataHash = keccak256(bytes(token.contractURI()));
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = handler.transfer.selector;
        selectors[1] = handler.approve.selector;
        selectors[2] = handler.transferFrom.selector;
        selectors[3] = handler.rejectOverspending.selector;
        selectors[4] = handler.rejectDelegatedOverspending.selector;
        selectors[5] = handler.rejectZeroRecipient.selector;
        selectors[6] = handler.revokeAndRejectSpend.selector;
        selectors[7] = handler.roundTripEntireBalance.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_supplyIsFixedAndEveryTokenIsAccountedFor() public view {
        uint256 sum;
        for (uint256 i; i < 4; ++i) {
            address actor = handler.actors(i);
            uint256 balance = token.balanceOf(actor);
            assertEq(balance, handler.expectedBalance(actor), "balance differs from the transfer ledger");
            sum += balance;
        }
        assertEq(sum, SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(handler)), 0);
        assertEq(token.balanceOf(address(token)), 0);
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
