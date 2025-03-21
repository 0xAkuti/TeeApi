// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Oracle.sol";

/**
 * @title DeployOracle
 * @dev Script to deploy the Oracle system
 */
contract DeployOracle is Script {
    // Address that will be granted the TEE role
    address constant TEE_ADDRESS = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;

    function run() external {
        // Start broadcast to record and send transactions
        vm.startBroadcast();

        // Deploy Oracle - request fee is set to 0.01 ETH
        Oracle oracle = new Oracle(0.01 ether);

        // Grant TEE role to the TEE address
        oracle.grantRoles(TEE_ADDRESS, oracle.ROLE_TEE());

        // Log the deployed contract addresses
        console.log("Oracle deployed at:", address(oracle));
        console.log("TEE role granted to:", TEE_ADDRESS);

        // End broadcast
        vm.stopBroadcast();
    }
}
