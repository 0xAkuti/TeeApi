// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IOracle.sol";
import "../interfaces/IRestApiConsumer.sol";

/**
 * @title ResponseLib
 * @dev Library for handling REST API response operations
 */
library ResponseLib {
    /**
     * @dev Error codes for API responses
     */
    uint8 constant ERROR_NONE = 0;
    uint8 constant ERROR_INVALID_RESPONSE = 1;
    uint8 constant ERROR_REQUEST_FAILED = 2;
    uint8 constant ERROR_INVALID_SIGNATURE = 3;

    /**
     * @dev Event emitted when there's an error processing a response
     */
    event ResponseError(bytes32 indexed requestId, uint8 errorCode);

    /**
     * @dev Encodes response data for verification by the TEE
     * @param requestId The unique identifier for the request
     * @param success Whether the API request was successful
     * @param data The response data
     * @return encodedResponse Encoded response details
     */
    function encodeResponse(bytes32 requestId, bool success, bytes memory data) internal pure returns (bytes memory) {
        return abi.encode(requestId, success, data);
    }

    /**
     * @dev Validates and formats the response according to the requested fields
     * @param responseFields The requested response fields
     * @param responseData The raw response data
     * @return formattedData The formatted response data
     */
    function validateAndFormatResponse(IOracle.ResponseField[] memory responseFields, bytes memory responseData)
        internal
        pure
        returns (bytes memory)
    {
        // In a real implementation, this would parse the responseData
        // according to the responseFields definitions
        // For Phase 1, we'll just pass through the data
        return responseData;
    }

    /**
     * @dev Executes the callback to the requester using fixed function signature
     * @param requester The address of the requester
     * @param requestId The unique identifier for the request
     * @param success Whether the API request was successful
     * @param data The response data
     * @return callSuccess Whether the callback was successful
     */
    function executeCallback(address requester, bytes32 requestId, bool success, bytes memory data)
        internal
        returns (bool)
    {
        // Use the fixed function selector for IRestApiConsumer.handleApiResponse
        bytes4 callbackSelector = IRestApiConsumer.handleApiResponse.selector;

        bytes memory callData = abi.encodeWithSelector(callbackSelector, requestId, success, data);

        (bool callSuccess,) = requester.call(callData);
        return callSuccess;
    }

    /**
     * @dev Recovers the requester address from the request ID
     * This is just a placeholder - in reality the TEE would fetch this from event logs
     * @param requestId The request ID
     * @return requester The address of the requester
     */
    function recoverRequester(bytes32 requestId) internal pure returns (address requester) {
        // In a real implementation, the TEE would look up the requester from event logs
        // For this implementation, we're just returning the address component from the requestId
        // which is an oversimplification but demonstrates the concept

        // Extract the first 20 bytes (address) from the requestId
        // This assumes requestId was generated in a way that incorporates the requester address
        bytes32 shifted = requestId << 96;
        requester = address(uint160(uint256(shifted >> 96)));

        return requester;
    }
}
