// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {IOracle} from "./interfaces/IOracle.sol";
import {IRestApiConsumer} from "./interfaces/IRestApiConsumer.sol";

import "forge-std/console.sol";

/**
 * @title Oracle
 * @dev Contract that handles REST API requests and responses
 */
contract Oracle is IOracle, OwnableRoles {
    // Roles
    uint256 public constant ROLE_TEE = _ROLE_0;
    // Constants for request status
    uint256 internal constant REQUEST_INACTIVE = 0;
    uint256 internal constant REQUEST_ACTIVE = 1;

    // Fee for making a request
    // TODO Static for now, extended to variable fees based on callback gas cost
    uint256 public requestFee;

    // Simple mapping to track completed requests - uint256 for gas refunds when cleared
    mapping(bytes32 => uint256) internal requestStatus;

    // Oracle's Ethereum public key for ECIES encryption (hex string with 0x prefix)
    string internal teePublicKey;

    // Cached Ethereum address derived from the public key for easier access
    address internal teeAddress;

    /**
     * @dev Constructor
     * @param _requestFee Initial fee for making a request
     */
    constructor(uint256 _requestFee) {
        _initializeOwner(msg.sender);
        requestFee = _requestFee;
    }

    /**
     * @dev Set the TEE public encryption key, only callable by the owner
     * @param _publicKey The Ethereum public key (hex string with 0x prefix)
     */
    function setPublicKey(string calldata _publicKey) external onlyOwner {
        teePublicKey = _publicKey;

        // Derive and store the Ethereum address using custom assembly
        // This calculation is done off-chain, but we store it for convenience
        // In a production contract, we would properly derive it here if needed
        if (bytes(_publicKey).length >= 4) {
            // Here we would parse the public key and derive the address
            // For now, we'll assume it's passed as a parameter to a separate function
            // and we'll implement the proper derivation in the future
        }
    }

    /**
     * @dev Set the TEE Ethereum address that corresponds to the public key
     * This would normally be derived from the public key, but is set separately
     * for simplicity and gas efficiency
     * @param _address The Ethereum address
     */
    function setPublicKeyAddress(address _address) external onlyOwner {
        teeAddress = _address;
    }

    /**
     * @dev Get the oracle's Ethereum address for the public key
     * @return keyAddress The oracle's Ethereum address
     */
    function getPublicKeyAddress() external view returns (address) {
        return teeAddress;
    }

    /**
     * @dev Get the oracle's public encryption key as a hex string
     * @return publicKey The oracle's public encryption key
     */
    function getPublicKey() external view returns (string memory) {
        return teePublicKey;
    }

    /**
     * @dev Implementation of the requestRestApi function from IOracle
     * @param request The REST API request details
     * @return requestId Unique identifier for the request
     */
    function requestRestApi(Request calldata request) external payable virtual returns (bytes32 requestId) {
        if (msg.value < requestFee) {
            revert InvalidFee();
        }
        if (msg.sender.code.length == 0) {
            revert InvalidRequester();
        }

        requestId = _generateRequestId(msg.sender, request);

        requestStatus[requestId] = REQUEST_ACTIVE;

        // Emit event for the TEE to pick up the request details
        // This moves the data off-chain and into the event logs
        emit RestApiRequest(requestId, msg.sender, request);

        return requestId;
    }

    /**
     * @dev Implementation of the fulfillRestApiRequest function from IOracle
     * @param requestId Unique identifier for the request
     * @param responseData ABI-encoded response data based on responseFields
     */
    function fulfillRestApiRequest(bytes32 requestId, bytes calldata responseData)
        external
        virtual
        override
        onlyRoles(ROLE_TEE)
        returns (bool)
    {
        if (requestStatus[requestId] == REQUEST_INACTIVE) {
            revert RequestNotActive();
        }
        address requester = _getRequester(requestId);
        console.log("Requester address: %s", requester);
        requestStatus[requestId] = REQUEST_INACTIVE; // get gas refund

        bool callbackSuccess;
        // TODO for now assume the API request was successful, but it should report the actual response
        // maybe even the HTTP error code
        try IRestApiConsumer(requester).handleApiResponse({requestId: requestId, success: true, data: responseData}) {
            callbackSuccess = true;
        } catch {
            callbackSuccess = false;
        }

        // Emit response event
        emit RestApiResponse(requestId, callbackSuccess);

        return callbackSuccess;
    }

    /**
     * @dev Set a new request fee
     * @param _requestFee The new fee
     */
    function setRequestFee(uint256 _requestFee) external onlyOwner {
        requestFee = _requestFee;
    }

    /**
     * @dev Check if a request is active
     * @param requestId Request ID to check
     * @return isActive Whether the request is active
     */
    function isRequestActive(bytes32 requestId) external view virtual returns (bool) {
        return requestStatus[requestId] == REQUEST_ACTIVE;
    }

    /**
     * @dev Withdraw fees collected by the oracle to the owner
     */
    function withdraw() external onlyOwner {
        SafeTransferLib.safeTransferAllETH(owner());
    }

    /**
     *  ╔════════════════════════════════════════════════════════════════════════════╗
     *  ║                             Internal functions                             ║
     *  ╚════════════════════════════════════════════════════════════════════════════╝
     */

    /**
     * @dev Generates a unique request ID based on the requester and request details
     * This encodes the requester address in the first 20 bytes to simplify recovery
     * @param requester Address of the requester
     * @param request The REST API request details
     * @return requestId Unique identifier for the request
     */
    function _generateRequestId(address requester, IOracle.Request memory request) internal view returns (bytes32) {
        bytes32 requesterPart = bytes32(uint256(uint160(requester)) << 96);
        bytes32 requestPart =
            keccak256(abi.encode(request.url, request.method, request.body, block.number, block.timestamp));
        // Combine both parts for the final ID
        // High 20 bytes = requester, Low 12 bytes = request hash + block data
        return requesterPart | (requestPart & 0x0000000000000000000000000000000000000000ffffffffffffffffffffffff);
    }

    /**
     * @dev Recovers the requester address from the request ID
     * @param requestId The request ID
     * @return requester The address of the requester
     */
    function _getRequester(bytes32 requestId) internal pure returns (address requester) {
        // Extract the first 20 bytes (address) from the requestId
        return address(uint160(uint256(requestId) >> 96));
    }
}
