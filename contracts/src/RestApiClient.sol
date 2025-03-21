// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from "./interfaces/IOracle.sol";
import {IRestApiConsumer} from "./interfaces/IRestApiConsumer.sol";

/**
 * @title RestApiClient
 * @dev Base contract for consuming REST API data through the Oracle
 * To use override the _handleResponse function
 */
abstract contract RestApiClient is IRestApiConsumer {
    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    // The Oracle contract address
    IOracle public immutable oracle;

    /**
     * @dev Emitted when a new REST API request is made
     */
    event ApiRequestSent(bytes32 indexed requestId, string url);

    /**
     * @dev Emitted when a REST API response is received
     */
    event ApiResponseReceived(bytes32 indexed requestId, bool success);

    modifier onlyOracle() {
        if (msg.sender != address(oracle)) revert Unauthorized();
        _;
    }

    /**
     * @dev Constructor
     * @param _oracle Address of the Oracle contract
     */
    constructor(address _oracle) {
        oracle = IOracle(_oracle);
    }

    /**
     * @dev Make a request to a REST API
     * @param method The HTTP method to use
     * @param url The URL to request
     * @param headers The headers to include in the request
     * @param queryParams The query parameters to append to the URL
     * @param body The request body for POST/PUT/PATCH requests
     * @param responseFields The fields to extract from the response
     * @return requestId The unique identifier for the request
     */
    function makeRequest(
        IOracle.HttpMethod method,
        string memory url,
        IOracle.KeyValue[] memory headers,
        IOracle.KeyValue[] memory queryParams,
        string memory body,
        IOracle.ResponseField[] memory responseFields
    ) internal returns (bytes32) {
        IOracle.Request memory request = IOracle.Request({
            method: method,
            url: url,
            headers: headers,
            queryParams: queryParams,
            body: body,
            responseFields: responseFields
        });
        return oracle.requestRestApi{value: msg.value}(request);
    }

    /**
     * @dev Make a GET request to a REST API
     * @param url The URL to request
     * @param responseFields The fields to extract from the response
     * @return requestId The unique identifier for the request
     */
    function makeGetRequest(string memory url, IOracle.ResponseField[] memory responseFields)
        internal
        returns (bytes32)
    {
        return makeRequest(
            IOracle.HttpMethod.GET, url, new IOracle.KeyValue[](0), new IOracle.KeyValue[](0), "", responseFields
        );
    }

    /**
     * @dev Implementation of handleApiResponse from IRestApiConsumer, only callable by the oracle
     * @param requestId Unique identifier of the original request
     * @param success Whether the API request was successful
     * @param data ABI-encoded response data according to the requested fields
     */
    function handleApiResponse(bytes32 requestId, bool success, bytes calldata data) external override onlyOracle {
        _handleResponse(requestId, success, data);
    }

    /**
     * @dev Internal function to handle the response
     * @param requestId Unique identifier of the original request
     * @param success Whether the API request was successful
     * @param data ABI-encoded response data according to the requested fields
     */
    function _handleResponse(bytes32 requestId, bool success, bytes calldata data) internal virtual;

    /**
     * @dev Check if a request is active in the oracle
     * @param requestId The request ID to check
     * @return isActive Whether the request is active
     */
    function isRequestActive(bytes32 requestId) internal view returns (bool) {
        return oracle.isRequestActive(requestId);
    }
}
