// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RestApiClient} from "../RestApiClient.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title FlightDelayInsurance
 * @dev A contract that provides insurance payouts for flight delays
 */
contract FlightDelayInsurance is RestApiClient, Ownable {
    // Insurance payout amount in wei
    uint256 public constant INSURANCE_PAYOUT = 0.001 ether;

    // Flight data structure
    struct FlightInfo {
        bool claimed;
        bool delayed;
        uint256 claimTimestamp;
        uint256 delayMinutes;
        string flightNumber;
        string date;
    }

    struct FlightId {
        string flightNumber;
        string date;
    }

    // Store flight information by flight number and date
    mapping(FlightId => FlightInfo) private flightData;

    // claimer address by requestId
    mapping(bytes32 => address) private claimers;

    // flightId by requestId
    mapping(bytes32 => FlightId) private flightIds;

    // Events
    event FlightDelayVerified(string flightNumber, string date, bool delayed, uint256 delayMinutes);
    event ClaimPaid(address recipient, string flightNumber, string date, uint256 amount);

    /**
     * @dev Constructor
     * @param _oracle Address of the Oracle contract
     */
    constructor(address _oracle) RestApiClient(_oracle) {
        _initializeOwner(msg.sender);
    }

    /**
     * @dev Check if a flight is delayed
     * @param flightNumber IATA flight number (e.g., UA1606)
     * @return requestId The unique identifier for the request
     */
    function initiateClaim(string memory flightNumber) external payable returns (bytes32) {
        // Create query parameters with encrypted API key
        IOracle.KeyValue[] memory queryParams = new IOracle.KeyValue[](2);
        queryParams[0] = IOracle.KeyValue({
            key: "access_key",
            value: "BKYsjhVlGzVth8axoDpWJNxstMuU+W8rgLdye1MsAiWIfLbUg5xVfST34kp/b7DvI1SLmECJKuBplDxdDxF1NrlT/f6w/XX7Unp0i3E2Aygi85W8nZbGjSk07BVJO4xlxuopzJDbbZceJrLhih3royD/9xIWyLy34n32SvbD9mAl",
            encrypted: true
        });
        queryParams[1] = IOracle.KeyValue({key: "flight_iata", value: flightNumber, encrypted: false});

        // Define conditions for verification
        IOracle.Condition memory flightLanded = IOracle.Condition({operator: "eq", value: "landed", encrypted: false});
        IOracle.Condition memory isDelayed = IOracle.Condition({operator: "gt", value: "0", encrypted: false});
        IOracle.Condition memory noCondition = IOracle.Condition({operator: "", value: "", encrypted: false});

        // Create response fields with conditions to verify
        IOracle.ResponseField[] memory responseFields = new IOracle.ResponseField[](5);

        // Verify if flight has landed
        responseFields[0] =
            IOracle.ResponseField({path: "$.data[0].flight_status", responseType: "string", condition: flightLanded});

        // Verify if arrival delay is greater than 0
        responseFields[1] =
            IOracle.ResponseField({path: "$.data[0].arrival.delay", responseType: "uint256", condition: isDelayed});

        // Extract the actual delay minutes
        responseFields[2] =
            IOracle.ResponseField({path: "$.data[0].arrival.delay", responseType: "uint256", condition: noCondition});

        // Extract the flight number
        responseFields[3] =
            IOracle.ResponseField({path: "$.data[0].flight.iata", responseType: "string", condition: noCondition});

        // Extract the flight date
        responseFields[4] =
            IOracle.ResponseField({path: "$.data[0].flight_date", responseType: "string", condition: noCondition});

        // Make the request
        bytes32 requestId = makeRequest({
            method: IOracle.HttpMethod.GET,
            url: "https://api.aviationstack.com/v1/flights",
            urlEncrypted: false,
            headers: new IOracle.KeyValue[](0),
            queryParams: queryParams,
            body: "",
            bodyEncrypted: false,
            responseFields: responseFields
        });

        claimers[requestId] = msg.sender;
        flightIds[requestId] = FlightId({flightNumber: flightNumber, date: date});
        return requestId;
    }

    /**
     * @dev Fund the contract to pay for insurance claims
     */
    function fundContract() external payable onlyOwner {
        // Simply accepts ETH sent to the contract
    }

    /**
     * @dev Withdraw funds from the contract (owner only)
     */
    function withdrawFunds() external onlyOwner {
        SafeTransferLib.safeTransferAllETH(owner());
    }

    /**
     * @dev Get flight information
     * @param flightNumber IATA flight number
     * @param date Flight date in YYYY-MM-DD format
     * @return Information about the flight
     */
    function getFlightInfo(string memory flightNumber, string memory date) external view returns (FlightInfo memory) {
        return flightData[flightNumber][date];
    }

    /**
     * @dev Get flight information by requestId
     * @param requestId Unique identifier for the request
     * @return Information about the flight
     */
    function getFlightInfoById(bytes32 requestId) external view returns (FlightInfo memory) {
        FlightId memory flightId = flightIds[requestId];
        return flightData[flightId.flightNumber][flightId.date];
    }

    /**
     * @dev Implementation of _handleResponse from RestApiClient
     * @param requestId Unique identifier for the request
     * @param success Whether the API request was successful
     * @param data ABI-encoded response data according to the requested fields
     */
    function _handleResponse(bytes32 requestId, bool success, bytes calldata data) internal override {
        address claimer = claimers[requestId];

        (bool isLanded, bool isDelayed, uint256 delayMinutes, string memory flightNumber, string memory date) =
            abi.decode(data, (bool, bool, uint256, string, string));

        // Update flight data
        FlightInfo memory flight = flightData[flightNumber][date];
        // Return early if flight already exists
        if (flight.claimTimestamp != 0) {
            return;
        }
        flight.delayed = isLanded && isDelayed;
        flight.delayMinutes = delayMinutes;

        emit FlightDelayVerified(flightNumber, date, flight.delayed, delayMinutes);
        if (flight.delayed) {
            flight.claimed = true;
            flight.claimTimestamp = block.timestamp;
            // Transfer payout to claimant
            SafeTransferLib.safeTransferETH(claimer, INSURANCE_PAYOUT);
            emit ClaimPaid(claimer, flightNumber, date, INSURANCE_PAYOUT);
        }
        flightData[flightNumber][date] = flight;
    }
}
