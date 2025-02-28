// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EthereumScript} from "solidity-utils/contracts/utils/ScriptUtils.sol";
import {IPoolAddressesProvider} from "aave-v3-origin/contracts/interfaces/IPoolAddressesProvider.sol";
import {ICollector} from "aave-v3-origin/contracts/treasury/ICollector.sol";
import {ITransparentProxyFactory} from
  "solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol";
import {IProxyAdminOzV4} from "solidity-utils/contracts/transparent-proxy/interfaces/IProxyAdminOzV4.sol";
import {GhoDirectMinter} from "../src/GhoDirectMinter.sol";
import {IGhoToken} from "../src/interfaces/IGhoToken.sol";

import {AaveV3EthereumAssets} from "aave-address-book/AaveV3Ethereum.sol";
import {AaveV3EthereumLido} from "aave-address-book/AaveV3EthereumLido.sol";
import {GovernanceV3Ethereum} from "aave-address-book/GovernanceV3Ethereum.sol";
import {MiscEthereum} from "aave-address-book/MiscEthereum.sol";

library DeploymentLibrary {
  function _deployFacilitator(
    ITransparentProxyFactory proxyFactory,
    address proxyAdmin,
    IPoolAddressesProvider poolAddressesProvider,
    address collector,
    IGhoToken gho,
    address council
  ) internal returns (address) {
    address vaultImpl = address(new GhoDirectMinter(poolAddressesProvider, address(collector), address(gho)));
    return proxyFactory.create(
      vaultImpl,
      proxyAdmin,
      abi.encodeWithSelector(GhoDirectMinter.initialize.selector, address(GovernanceV3Ethereum.EXECUTOR_LVL_1), council)
    );
  }

  function _deployLido() internal returns (address) {
    // its the council used on other GHO stewards
    // might make sense to have on address book
    address council = 0x8513e6F37dBc52De87b166980Fa3F50639694B60;
    return _deployFacilitator(
      //ITransparentProxyFactory(MiscEthereum.TRANSPARENT_PROXY_FACTORY),
      // using an old TRANSPARENT_PROXY_FACTORY, it was replaced in a new version of aave-address-book
      ITransparentProxyFactory(0x9FB3B12248bf010AEA7cE08343C8499FFAB4770f),
      MiscEthereum.PROXY_ADMIN,
      AaveV3EthereumLido.POOL_ADDRESSES_PROVIDER,
      address(AaveV3EthereumLido.COLLECTOR),
      IGhoToken(AaveV3EthereumAssets.GHO_UNDERLYING),
      council
    );
  }
}

contract DeployLido is EthereumScript {
  function run() external broadcast {
    DeploymentLibrary._deployLido();
  }
}
