// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3EthereumAssets} from "aave-address-book/AaveV3Ethereum.sol";
import {AaveV3EthereumLido} from "aave-address-book/AaveV3EthereumLido.sol";
import {MiscEthereum} from "aave-address-book/MiscEthereum.sol";
import {AaveV3PayloadEthereumLido} from "aave-helpers/src/v3-config-engine/AaveV3PayloadEthereumLido.sol";
import {EngineFlags} from "aave-v3-origin/contracts/extensions/v3-config-engine/EngineFlags.sol";
import {IAaveV3ConfigEngine} from "aave-v3-origin/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol";
import {IERC20} from "solidity-utils/contracts/oz-common/interfaces/IERC20.sol";
import {SafeERC20} from "solidity-utils/contracts/oz-common/SafeERC20.sol";
import {
  ITransparentProxyFactory,
  ProxyAdmin
} from "solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

import {IGhoToken} from "../interfaces/IGhoToken.sol";
import {IGhoBucketSteward} from "../interfaces/IGhoBucketSteward.sol";
import {GhoDirectMinter} from "../GhoDirectMinter.sol";

/**
 * @title GHO listing on Lido pool
 * @notice Lists GHO on Lido pool and creates a new facilatator bucket for the vault.
 * @author BGD Labs @bgdlabs
 * - Discussion: https://governance.aave.com/t/arfc-mint-deploy-10m-gho-into-aave-v3-lido-instance/19700/3
 */
contract LidoGHOListing is AaveV3PayloadEthereumLido {
  using SafeERC20 for IERC20;

  uint128 public constant GHO_MINT_AMOUNT = 10_000_000e18;
  address public immutable FACILITATOR;

  constructor(address facilitator) {
    FACILITATOR = facilitator;
  }

  function _postExecute() internal override {
    IAccessControl(address(AaveV3EthereumLido.ACL_MANAGER)).grantRole(
      AaveV3EthereumLido.ACL_MANAGER.RISK_ADMIN_ROLE(), address(FACILITATOR)
    );
    IGhoToken(AaveV3EthereumAssets.GHO_UNDERLYING).addFacilitator(FACILITATOR, "LidoGhoDirectMinter", GHO_MINT_AMOUNT);
    GhoDirectMinter(FACILITATOR).mintAndSupply(GHO_MINT_AMOUNT);

    // allow risk council to control the bucket capacity
    address[] memory vaults = new address[](1);
    vaults[0] = FACILITATOR;
    IGhoBucketSteward(0x46Aa1063e5265b43663E81329333B47c517A5409).setControlledFacilitator(vaults, true);
  }
}
