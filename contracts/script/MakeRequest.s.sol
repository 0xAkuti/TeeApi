// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/examples/ExampleConsumer.sol";
import "../src/Oracle.sol";

/**
 * @title MakeRequest
 * @dev Script to make a TODO request using the ExampleConsumer
 */
contract MakeRequest is Script {
    function run() external {
        // Get the Consumer address from command line or environment variable
        address consumerAddress = vm.envOr("CONSUMER_ADDRESS", 0xb19b36b1456E65E3A6D514D3F715f204BD59f431);
        require(consumerAddress != address(0), "Consumer address not provided. Set CONSUMER_ADDRESS env var.");

        string memory todoId = "1";

        console.log("Using ExampleConsumer at:", consumerAddress);
        console.log("Requesting TODO data for:", todoId);

        // Get Oracle to determine request fee
        ExampleConsumer consumer = ExampleConsumer(consumerAddress);
        IOracle oracle = IOracle(consumer.oracle());
        uint256 requestFee = oracle.requestFee();

        console.log("Oracle request fee:", requestFee);

        // Start broadcast
        vm.startBroadcast();

        // Make the request with fee
        bytes32 requestId = consumer.requestTODOData{value: requestFee}(todoId);

        // Log the request ID
        console.log("Request sent! Request ID:", vm.toString(requestId));

        // End broadcast
        vm.stopBroadcast();
    }
}
