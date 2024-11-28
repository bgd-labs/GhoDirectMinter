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
import {RiskCouncilControlled} from "../src/RiskCouncilControlled.sol";
import {LidoGHOListing} from "../src/proposals/LidoGHOListing.sol";
import {IGhoToken} from "../src/interfaces/IGhoToken.sol";

contract Lido_GHODirectMinter_Test is Test {
  GHODirectMinter internal minter;
  IERC20 internal ghoAToken;
  LidoGHOListing internal proposal;

  address council = makeAddr("council");
  address owner = GovernanceV3Ethereum.EXECUTOR_LVL_1;

  function setUp() external {
    vm.createSelectFork(vm.rpcUrl("mainnet"), 21265036);

    // execute payload
    proposal = new LidoGHOListing(council);
    GovV3Helpers.executePayload(vm, address(proposal));

    address[] memory facilitators = IGhoToken(AaveV3EthereumAssets.GHO_UNDERLYING).getFacilitatorsList();
    minter = GHODirectMinter(facilitators[facilitators.length - 1]);
    ghoAToken = IERC20(minter.GHO_A_TOKEN());

    // burn all supply to start with a clean state on the tests
    uint128 mintAmount = proposal.GHO_MINT_AMOUNT();
    vm.prank(owner);
    minter.withdrawAndBurn(mintAmount);
    assertEq(ghoAToken.balanceOf(address(minter)), 0);
    assertEq(ghoAToken.totalSupply(), 0);
  }

  function test_mintAndSupply_owner(uint256 amount) public returns (uint256) {
    return _mintAndSupply(amount, owner);
  }

  function test_mintAndSupply_council(uint256 amount) external returns (uint256) {
    return _mintAndSupply(amount, council);
  }

  function test_mintAndSupply_rando() external {
    vm.expectRevert(RiskCouncilControlled.InvalidCaller.selector);
    minter.mintAndSupply(100);
  }

  function test_withdrawAndBurn_owner(uint256 supplyAmount, uint256 withdrawAmount) external {
    _withdrawAndBurn(supplyAmount, withdrawAmount, owner);
  }

  function test_withdrawAndBurn_council(uint256 supplyAmount, uint256 withdrawAmount) external {
    _withdrawAndBurn(supplyAmount, withdrawAmount, council);
  }

  function test_withdrawAndBurn_rando() external {
    vm.expectRevert(RiskCouncilControlled.InvalidCaller.selector);
    minter.withdrawAndBurn(100);
  }

  function test_transferExcessToTreasury() external {
    uint256 amount = test_mintAndSupply_owner(1000 ether);
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
    assertApproxEqAbs(ghoAToken.balanceOf(address(minter)), amount, 1);
    assertApproxEqAbs(ghoAToken.balanceOf(address(minter.COLLECTOR())), balanceBeforeTransfer - amount, 1);
  }

  function _mintAndSupply(uint256 amount, address caller) internal returns (uint256) {
    amount = bound(amount, 1, proposal.GHO_MINT_AMOUNT());
    vm.prank(caller);
    minter.mintAndSupply(amount);
    assertEq(IERC20(ghoAToken).balanceOf(address(minter)), amount);
    assertEq(ghoAToken.totalSupply(), amount);
    return amount;
  }

  function _withdrawAndBurn(uint256 supplyAmount, uint256 withdrawAmount, address caller) internal {
    uint256 amount = test_mintAndSupply_owner(supplyAmount);
    withdrawAmount = bound(withdrawAmount, 1, amount);
    vm.prank(caller);
    minter.withdrawAndBurn(amount);
    assertEq(IERC20(ghoAToken).balanceOf(address(minter)), 0);
    assertEq(ghoAToken.totalSupply(), 0);
  }
}
