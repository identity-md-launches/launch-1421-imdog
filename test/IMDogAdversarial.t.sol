// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IMDog} from "src/IMDog.sol";

/// @dev Additional regressions for authorization boundaries, failure recovery, and algebraic properties.
/// forge-config: default.fuzz.runs = 1000
contract IMDogAdversarialTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000 * 1e18;
    IMDog internal token;
    address internal alice = makeAddr("adversarial alice");
    address internal bob = makeAddr("adversarial bob");
    address internal spender = makeAddr("adversarial spender");
    address internal otherSpender = makeAddr("other spender");

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        token = new IMDog();
    }

    function test_oneBaseUnitRoundTripEmitsExactTransfers() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(address(this), alice, 1);
        assertTrue(token.transfer(alice, 1));
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);

        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, address(this), 1);
        vm.prank(alice);
        assertTrue(token.transfer(address(this), 1));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_maxMinusOneApprovalIsFiniteAndDoesNotBecomeInfinite() public {
        assertTrue(token.approve(spender, type(uint256).max - 1));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), spender), type(uint256).max - 2);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, SUPPLY - 1));
        assertEq(token.allowance(address(this), spender), type(uint256).max - 1 - SUPPLY);
        assertEq(token.balanceOf(alice), SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_maximumDelegatedTransferRevertsAndKeepsInfiniteAllowance() public {
        assertTrue(token.approve(spender, type(uint256).max));
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, type(uint256).max
            )
        );
        vm.prank(spender);
        token.transferFrom(address(this), alice, type(uint256).max);
        assertEq(token.allowance(address(this), spender), type(uint256).max);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);

        // A rejected oversized spend must not poison the following valid spend.
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, SUPPLY));
        assertEq(token.allowance(address(this), spender), type(uint256).max);
        assertEq(token.balanceOf(alice), SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroSourceCannotMintThroughTransferFrom() public {
        uint256[3] memory amounts = [uint256(0), uint256(1), type(uint256).max];
        for (uint256 i; i < amounts.length; ++i) {
            // The zero-source and allowance checks may reject at different stages for different amounts.
            vm.expectRevert();
            vm.prank(spender);
            token.transferFrom(address(0), alice, amounts[i]);
            assertEq(token.totalSupply(), SUPPLY);
            assertEq(token.balanceOf(address(0)), 0);
            assertEq(token.balanceOf(alice), 0);
            assertEq(token.balanceOf(address(this)), SUPPLY);
            assertEq(token.allowance(address(0), spender), 0);
        }
    }

    function test_zeroValueDoesNotBypassInvalidRecipientOrSpender() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(address(this), address(0), 0);
        assertEq(token.allowance(address(this), spender), 0);

        assertTrue(token.approve(spender, type(uint256).max));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(address(this), address(0), 0);
        assertEq(token.allowance(address(this), spender), type(uint256).max);
        assertEq(token.allowance(address(this), address(0)), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroDelegatedTransferEmitsEventWithoutSpendingFiniteAllowance() public {
        vm.prank(alice);
        assertTrue(token.approve(spender, 1));
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, bob, 0);
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 0));
        assertEq(token.allowance(alice, spender), 1);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_ownerUsingTransferFromStillNeedsItsOwnAllowance() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 1));
        token.transferFrom(address(this), alice, 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);

        assertTrue(token.approve(address(this), 1));
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), address(this)), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
        assertEq(token.balanceOf(alice), 1);
    }

    function test_selfTransferFromCannotExceedBalanceEvenWhenNetMovementWouldBeZero() public {
        assertTrue(token.transfer(alice, 1));
        vm.prank(alice);
        assertTrue(token.approve(spender, 2));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 1, 2));
        vm.prank(spender);
        token.transferFrom(alice, alice, 2);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.allowance(alice, spender), 2);

        vm.prank(spender);
        assertTrue(token.transferFrom(alice, alice, 1));
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.allowance(alice, spender), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_approvalBeforeFundingSurvivesFailureAndSpendsAfterFunding() public {
        vm.prank(alice);
        assertTrue(token.approve(spender, SUPPLY));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, SUPPLY));
        vm.prank(spender);
        token.transferFrom(alice, bob, SUPPLY);
        assertEq(token.allowance(alice, spender), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);

        assertTrue(token.transfer(alice, SUPPLY));
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, SUPPLY));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), SUPPLY);
        assertEq(token.allowance(alice, spender), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_infiniteApprovalCanBeReducedAndRevokedAfterSpending() public {
        assertTrue(token.approve(spender, type(uint256).max));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), spender), type(uint256).max);

        vm.expectEmit(true, true, false, true, address(token));
        emit Approval(address(this), spender, 7);
        assertTrue(token.approve(spender, 7));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 7, 8));
        vm.prank(spender);
        token.transferFrom(address(this), alice, 8);
        assertEq(token.allowance(address(this), spender), 7);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 7));
        assertEq(token.allowance(address(this), spender), 0);

        assertTrue(token.approve(spender, type(uint256).max));
        vm.expectEmit(true, true, false, true, address(token));
        emit Approval(address(this), spender, 0);
        assertTrue(token.approve(spender, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), bob, 1);
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(alice), 8);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - 8);
    }

    function testFuzz_failedDelegatedTransferRestoresFiniteAllowance(
        uint256 rawBalance,
        uint256 rawAllowance,
        uint256 rawAmount
    ) public {
        uint256 balance = bound(rawBalance, 0, SUPPLY - 1);
        uint256 allowed = bound(rawAllowance, balance + 1, type(uint256).max - 1);
        uint256 amount = bound(rawAmount, balance + 1, allowed);
        assertTrue(token.transfer(alice, balance));
        vm.prank(alice);
        assertTrue(token.approve(spender, allowed));

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, balance, amount));
        vm.prank(spender);
        token.transferFrom(alice, bob, amount);
        assertEq(token.allowance(alice, spender), allowed);
        assertEq(token.balanceOf(alice), balance);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - balance);

        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, balance));
        assertEq(token.allowance(alice, spender), allowed - balance);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), balance);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_replacementApprovalImmediatelyLimitsSpending(uint256 rawPrevious, uint256 rawReplacement) public {
        uint256 previous = bound(rawPrevious, 1, type(uint256).max);
        uint256 replacement = bound(rawReplacement, 0, previous - 1);
        assertTrue(token.approve(spender, previous));
        assertTrue(token.approve(spender, replacement));
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, spender, replacement, replacement + 1
            )
        );
        vm.prank(spender);
        token.transferFrom(address(this), alice, replacement + 1);
        assertEq(token.allowance(address(this), spender), replacement);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);

        uint256 amount = replacement < SUPPLY ? replacement : SUPPLY;
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, amount));
        assertEq(token.allowance(address(this), spender), replacement - amount);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
    }

    function testFuzz_approvalsAreIsolatedByBothOwnerAndSpender(
        uint256 firstAllowance,
        uint256 otherAllowance,
        uint256 rawAmount
    ) public {
        assertTrue(token.transfer(alice, SUPPLY / 2));
        assertTrue(token.transfer(bob, SUPPLY / 2));
        vm.startPrank(alice);
        assertTrue(token.approve(spender, firstAllowance));
        assertTrue(token.approve(otherSpender, otherAllowance));
        vm.stopPrank();
        vm.prank(bob);
        assertTrue(token.approve(spender, otherAllowance));

        uint256 limit = firstAllowance < SUPPLY / 2 ? firstAllowance : SUPPLY / 2;
        uint256 amount = bound(rawAmount, 0, limit);
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, amount));
        assertEq(
            token.allowance(alice, spender),
            firstAllowance == type(uint256).max ? firstAllowance : firstAllowance - amount
        );
        assertEq(token.allowance(alice, otherSpender), otherAllowance);
        assertEq(token.allowance(bob, spender), otherAllowance);
        assertEq(token.allowance(bob, otherSpender), 0);
        assertEq(token.allowance(spender, alice), 0);
        assertEq(token.balanceOf(alice), SUPPLY / 2 - amount);
        assertEq(token.balanceOf(bob), SUPPLY / 2 + amount);
        assertEq(token.balanceOf(spender), 0);
        assertEq(token.balanceOf(otherSpender), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_approveIsIdempotentAndLastWriteWins(uint256 first, uint256 last) public {
        assertTrue(token.approve(spender, first));
        assertTrue(token.approve(spender, first));
        assertEq(token.allowance(address(this), spender), first);
        assertTrue(token.approve(spender, last));
        assertTrue(token.approve(spender, last));
        assertEq(token.allowance(address(this), spender), last);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(spender), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_splitAndSingleTransfersHaveIdenticalOutcomes(uint256 rawTotal, uint256 rawFirst) public {
        IMDog singleTransferToken = new IMDog();
        uint256 total = bound(rawTotal, 0, SUPPLY);
        uint256 first = bound(rawFirst, 0, total);
        assertTrue(token.transfer(alice, first));
        assertTrue(token.transfer(alice, total - first));
        assertTrue(singleTransferToken.transfer(alice, total));
        assertEq(token.balanceOf(alice), singleTransferToken.balanceOf(alice));
        assertEq(token.balanceOf(address(this)), singleTransferToken.balanceOf(address(this)));
        assertEq(token.balanceOf(alice), total);
        assertEq(token.balanceOf(address(this)), SUPPLY - total);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(singleTransferToken.totalSupply(), SUPPLY);
    }

    function testFuzz_constructorCreditsImmediateCallerRatherThanTransactionOrigin(address rawDeployer) public {
        address deployer = address(uint160(bound(uint160(rawDeployer), 1, type(uint160).max)));
        if (deployer == alice) deployer = bob;
        // Synthetic callers model constructor semantics only; these are not deployment parameters.
        vm.prank(deployer, alice);
        IMDog fresh = new IMDog();
        assertEq(fresh.totalSupply(), SUPPLY);
        assertEq(fresh.balanceOf(deployer), SUPPLY);
        assertEq(fresh.balanceOf(alice), 0);
        assertEq(fresh.balanceOf(address(0)), 0);
        assertEq(fresh.name(), "IMDog");
        assertEq(fresh.symbol(), "IMDOG");
        assertEq(fresh.decimals(), 18);
        assertEq(
            vm.parseJsonString(fresh.metadataJSON(), ".image"),
            "ipfs://bafybeie5pg3kfdo6fl7dllampv44j2bymf46j554n5ehdmsryl5ejbrdre"
        );
    }
}
