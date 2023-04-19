// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ICurvePool } from "src/interfaces/ICurvePool.sol";
import { IYearnVault } from "src/interfaces/IYearnVault.sol";
import "forge-std/console.sol";

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

    // collection of observations
    OracleData[] private observations;

    event NewPriceObserved(uint256 indexed _price);

    error FailedToFetchPrice();
    error CannotUpdateInSameBlock();
    error ZERO_ADDRESS_ERROR();
    error InvalidTime();
    error NoPriceToShow();

    /**
     * @dev constructor to set the required addresses
     * @param _curvePoolAddress Address of the Curve pool contract
     * @param _yearnVaultAddress Address of the Yearn vault contract
     * @param _coinPriceFeedAddresses Array of Chainlink price feed addresses for the coins in the Curve pool
     *        (should be ordered corresponding to the indexes of curve pool tokens)
     */
    constructor(
        address _curvePoolAddress,
        address _yearnVaultAddress,
        address[3] memory _coinPriceFeedAddresses // should be ordered corresponding to the indexes of curve pool tokens
    ) {
        curvePool = ICurvePool(_curvePoolAddress);
        yearnVault = IYearnVault(_yearnVaultAddress);
        coinPriceFeedAddresses = _coinPriceFeedAddresses;

        lpToken = IERC20Metadata(curvePool.token());
        LP_UNIT = 10 ** (lpToken.decimals());
        _registerPrice(block.timestamp, 0);
    }

    /**
     * @notice Register the current price of Yearn vault shares in USD.
     * @dev Calculates the weighted average price of the underlying coins in the Curve pool,
     * calculates the price of the Yearn vault position in USD, and stores it in the observations array.
     * Emits a `NewPriceObserved` event with the timestamp and price.
     */
    function registerCurrentPrice() external {
        OracleData memory lastIndexData = observations[observations.length - 1];

        uint256 currentTime = block.timestamp;
        if(currentTime <= lastIndexData.timestamp) {
            revert CannotUpdateInSameBlock();
        }
        uint256 interval;
        unchecked {
            interval  = currentTime - lastIndexData.timestamp;
        }
        uint256 cummulativePrice = lastIndexData.cumulativePrice + (interval * lastIndexData.price);
        _registerPrice(currentTime, cummulativePrice);
    }

    /**
     * @notice Get the time-weighted average price of Yearn vault shares in USD over a specified time .
     * @param timeInterval The time  in seconds for which to calculate the TWAP.
     * @return twap The time-weighted average price of Yearn vault shares in USD.
     */
    function getYearnVaultPositionTwap(uint256 timeInterval) external view returns (uint256 twap) {
        // Calculate the start timeInterval according to the given time 
        uint256 currentTime = block.timestamp;
        uint256 startingIndex;
        uint256 obsvLength = observations.length;
        OracleData memory startingIndexData;
        OracleData memory endingIndexData = observations[obsvLength - 1];
        if(timeInterval >= currentTime) {
            startingIndex = 0;
        }
        else {
            uint256 startTime = currentTime - timeInterval;
            if(startTime > endingIndexData.timestamp) {
            revert NoPriceToShow();
            }
            startingIndex = _getStartingIndex(startTime, obsvLength);
        }
        startingIndexData = observations[startingIndex];
        unchecked {
            uint256 cumulativePriceDiff = (endingIndexData.cumulativePrice - startingIndexData.cumulativePrice);
            twap = (cumulativePriceDiff == 0) ? startingIndexData.price : cumulativePriceDiff / (endingIndexData.timestamp - startingIndexData.timestamp);
        }
    }

    /**
     * @dev Calculates the latest prices and adds to the observations record.
     * @param currentTime the current time stamp of the observation.
     * @param cummulativePrice total time passed since deployment.
     */
    function _registerPrice(uint256 currentTime, uint256 cummulativePrice) internal {
        // Calculate the price of 1 LPToken in terms of USD
        uint256 totalUsdValue = _latestPriceFeed();

        // Calculate the price of the Yearn vault position in USD
        uint256 yearnVaultShareUsdPrice = (yearnVault.pricePerShare() * totalUsdValue) / LP_UNIT;

        observations.push(
            OracleData({
                timestamp: currentTime,
                cumulativePrice: cummulativePrice,
                price: yearnVaultShareUsdPrice
            })
        );

        emit NewPriceObserved(yearnVaultShareUsdPrice);
    }

    /**
     * @dev Fetches and calculates the latest USD value of LP Token.
     * @return totalUsdValue of the LP Token.
     */
    function _latestPriceFeed() internal returns (uint256 totalUsdValue) {
        uint256 totalLPSupply = lpToken.totalSupply();

        for (uint256 i; i < N;) {
            AggregatorV3Interface coinPriceFeed = AggregatorV3Interface(coinPriceFeedAddresses[i]);

            // Can be added to a try catch block if we want to redirect to another price feed if this fails
            (, int256 price, , , ) = coinPriceFeed.latestRoundData();

            // Adjust the decimals based on the price feed and token decimals
            uint256 tokenPrice = uint256(price) * (10 ** (18 - coinPriceFeed.decimals()));
            uint256 tokenAmount = ((LP_UNIT - 1) * curvePool.balances(i)) / totalLPSupply;
            uint256 usdValue = (tokenAmount * tokenPrice) / (10 ** 18);
            totalUsdValue += usdValue;
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev FInds starting index for twap calculation using binary search
     * @param targetTimeStamp The timestamp used to match values from the observations
     * @param obsvLength The length of the observations array
     * @return The starting index to be used for twap calculation
     */
    function _getStartingIndex(uint256 targetTimeStamp, uint256 obsvLength) internal view returns(uint256) {
        uint256 minIndex;
        uint256 maxIndex = obsvLength - 1;
        uint256 middle;
        OracleData memory middleData;

        while (minIndex <= maxIndex) {
            middle = minIndex + (maxIndex - minIndex) / 2;
            middleData = observations[middle];
            if (middleData.timestamp == targetTimeStamp) {
                return middle;
            } else if (middleData.timestamp < targetTimeStamp) {
                minIndex = middle + 1;
            } else {
                if(middle == 0) {
                    return 0;
                }
                maxIndex = middle - 1;
            }
        }
        return minIndex;
    }
}