// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPool, DataTypes} from "aave-v3-origin/contracts/interfaces/IPool.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "solidity-utils/contracts/oz-common/interfaces/IERC20.sol";
import {SafeERC20} from "solidity-utils/contracts/oz-common/SafeERC20.sol";
import {IGhoToken} from "./interfaces/IGhoToken.sol";
import {IGHODirectMinter} from "./interfaces/IGHODirectMinter.sol";
import {RiskCouncilControlled} from "./RiskCouncilControlled.sol";

/**
 * @title GHODirectMinter
 * @notice The GHODirectMinter is a GHO facilitator, that can inject(mint) and remove(burn) GHO from an AAVE pool that has GHO listed as a non-custom AToken.
 * @author BGD Labs @bgdlabs
 */
contract GHODirectMinter is Initializable, OwnableUpgradeable, IGHODirectMinter, RiskCouncilControlled {
  using SafeERC20 for IERC20;

  // @inheritdoc IGHODirectMinter
  IPool public immutable POOL;
  // @inheritdoc IGHODirectMinter
  address public immutable COLLECTOR;
  // @inheritdoc IGHODirectMinter
  address public immutable GHO;
  // @inheritdoc IGHODirectMinter
  address public immutable GHO_A_TOKEN;

  modifier onlyRiskCouncilOrOwner() {
    require(RISK_COUNCIL == msg.sender || owner() == msg.sender, InvalidCaller());
    _;
  }

  constructor(IPool pool, address collector, address gho, address council) RiskCouncilControlled(council) {
    POOL = pool;
    COLLECTOR = collector;
    GHO = gho;
    DataTypes.ReserveDataLegacy memory reserveData = pool.getReserveData(gho);
    require(reserveData.aTokenAddress != address(0), InvalidAToken());
    GHO_A_TOKEN = reserveData.aTokenAddress;
    _disableInitializers();
  }

  function initialize(address owner) external virtual initializer {
    __Ownable_init(owner);
  }

  // @inheritdoc IGHODirectMinter
  function mintAndSupply(uint256 amount) external onlyRiskCouncilOrOwner {
    IGhoToken(GHO).mint(address(this), amount);
    IERC20(GHO).forceApprove(address(POOL), amount);
    POOL.supply(GHO, amount, address(this), 0);
  }

  // @inheritdoc IGHODirectMinter
  function withdrawAndBurn(uint256 amount) external onlyRiskCouncilOrOwner {
    uint256 amountWithdrawn = POOL.withdraw(GHO, amount, address(this));
    IGhoToken(GHO).burn(amountWithdrawn);
  }

  // @inheritdoc IGHODirectMinter
  function transferExcessToTreasury() external {
    (, uint256 capacityUtilization) = IGhoToken(GHO).getFacilitatorBucket(address(this));
    uint256 balanceIncrease = IERC20(GHO_A_TOKEN).balanceOf(address(this)) - capacityUtilization;
    IERC20(GHO_A_TOKEN).transfer(address(COLLECTOR), balanceIncrease);
  }
}
