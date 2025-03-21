// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/examples/ExampleConsumer.sol";
import "../src/Oracle.sol";

/**
 * @title DeployConsumer
 * @dev Script to deploy the ExampleConsumer contract
 */
contract DeployConsumer is Script {
    function run() external {
        // Get the Oracle address from command line or environment variable
        address oracleAddress = vm.envOr("ORACLE_ADDRESS", 0x700b6A60ce7EaaEA56F065753d8dcB9653dbAD35);

        // Start broadcast for just the Consumer deployment
        vm.startBroadcast();
        console.log("Using existing Oracle at:", oracleAddress);

        // Deploy the ExampleConsumer
        ExampleConsumer consumer = new ExampleConsumer(oracleAddress);

        // Log the deployed contract address
        console.log("ExampleConsumer deployed at:", address(consumer));

        // End broadcast
        vm.stopBroadcast();
    }
}
