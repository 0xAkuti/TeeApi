// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/examples/ExampleConsumer.sol";
import "../src/Oracle.sol";

/**
 * @title ReadLastTODO
 * @dev Script to read the last TODO data from the ExampleConsumer
 */
contract ReadLastTODO is Script {
    function run() external {
        // Get the Consumer address from command line or environment variable
        address consumerAddress = vm.envOr("CONSUMER_ADDRESS", 0xb19b36b1456E65E3A6D514D3F715f204BD59f431);
        require(consumerAddress != address(0), "Consumer address not provided. Set CONSUMER_ADDRESS env var.");

        // Make the request with fee
        ExampleConsumer consumer = ExampleConsumer(consumerAddress);
        ExampleConsumer.TODOData memory lastTODOData = consumer.getLastTODOData();

        // Log the request ID
        console.log("Last TODO id:", lastTODOData.id);
        console.log("Last TODO userId:", lastTODOData.userId);
        console.log("Last TODO title:", lastTODOData.title);
        console.log("Last TODO completed:", lastTODOData.completed);
    }
}
