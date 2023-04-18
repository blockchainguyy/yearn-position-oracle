// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../src/YearnPositionTWAPOracle.sol";
import "../src/mock/MockPriceFeed.sol";

contract ContractTWAPOracle is Test {

    YearnPositionTWAPOracle public oracle;
    address public USDT_PRICE_FEED = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
    address public BTC_USD_PRICE_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address public ETH_USD_PRICE_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public curvePool = 0xD51a44d3FaE010294C616388b506AcdA1bfAAE46;
    address public yearnVault = 0x8078198Fc424986ae89Ce4a910Fc109587b6aBF3;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    uint256 blockNo = 16234272;
    MockPriceFeed public USDTPriceFeed;
    MockPriceFeed public WBTCPriceFeed;
    MockPriceFeed public WETHPriceFeed;

    function setUp() public {
        uint256 fork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(fork);
        vm.rollFork(blockNo);
        (,int256 initialPriceUSDT,,,) = AggregatorV3Interface(USDT_PRICE_FEED).latestRoundData();
        (,int256 initialPriceWBTC,,,) = AggregatorV3Interface(BTC_USD_PRICE_FEED).latestRoundData();
        (,int256 initialPriceWETH,,,) = AggregatorV3Interface(ETH_USD_PRICE_FEED).latestRoundData();
        uint8 decimalsUSDT = AggregatorV3Interface(USDT_PRICE_FEED).decimals();
        uint8 decimalsWBTC = AggregatorV3Interface(BTC_USD_PRICE_FEED).decimals();
        uint8 decimalsWETH = AggregatorV3Interface(ETH_USD_PRICE_FEED).decimals();
        USDTPriceFeed = new MockPriceFeed(initialPriceUSDT, decimalsUSDT);
        WBTCPriceFeed = new MockPriceFeed(initialPriceWBTC, decimalsWBTC);
        WETHPriceFeed = new MockPriceFeed(initialPriceWETH, decimalsWETH);
        oracle = new YearnPositionTWAPOracle(curvePool, yearnVault, [address(USDTPriceFeed), address(WBTCPriceFeed), address(WETHPriceFeed)]);
    }

    function testInitialFetch() public view {
        oracle.getYearnVaultPositionTwap(block.timestamp / 100);
    }

    function testFetchWithMultipleRegisterPrice() public {
        uint256 initialTime = block.timestamp;
        _registerPrices();
        uint256 finalTime = block.timestamp;
        oracle.getYearnVaultPositionTwap(finalTime - initialTime + 100);
    }

    function testFetchPriceWhenFirstRecordedTimeIsAheadOfTimeInterval() public {
        uint256 initialTime = block.timestamp;
        _registerPrices();
        uint256 finalTime = block.timestamp;
        oracle.getYearnVaultPositionTwap(finalTime - initialTime - 100);
    }

    function testFetchPriceTimeIntervalLargerThanBlockTime() public {
        _registerPrices();
        uint256 finalTime = block.timestamp;
        oracle.getYearnVaultPositionTwap(finalTime + 100);
    }

    function testFetchPriceBlockTimeMinusTimeIntervalLargerThanLastTimeFails() public {
        _registerPrices();
        _increaseTime(block.timestamp + 1000);
        bytes memory revertData = abi.encodeWithSignature("NoPriceToShow()");
        vm.expectRevert(revertData);
        oracle.getYearnVaultPositionTwap(100);
    }

    function _increaseTime(uint256 time) internal {
        vm.warp(time);
    }

    function _registerPrices() internal {
        for(uint256 i = 0;i < 30; i++) {
            _increaseTime(block.timestamp + 1000);
            oracle.registerCurrentPrice();
            (,int256 currentUSDTPrice,,,) = USDTPriceFeed.latestRoundData(); 
            (,int256 currentWBTCPrice,,,) = WBTCPriceFeed.latestRoundData();
            (,int256 currentWETHPrice,,,) = WETHPriceFeed.latestRoundData();

            int256 newUSDTPrice = bound(0, currentUSDTPrice * 80 / 100, currentUSDTPrice * 120 / 100);
            int256 newWBTCPrice = bound(0, currentWBTCPrice * 80 / 100, currentWBTCPrice * 120 / 100);
            int256 newWETHPrice = bound(0, currentWETHPrice * 80 / 100, currentWETHPrice * 120 / 100);

            USDTPriceFeed.setPrice(newUSDTPrice);
            WBTCPriceFeed.setPrice(newWBTCPrice);
            WETHPriceFeed.setPrice(newWETHPrice);
        }
    }

}