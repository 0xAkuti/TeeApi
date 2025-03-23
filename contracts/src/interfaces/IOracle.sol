// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IOracle
 * @dev Interface for the Oracle contract that handles REST API requests
 */
interface IOracle {
    error RequestNotActive();
    error InvalidFee();
    error InvalidRequester();

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
     * @dev Struct representing a condition for response verification
     * @param operator Comparison operator (e.g., "gt", "lt", "eq", "contains")
     * @param value Value to compare against
     * @param encrypted Whether the comparison value is encrypted
     */
    struct Condition {
        string operator;
        string value;
        bool encrypted;
    }

    /**
     * @dev Struct representing a field to extract from JSON response
     * @param path JSONPath expression to extract the value
     * @param responseType Type of the response (string, uint, int, bool, address, bytes)
     * @param condition Optional condition to verify against the value
     *        If condition is provided, the response will be a boolean indicating
     *        whether the value meets the condition, instead of the actual value
     */
    struct ResponseField {
        string path;
        string responseType;
        Condition condition;
    }

    /**
     * @dev Struct representing a key-value pair for headers or query parameters
     * @param key The key name
     * @param value The value
     * @param encrypted Whether the value is encrypted
     */
    struct KeyValue {
        string key;
        string value;
        bool encrypted;
    }

    /**
     * @dev Struct representing a REST API request
     * @param method HTTP method for the request
     * @param url Base URL for the API request
     * @param urlEncrypted Whether the URL is encrypted
     * @param headers HTTP headers to include in the request
     * @param queryParams Query parameters to append to the URL
     * @param body Request body for POST/PUT/PATCH requests
     * @param bodyEncrypted Whether the body is encrypted
     * @param responseFields Fields to extract from the JSON response
     */
    struct Request {
        HttpMethod method;
        string url;
        bool urlEncrypted;
        KeyValue[] headers;
        KeyValue[] queryParams;
        string body;
        bool bodyEncrypted;
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
     * @param callbackSuccess Whether the request callback was successful
     */
    event RestApiResponse(bytes32 indexed requestId, bool callbackSuccess);

    /**
     * @dev Submit a REST API request
     * @param request The REST API request details
     * @return requestId Unique identifier for the request
     */
    function requestRestApi(Request calldata request) external payable returns (bytes32 requestId);

    /**
     * @dev Get the oracle's Ethereum public key as a hex string
     * @return publicKey The oracle's Ethereum public key
     */
    function getPublicKey() external view returns (string memory publicKey);

    /**
     * @dev Get the oracle's Ethereum address for the public key
     * @return keyAddress The oracle's Ethereum address
     */
    function getPublicKeyAddress() external view returns (address keyAddress);

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
