// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

import { ICurvePool } from "src/interfaces/ICurvePool.sol";
import { IYearnVault } from "src/interfaces/IYearnVault.sol";

/**
 * @title YearnPositionTWAPOracle
 * @dev A Solidity contract that calculates the time-weighted average price (TWAP) of a Yearn Vault share
 *      by using Chainlink price feeds for the underlying coins in the Curve pool.
 */
contract YearnPositionTWAPOracle {
    uint256 private constant N = 3; // curve 3 pool

    uint256 private immutable LP_UNIT;

    // Addresses for the Curve pool and Yearn vault
    ICurvePool public curvePool;
    IYearnVault public yearnVault;
    IERC20Metadata public lpToken;

    // Chainlink Price Feed addresses for coins in the Curve pool(USDT-WETH-WBTC)
    address[3] public coinPriceFeedAddresses;

    // Oracle data struct
    struct OracleData {
        uint256 timestamp;
        uint256 cumulativePrice; // total time since deployment
        uint256 price;
    }

}