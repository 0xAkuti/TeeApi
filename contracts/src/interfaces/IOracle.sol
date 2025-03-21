// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IOracle
 * @dev Interface for the Oracle contract that handles REST API requests
 */
interface IOracle {
    /**
     * @dev Enum representing HTTP methods
     */
    enum HttpMethod {
        GET,
        POST,
        PUT,
        DELETE,
        PATCH
    }

    /**
     * @dev Struct representing a field to extract from JSON response
     * @param path JSONPath expression to extract the value
     * @param responseType Type of the response (string, uint, int, bool, address, bytes)
     */
    struct ResponseField {
        string path;
        string responseType;
    }

    /**
     * @dev Struct representing a key-value pair for headers or query parameters
     */
    struct KeyValue {
        string key;
        string value;
    }

    /**
     * @dev Struct representing a REST API request
     * @param method HTTP method for the request
     * @param url Base URL for the API request
     * @param headers HTTP headers to include in the request
     * @param queryParams Query parameters to append to the URL
     * @param body Request body for POST/PUT/PATCH requests
     * @param responseFields Fields to extract from the JSON response
     */
    struct Request {
        HttpMethod method;
        string url;
        KeyValue[] headers;
        KeyValue[] queryParams;
        string body;
        ResponseField[] responseFields;
    }

    /**
     * @dev Event emitted when a new REST API request is made
     * @param requestId Unique identifier for the request
     * @param requester Address that made the request
     * @param request Details of the API request
     */
    event RestApiRequest(bytes32 indexed requestId, address indexed requester, Request request);

    /**
     * @dev Event emitted when a response is fulfilled
     * @param requestId Unique identifier for the original request
     * @param success Whether the request was successful
     */
    event RestApiResponse(bytes32 indexed requestId, bool success);

    /**
     * @dev Submit a REST API request
     * @param request The REST API request details
     * @return requestId Unique identifier for the request
     */
    function requestRestApi(Request calldata request) external payable returns (bytes32 requestId);

    /**
     * @dev Fulfill a REST API request with the response data, only callable by the TEE
     * @param requestId Unique identifier for the request
     * @param responseData ABI-encoded response data based on responseFields
     */
    function fulfillRestApiRequest(bytes32 requestId, bytes calldata responseData) external returns (bool);

    /**
     * @dev Get the current fee for making a request
     * @return fee The current request fee
     */
    function requestFee() external view returns (uint256);

    /**
     * @dev Check if a request is active
     * @param requestId Request ID to check
     * @return isActive Whether the request is active
     */
    function isRequestActive(bytes32 requestId) external view returns (bool);
}
