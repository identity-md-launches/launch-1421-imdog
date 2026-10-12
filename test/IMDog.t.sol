// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IMDog} from "../src/IMDog.sol";

contract IMDogTest is Test {
    IMDog internal token;
    uint256 internal constant SUPPLY = 1_000_000_000 * 1e18;
    string internal constant IMAGE = "ipfs://bafybeie5pg3kfdo6fl7dllampv44j2bymf46j554n5ehdmsryl5ejbrdre";
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal spender = makeAddr("spender");

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        token = new IMDog();
    }

    function test_identityAndEntireSupplyBelongToConstructorCaller() public view {
        assertEq(token.name(), "IMDog");
        assertEq(token.symbol(), "IMDOG");
        assertEq(token.decimals(), 18);
        assertEq(token.INITIAL_SUPPLY(), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_constructorEmitsMintTransfer() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), address(this), SUPPLY);
        IMDog fresh = new IMDog();
        assertEq(fresh.balanceOf(address(this)), SUPPLY);
    }

    function test_metadataContainsExactOfficialImageAndIdentity() public view {
        string memory json = token.metadataJSON();
        assertEq(vm.parseJsonString(json, ".name"), "IMDog");
        assertEq(vm.parseJsonString(json, ".symbol"), "IMDOG");
        assertEq(vm.parseJsonUint(json, ".decimals"), 18);
        assertEq(vm.parseJsonString(json, ".description"), "IMDog meme token on IdentityMD.");
        assertEq(vm.parseJsonString(json, ".image"), IMAGE);
        assertEq(token.LOGO_URI(), IMAGE);
        // Foundry independently encodes the JSON, checking the actual data URI returned by the token.
        assertEq(token.contractURI(), string.concat("data:application/json;base64,", vm.toBase64(bytes(json))));
    }

    function test_transferEmitsEventAndDeliversExactAmount() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(address(this), alice, 125e18);
        assertTrue(token.transfer(alice, 125e18));
        assertEq(token.balanceOf(alice), 125e18);
        assertEq(token.balanceOf(address(this)), SUPPLY - 125e18);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferEntireSupply() public {
        assertTrue(token.transfer(alice, SUPPLY));
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(alice), SUPPLY);
        vm.prank(alice);
        assertTrue(token.transfer(bob, SUPPLY));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroValueTransferFromEmptyAccountEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, bob, 0);
        vm.prank(alice);
        assertTrue(token.transfer(bob, 0));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_selfTransferPreservesBalance() public {
        assertTrue(token.transfer(address(this), SUPPLY));
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_transferToZeroRevertsIncludingZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 1);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 0);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_transferOverBalanceRevertsWithoutChangingState() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transfer(bob, 1);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_maximumTransferRevertsWithoutOverflowOrStateChange() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, type(uint256).max
            )
        );
        token.transfer(alice, type(uint256).max);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_approveEmitsEventAndDoesNotMoveBalance() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Approval(address(this), spender, 50e18);
        assertTrue(token.approve(spender, 50e18));
        assertEq(token.allowance(address(this), spender), 50e18);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(spender), 0);
    }

    function test_approveOverwritesThenRevokesAllowance() public {
        assertTrue(token.approve(spender, 50));
        assertTrue(token.approve(spender, 10));
        assertEq(token.allowance(address(this), spender), 10);
        assertTrue(token.approve(spender, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), bob, 1);
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_approveZeroSpenderReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 100);
        assertEq(token.allowance(address(this), address(0)), 0);
    }

    function test_transferFromSpendsOnlyAllowanceAndDeliversExactAmount() public {
        token.approve(spender, 100e18);
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(address(this), alice, 40e18);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 40e18));
        assertEq(token.allowance(address(this), spender), 60e18);
        assertEq(token.balanceOf(address(this)), SUPPLY - 40e18);
        assertEq(token.balanceOf(alice), 40e18);
        assertEq(token.balanceOf(spender), 0);
    }

    function test_transferFromExhaustsAllowanceAndCannotSpendAgain() public {
        token.approve(spender, 100);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 100));
        assertEq(token.allowance(address(this), spender), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), alice, 1);
        assertEq(token.balanceOf(alice), 100);
    }

    function test_infiniteAllowanceHasStandardERC20Semantics() public {
        token.approve(spender, type(uint256).max);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, SUPPLY));
        assertEq(token.allowance(address(this), spender), type(uint256).max);
        assertEq(token.balanceOf(alice), SUPPLY);
    }

    function test_transferFromWithoutApprovalReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), alice, 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_anApprovalCannotBeUsedByAnotherSpender() public {
        token.approve(spender, 100);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, 100));
        vm.prank(bob);
        token.transferFrom(address(this), bob, 100);
        assertEq(token.allowance(address(this), spender), 100);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_transferFromOverAllowanceRevertsAtomically() public {
        token.approve(spender, 100);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 100, 101));
        vm.prank(spender);
        token.transferFrom(address(this), alice, 101);
        assertEq(token.allowance(address(this), spender), 100);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_transferFromOverBalanceRestoresAllowanceOnRevert() public {
        vm.prank(alice);
        token.approve(spender, 100);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 50));
        vm.prank(spender);
        token.transferFrom(alice, bob, 50);
        assertEq(token.allowance(alice, spender), 100);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_transferFromToZeroRestoresAllowanceOnRevert() public {
        token.approve(spender, 100);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(address(this), address(0), 50);
        assertEq(token.allowance(address(this), spender), 100);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroTransferFromNeedsNoApproval() public {
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 0));
        assertEq(token.allowance(alice, spender), 0);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_selfTransferFromConsumesAllowanceWithoutChangingBalance() public {
        token.approve(spender, 123);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), address(this), 123));
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_ethAndUnknownCallsRevert() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool sent,) = address(token).call{value: 1 wei}("");
        assertFalse(sent);
        assertEq(address(token).balance, 0);
        (bool unknown,) = address(token).call(hex"deadbeef");
        assertFalse(unknown);
    }

    function test_deployerAndStrangerCannotMintBurnFreezeUpgradeOrChangeLogo() public {
        token.transfer(alice, 100e18);
        bytes[] memory calls = new bytes[](18);
        calls[0] = abi.encodeWithSignature("mint(address,uint256)", bob, 1e18);
        calls[1] = abi.encodeWithSignature("mint(uint256)", 1e18);
        calls[2] = abi.encodeWithSignature("mint()");
        calls[3] = abi.encodeWithSignature("burn(uint256)", 1e18);
        calls[4] = abi.encodeWithSignature("burnFrom(address,uint256)", alice, 1e18);
        calls[5] = abi.encodeWithSignature("pause()");
        calls[6] = abi.encodeWithSignature("blacklist(address)", alice);
        calls[7] = abi.encodeWithSignature("freeze(address)", alice);
        calls[8] = abi.encodeWithSignature("seize(address)", alice);
        calls[9] = abi.encodeWithSignature("transferOwnership(address)", bob);
        calls[10] = abi.encodeWithSignature("setMinter(address)", bob);
        calls[11] = abi.encodeWithSignature("upgradeTo(address)", bob);
        calls[12] = abi.encodeWithSignature("initialize(address)", bob);
        calls[13] = abi.encodeWithSignature("setContractURI(string)", "altered");
        calls[14] = abi.encodeWithSignature("setLogoURI(string)", "altered");
        calls[15] = abi.encodeWithSignature("setMetadataURI(string)", "altered");
        calls[16] = abi.encodeWithSignature("setImage(string)", "altered");
        calls[17] = abi.encodeWithSignature("setTransfersEnabled(bool)", false);

        string memory metadataBefore = token.contractURI();
        for (uint256 i; i < calls.length; ++i) {
            (bool fromDeployer,) = address(token).call(calls[i]);
            assertFalse(fromDeployer, "deployer reached an administrative function");
            vm.prank(bob);
            (bool fromStranger,) = address(token).call(calls[i]);
            assertFalse(fromStranger, "stranger reached an administrative function");
            assertEq(token.totalSupply(), SUPPLY);
            assertEq(token.balanceOf(alice), 100e18);
            assertEq(token.balanceOf(bob), 0);
        }
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 1));
        token.transferFrom(alice, address(this), 1);
        vm.prank(alice);
        assertTrue(token.transfer(bob, 100e18));
        assertEq(token.balanceOf(bob), 100e18);
        assertEq(token.contractURI(), metadataBefore);
    }

    function test_runtimeFitsDeploymentLimitAndContainsNoForbiddenOpcodes() public view {
        bytes memory runtime = address(token).code;
        assertGt(runtime.length, 0);
        assertLe(runtime.length, 24_576);
        for (uint256 i; i < runtime.length; ++i) {
            uint8 op = uint8(runtime[i]);
            if (op >= 0x60 && op <= 0x7f) {
                i += op - 0x5f;
                continue;
            }
            assertTrue(op != 0xf4 && op != 0xf2 && op != 0xff, "forbidden opcode");
        }
    }

    function testFuzz_transferConservesSupplyAndArrivesWhole(address recipient, uint256 rawAmount) public {
        vm.assume(recipient != address(0) && recipient != address(this));
        uint256 amount = bound(rawAmount, 0, SUPPLY);
        assertTrue(token.transfer(recipient, amount));
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_delegatedTransferConservesSupplyAndAllowance(uint256 rawAmount, uint256 rawAllowance) public {
        uint256 allowed = bound(rawAllowance, 0, SUPPLY);
        uint256 amount = bound(rawAmount, 0, allowed);
        token.approve(spender, allowed);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, amount));
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.allowance(address(this), spender), allowed - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_insufficientBalanceAlwaysReverts(uint256 rawAmount) public {
        uint256 amount = bound(rawAmount, SUPPLY + 1, type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, amount)
        );
        token.transfer(alice, amount);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }
}
