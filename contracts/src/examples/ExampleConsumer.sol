// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RestApiClient} from "../RestApiClient.sol";
import {IOracle} from "../interfaces/IOracle.sol";

/**
 * @title ExampleConsumer
 */
contract ExampleConsumer is RestApiClient {
    // Structure to store userdata
    struct TODOData {
        uint256 id;
        uint256 userId;
        bool completed;
        string title;
    }

    TODOData public lastTODOData;
    /**
     * @dev Constructor
     * @param _oracle Address of the Oracle contract
     */

    constructor(address _oracle) RestApiClient(_oracle) {}

    /**
     * @dev Request todo data for a specific id
     * @param id The id of the todo to get data for
     * @return requestId The unique identifier for the request
     */
    function requestTODOData(string memory id) external payable returns (bytes32) {
        // Exapmle response looks like this
        // [
        //     {
        //         "userId": 1,
        //         "id": 5,
        //         "title": "laboriosam mollitia et enim quasi adipisci quia provident illum",
        //         "completed": false
        //     }
        // ]

        // Create response fields to extract from the JSON
        IOracle.ResponseField[] memory responseFields = new IOracle.ResponseField[](4);
        responseFields[0] = IOracle.ResponseField({path: "$.id", responseType: "uint256"});
        responseFields[1] = IOracle.ResponseField({path: "$.userId", responseType: "uint256"});
        responseFields[2] = IOracle.ResponseField({path: "$.completed", responseType: "bool"});
        responseFields[3] = IOracle.ResponseField({path: "$.title", responseType: "string"});

        // Create query parameters
        IOracle.KeyValue[] memory queryParams = new IOracle.KeyValue[](1);
        queryParams[0] = IOracle.KeyValue({key: "id", value: id});

        // Make the request
        bytes32 requestId = makeRequest({
            method: IOracle.HttpMethod.GET,
            url: "https://jsonplaceholder.typicode.com/todos",
            headers: new IOracle.KeyValue[](0),
            queryParams: queryParams,
            body: "",
            responseFields: responseFields
        });

        return requestId;
    }

    /**
     * @dev Implementation of _handleResponse from RestApiClient
     * @param success Whether the API request was successful
     * @param data ABI-encoded response data according to the requested fields
     */
    function _handleResponse(bytes32, bool success, bytes calldata data) internal override {
        // Ensure the request was successful
        require(success, "API request failed");

        // Decode the response data
        (uint256 id, uint256 userId, bool completed, string memory title) =
            abi.decode(data, (uint256, uint256, bool, string));

        lastTODOData = TODOData({id: id, userId: userId, title: title, completed: completed});
    }

    function getLastTODOData() public view returns (TODOData memory) {
        return lastTODOData;
    }
}
