// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

contract MockPriceFeed {
    int256 private price;
    uint8 immutable private _decimals;

    event PriceUpdated(int256 indexed newPrice);

    constructor(int256 initialPrice, uint8 decimals_) {
        emit PriceUpdated(initialPrice);
        price = initialPrice;
        _decimals = decimals_;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) {
        return(uint80(0),price,0,0,uint80(0));
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }
 
}