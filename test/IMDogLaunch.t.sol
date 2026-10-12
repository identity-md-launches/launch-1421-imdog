// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IMDog} from "../src/IMDog.sol";

/// @dev Test-only CREATE2 deployer. This models token transfers, not the production AMM or factory.
contract TokenFactoryHarness {
    function deploy(bytes32 salt) external returns (IMDog) {
        bytes memory creationCode = type(IMDog).creationCode;
        address deployed;
        assembly ("memory-safe") {
            deployed := create2(0, add(creationCode, 32), mload(creationCode), salt)
        }
        require(deployed != address(0) && deployed.code.length > 0, "deployment failed");
        return IMDog(deployed);
    }

    function send(IMDog token, address to, uint256 amount) external {
        require(token.transfer(to, amount), "transfer failed");
    }
}

contract RejectingTokenRecipient {
    fallback() external {
        revert("recipient must not be called");
    }
}

contract IMDogLaunchTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000 * 1e18;
    TokenFactoryHarness internal factory;
    IMDog internal token;
    address internal distributor = makeAddr("launch distributor");
    address internal poolManager = makeAddr("pool manager model");
    address internal requester = 0xf2816F3f05FAC35577B1930ffd09b531B62628dF;
    address internal contributor = makeAddr("contributor");
    address internal trader = makeAddr("trader");

    function setUp() public {
        factory = new TokenFactoryHarness();
        token = factory.deploy(bytes32(uint256(1)));
    }

    function test_create2DeploymentMintsToFactoryAndLinksLogoOnPredictedToken() public view {
        bytes32 hash = keccak256(type(IMDog).creationCode);
        address predicted = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(factory), bytes32(uint256(1)), hash))))
        );
        assertEq(address(token), predicted);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(factory)), SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(requester), 0);
        assertEq(
            vm.parseJsonString(IMDog(predicted).metadataJSON(), ".image"),
            "ipfs://bafybeie5pg3kfdo6fl7dllampv44j2bymf46j554n5ehdmsryl5ejbrdre"
        );
    }

    function test_factoryDistributionsClaimsAndBothPoolTransferDirectionsArriveWhole() public {
        uint256 swarm = SUPPLY * 1_000 / 10_000;
        uint256 pool = SUPPLY * 8_800 / 10_000;
        uint256 remainder = SUPPLY - swarm - pool;

        factory.send(token, distributor, swarm);
        factory.send(token, poolManager, pool);
        factory.send(token, requester, remainder);
        assertEq(token.balanceOf(address(factory)), 0);
        assertEq(token.balanceOf(distributor), 100_000_000e18);
        assertEq(token.balanceOf(poolManager), 880_000_000e18);
        assertEq(token.balanceOf(requester), 20_000_000e18);

        vm.prank(distributor);
        assertTrue(token.transfer(contributor, swarm));
        assertEq(token.balanceOf(distributor), 0);
        assertEq(token.balanceOf(contributor), swarm);

        uint256 traded = 1_234e18;
        vm.prank(poolManager);
        assertTrue(token.transfer(trader, traded));
        assertEq(token.balanceOf(trader), traded);
        assertEq(token.balanceOf(poolManager), pool - traded);
        vm.prank(trader);
        assertTrue(token.transfer(poolManager, traded));
        assertEq(token.balanceOf(trader), 0);
        assertEq(token.balanceOf(poolManager), pool);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_factoryCannotSpendDistributedTokensWithoutApproval() public {
        factory.send(token, contributor, 100e18);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(factory), 0, 1)
        );
        vm.prank(address(factory));
        token.transferFrom(contributor, address(factory), 1);
        assertEq(token.balanceOf(contributor), 100e18);
        vm.prank(contributor);
        assertTrue(token.transfer(trader, 100e18));
        assertEq(token.balanceOf(trader), 100e18);
    }

    function test_transferDoesNotCallRecipientCode() public {
        RejectingTokenRecipient recipient = new RejectingTokenRecipient();
        factory.send(token, address(recipient), 100e18);
        assertEq(token.balanceOf(address(recipient)), 100e18);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_distinctFactoryDeploymentsHaveIndependentFixedSupplies(bytes32 salt) public {
        vm.assume(salt != bytes32(uint256(1)));
        IMDog another = factory.deploy(salt);
        assertTrue(address(another) != address(token));
        assertEq(another.totalSupply(), SUPPLY);
        assertEq(another.balanceOf(address(factory)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(factory)), SUPPLY);
    }
}
