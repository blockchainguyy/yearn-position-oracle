// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

interface ICurvePool {
    function balances(uint256 i) external returns (uint256);
    function token() external view returns (address);
}
