// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import { YearnPositionTWAPOracle } from "../src/YearnPositionTWAPOracle.sol";

contract YearnPositionTWAScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address curvePoolAddress = vm.envAddress(
            string.concat("CURVE_POOL", deploymentNetwork)
        );

        address yearnVaultAddress = vm.envAddress(
            string.concat("YEARN_VAULT", deploymentNetwork)
        );

        address poolTokenAddress1 = vm.envAddress(
            string.concat("POOL_TOKEN_1", deploymentNetwork)
        );

        address poolTokenAddress2 = vm.envAddress(
            string.concat("POOL_TOKEN_2", deploymentNetwork)
        );

        address poolTokenAddress3 = vm.envAddress(
            string.concat("POOL_TOKEN_3", deploymentNetwork)
        );

        address[3] memory coinPriceFeedAddresses = [
            poolTokenAddress1,
            poolTokenAddress2,
            poolTokenAddress3
        ];

        YearnPositionTWAPOracle oracle = new YearnPositionTWAPOracle(
            curvePoolAddress,
            yearnVaultAddress,
            coinPriceFeedAddresses
        );

        console.log("YearnPositionTWAPOracle deployed at", address(oracle));
        vm.stopBroadcast();
    }
}