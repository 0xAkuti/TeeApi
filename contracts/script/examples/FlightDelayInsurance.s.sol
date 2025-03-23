// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../src/examples/FlightDelayInsurance.sol";
import "../../src/Oracle.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title DeployFlightDelayInsurance
 * @dev Script to deploy the FlightDelayInsurance contract
 */
contract DeployFlightDelayInsurance is Script {
    function run() external {
        // Get the Oracle address from environment variable
        address oracleAddress = vm.envOr("ORACLE_ADDRESS", 0x700b6A60ce7EaaEA56F065753d8dcB9653dbAD35);
        require(oracleAddress != address(0), "Oracle address not provided. Set ORACLE_ADDRESS env var.");

        console.log("Using Oracle at:", oracleAddress);

        // Start broadcast
        vm.startBroadcast();

        // Deploy FlightDelayInsurance
        FlightDelayInsurance insurance = new FlightDelayInsurance(oracleAddress);

        // Fund the contract with initial capital
        uint256 initialFunding = 0.05 ether; // 50 payouts
        insurance.fundContract{value: initialFunding}();

        console.log("FlightDelayInsurance deployed at:", address(insurance));
        console.log("Initial funding:", initialFunding);

        // End broadcast
        vm.stopBroadcast();
    }
}

/**
 * @title ClaimFlightDelayInsurance
 * @dev Script to claim flight delay insurance payout using the FlightDelayInsurance contract
 */
contract ClaimFlightDelayInsurance is Script {
    function run() external {
        // Get the FlightDelayInsurance address from environment variable
        address insuranceAddress = vm.envOr("INSURANCE_ADDRESS", 0x0C8E79F3534B00D9a3D4a856B665Bf4eBC22f2ba);
        require(insuranceAddress != address(0), "Insurance address not provided. Set INSURANCE_ADDRESS env var.");

        // Get flight details from environment variables or use defaults
        string memory flightNumber = vm.envOr("FLIGHT_NUMBER", string("UA1606"));
        string memory flightDate = vm.envOr("FLIGHT_DATE", string("2025-03-22"));

        console.log("Using FlightDelayInsurance at:", insuranceAddress);
        console.log("Checking delay status for flight:", flightNumber);
        console.log("Flight date:", flightDate);

        // Access FlightDelayInsurance contract
        FlightDelayInsurance insurance = FlightDelayInsurance(insuranceAddress);

        // Get Oracle to determine request fee
        IOracle oracle = IOracle(insurance.oracle());
        uint256 requestFee = oracle.requestFee();

        console.log("Oracle request fee:", requestFee);

        // Start broadcast
        vm.startBroadcast();

        // Check flight delay status
        bytes32 requestId = insurance.initiateClaim{value: requestFee}(flightNumber);

        // Log the request ID
        console.log("Request sent! Request ID:", vm.toString(requestId));

        // End broadcast
        vm.stopBroadcast();
    }
}

/**
 * @title CheckFlightDelayInsurance
 * @dev Script to check flight delay status using the FlightDelayInsurance contract
 */
contract CheckFlightDelayInsurance is Script {
    function run() external {
        // Get the FlightDelayInsurance address from environment variable
        address insuranceAddress = vm.envOr("INSURANCE_ADDRESS", 0x0C8E79F3534B00D9a3D4a856B665Bf4eBC22f2ba);
        require(insuranceAddress != address(0), "Insurance address not provided. Set INSURANCE_ADDRESS env var.");

        // Get flight details from environment variables or use defaults
        string memory flightNumber = vm.envOr("FLIGHT_NUMBER", string("UA1606"));
        string memory flightDate = vm.envOr("FLIGHT_DATE", string("2025-03-22"));

        console.log("Using FlightDelayInsurance at:", insuranceAddress);
        console.log("Claiming insurance for flight:", flightNumber);
        console.log("Flight date:", flightDate);

        // Access FlightDelayInsurance contract
        FlightDelayInsurance insurance = FlightDelayInsurance(insuranceAddress);

        // Check flight status first to display info
        FlightDelayInsurance.FlightInfo memory flightInfo = insurance.getFlightInfo(flightNumber, flightDate);
        console.log("Flight delay status:", flightInfo.delayed ? "DELAYED" : "NOT DELAYED");

        console.log("Flight delay minutes:", flightInfo.delayMinutes);
        console.log("Insurance payout amount:", insurance.INSURANCE_PAYOUT());
        console.log("Claim status:", flightInfo.claimed ? "CLAIMED" : "NOT CLAIMED");
        console.log("Claim time:", flightInfo.claimTimestamp);
    }
}
