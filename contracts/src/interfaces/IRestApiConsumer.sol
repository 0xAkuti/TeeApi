// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IRestApiConsumer
 * @dev Interface for contracts that want to receive REST API responses
 */
interface IRestApiConsumer {
    /**
     * @dev Callback function to receive REST API responses
     * All consumers MUST implement this exact function signature
     * @param requestId Unique identifier of the original request
     * @param success Whether the API request was successful
     * @param data ABI-encoded response data according to the requested fields
     */
    function handleApiResponse(bytes32 requestId, bool success, bytes calldata data) external;
}
