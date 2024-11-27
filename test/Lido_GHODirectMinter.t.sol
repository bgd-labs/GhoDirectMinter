// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MiscEthereum} from "aave-address-book/MiscEthereum.sol";
import {AaveV3EthereumAssets} from "aave-address-book/AaveV3Ethereum.sol";
import {AaveV3EthereumLido} from "aave-address-book/AaveV3EthereumLido.sol";
import {GovernanceV3Ethereum} from "aave-address-book/GovernanceV3Ethereum.sol";
import {IERC20} from "solidity-utils/contracts/oz-common/interfaces/IERC20.sol";
import {
    ITransparentProxyFactory,
    ProxyAdmin
} from "solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol";
import {GovV3Helpers} from "aave-helpers/src/GovV3Helpers.sol";
import {IPool, DataTypes} from "aave-v3-origin/contracts/interfaces/IPool.sol";
import {GHODirectMinter} from "../src/GHODirectMinter.sol";
import {LidoGHOListing} from "../src/proposals/LidoGHOListing.sol";
import {IGhoToken} from "../src/interfaces/IGhoToken.sol";

contract Lido_GHODirectMinter_Test is Test {
    GHODirectMinter internal minter;
    IERC20 internal ghoAToken;
    LidoGHOListing internal proposal;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 21265036);

        // execute payload
        proposal = new LidoGHOListing();
        GovV3Helpers.executePayload(vm, address(proposal));

        address[] memory facilitators = IGhoToken(AaveV3EthereumAssets.GHO_UNDERLYING).getFacilitatorsList();
        minter = GHODirectMinter(facilitators[facilitators.length - 1]);
        ghoAToken = IERC20(minter.GHO_A_TOKEN());

        // burn all supply to start with a clean state on the tests
        uint128 mintAmount = proposal.GHO_MINT_AMOUNT();
        vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
        minter.withdrawAndBurn(mintAmount);
        assertEq(ghoAToken.balanceOf(address(minter)), 0);
        assertEq(ghoAToken.totalSupply(), 0);
    }

    function test_mintAndSupply(uint256 amount) public returns (uint256) {
        amount = bound(amount, 1, proposal.GHO_MINT_AMOUNT());
        vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
        minter.mintAndSupply(amount);
        assertEq(IERC20(ghoAToken).balanceOf(address(minter)), amount);
        assertEq(ghoAToken.totalSupply(), amount);
        return amount;
    }

    function test_withdrawAndBurn(uint256 supplyAmount, uint256 withdrawAmount) external {
        uint256 amount = test_mintAndSupply(supplyAmount);
        withdrawAmount = bound(withdrawAmount, 1, amount);
        vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
        minter.withdrawAndBurn(amount);
        assertEq(IERC20(ghoAToken).balanceOf(address(minter)), 0);
        assertEq(ghoAToken.totalSupply(), 0);
    }

    function test_transferExcessToTreasury() external {
        uint256 amount = test_mintAndSupply(1000 ether);
        // supply sth and borrow gho
        deal(AaveV3EthereumAssets.wstETH_UNDERLYING, address(this), 1_000 ether);
        IERC20(AaveV3EthereumAssets.wstETH_UNDERLYING).approve(address(AaveV3EthereumLido.POOL), 1_000 ether);
        AaveV3EthereumLido.POOL.deposit(AaveV3EthereumAssets.wstETH_UNDERLYING, 1_000 ether, address(this), 0);
        AaveV3EthereumLido.POOL.borrow(AaveV3EthereumAssets.GHO_UNDERLYING, amount, 2, 0, address(this));

        // generate some yield
        vm.warp(block.timestamp + 1000);

        uint256 balanceBeforeTransfer = ghoAToken.balanceOf(address(minter));
        assertGt(balanceBeforeTransfer, amount);
        minter.transferExcessToTreasury();
        assertEq(ghoAToken.balanceOf(address(minter)), amount);
        assertEq(ghoAToken.balanceOf(address(minter.COLLECTOR())), balanceBeforeTransfer - amount);
    }
}
