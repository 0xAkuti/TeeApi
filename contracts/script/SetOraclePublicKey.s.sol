// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Oracle.sol";

/**
 * @title SetOraclePublicKey
 * @dev Script to set the public key in the Oracle contract
 */
contract SetOraclePublicKey is Script {
    address constant DEFAULT_ORACLE_ADDRESS = 0x700b6A60ce7EaaEA56F065753d8dcB9653dbAD35;
    address constant DEFUALT_PUBLIC_KEY_ADDRESS = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
    string constant DEFAULT_PUBLIC_KEY =
        "0x931e7fda8da226f799f791eefc9afebcd7ae2b1b19a03c5eaa8d72122d9fe74d887a3962ff861190b531ab31ee82f0d7f255dfe3ab73ca627bd70ab3d1cbb417";

    function run() external {
        // Get the Oracle address from command line or environment variable
        address oracleAddress = vm.envOr("ORACLE_ADDRESS", DEFAULT_ORACLE_ADDRESS);
        require(oracleAddress != address(0), "Oracle address not provided. Set ORACLE_ADDRESS env var.");

        // Get the public key from environment variable
        string memory publicKey = vm.envOr("PUBLIC_KEY", DEFAULT_PUBLIC_KEY);
        require(bytes(publicKey).length > 0, "Public key not provided. Set PUBLIC_KEY env var.");

        // Get the Ethereum address associated with the public key
        address keyAddress = vm.envOr("PUBLIC_KEY_ADDRESS", DEFUALT_PUBLIC_KEY_ADDRESS);
        require(keyAddress != address(0), "Public key address not provided. Set PUBLIC_KEY_ADDRESS env var.");

        console.log("Using Oracle at:", oracleAddress);
        console.log("Setting public key...");
        console.log("Public key address:", keyAddress);

        // Start broadcast
        vm.startBroadcast();

        // Get the Oracle contract
        Oracle oracle = Oracle(oracleAddress);

        // Set the public key
        oracle.setPublicKey(publicKey);

        // Set the address
        oracle.setPublicKeyAddress(keyAddress);

        // Log confirmation
        console.log("Public key and address set successfully!");

        // End broadcast
        vm.stopBroadcast();
    }
}
