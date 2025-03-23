// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RestApiClient} from "../RestApiClient.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title FlightDelayInsurance
 * @dev A contract that provides insurance payouts for flight delays
 * @notice This contract allows users to make claims for flight delays and receive automatic
 * payouts if their flight was delayed. It uses the TeeAPI Oracle to verify flight data.
 */
contract FlightDelayInsurance is RestApiClient, Ownable {
    // Insurance payout amount in wei
    uint256 public constant INSURANCE_PAYOUT = 0.001 ether;

    /**
     * @dev Flight data structure
     * @notice Stores information about a flight's delay status and claim details
     */
    struct FlightInfo {
        bool claimed;
        bool landed;
        bool delayed;
        uint256 claimTimestamp;
        uint256 delayMinutes;
        string flightNumber;
        string date;
    }

    /**
     * @dev Flight identifier structure
     * @notice Used to uniquely identify a flight by its number and date
     */
    struct FlightId {
        string flightNumber;
        string date;
    }

    // Store flight information by flight number and date
    mapping(string => mapping(string => FlightInfo)) private flightData;

    // claimer address by requestId
    mapping(bytes32 => address) private claimers;

    // make it easy to see the last request by the claimer
    bytes32 public lastRequestId;

    // flightId by requestId
    mapping(bytes32 => FlightId) private flightIds;

    // Events
    /**
     * @notice Emitted when a flight's delay status has been verified by the Oracle
     * @param flightNumber The IATA flight number
     * @param date The flight date (YYYY-MM-DD)
     * @param delayed Whether the flight was delayed
     * @param delayMinutes The number of minutes the flight was delayed
     */
    event FlightDelayVerified(string flightNumber, string date, bool delayed, uint256 delayMinutes);

    /**
     * @notice Emitted when an insurance claim is paid out
     * @param recipient The address that received the payout
     * @param flightNumber The IATA flight number for the delayed flight
     * @param date The flight date (YYYY-MM-DD)
     * @param amount The amount paid out in wei
     */
    event ClaimPaid(address recipient, string flightNumber, string date, uint256 amount);

    /**
     * @dev Constructor
     * @param _oracle Address of the Oracle contract
     * @notice Initializes the contract with the Oracle address and sets the owner
     */
    constructor(address _oracle) RestApiClient(_oracle) {
        _initializeOwner(msg.sender);
    }

    /**
     * @dev Check if a flight is delayed
     * @param flightNumber IATA flight number (e.g., UA1606)
     * @return requestId The unique identifier for the request
     * @notice Initiates a claim for flight delay insurance by checking the flight status
     * using the TeeAPI Oracle. A small fee may be required to cover the Oracle costs.
     * Currently the fee is 100000000000000 (0.0001 ETH).
     */
    function initiateClaim(string memory flightNumber) external payable returns (bytes32) {
        // Create query parameters with encrypted API key
        IOracle.KeyValue[] memory queryParams = new IOracle.KeyValue[](2);
        queryParams[0] = IOracle.KeyValue({
            key: "access_key",
            value: "BJst9aKc0VEuRDm3bFqnePTvE+JVmo/A8p2WZqn2QLk4eYgR7ECFRIsz5kuvCjf9v+yaNZ5OFtfYs1qzckOJCJK4s/lJkmgOlP/Ys0pkiZ+WQgf6gz/VkjQv1Ul/XnJ9FHftgDQdgg2ii/jQ0lKhcnt2i7qADd95H7qSOsGkdUWZ",
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
        flightIds[requestId] = FlightId({flightNumber: flightNumber, date: ""});
        lastRequestId = requestId;
        return requestId;
    }

    /**
     * @dev Fund the contract to pay for insurance claims
     * @notice Allows the owner to fund the contract to ensure there are sufficient funds for payouts
     */
    function fundContract() external payable onlyOwner {
        // Simply accepts ETH sent to the contract
    }

    /**
     * @dev Withdraw funds from the contract (owner only)
     * @notice Allows the owner to withdraw all funds from the contract
     */
    function withdrawFunds() external onlyOwner {
        SafeTransferLib.safeTransferAllETH(owner());
    }

    /**
     * @dev Get flight information
     * @param flightNumber IATA flight number
     * @param date Flight date in YYYY-MM-DD format
     * @return Information about the flight
     * @notice Retrieve information about a specific flight by its number and date
     */
    function getFlightInfo(string memory flightNumber, string memory date) external view returns (FlightInfo memory) {
        return flightData[flightNumber][date];
    }

    /**
     * @dev Get flight information by requestId
     * @param requestId Unique identifier for the request
     * @return Information about the flight
     * @notice Retrieve flight information using the Oracle request ID
     */
    function getFlightInfoById(bytes32 requestId) external view returns (FlightInfo memory) {
        FlightId memory flightId = flightIds[requestId];
        return flightData[flightId.flightNumber][flightId.date];
    }

    /**
     * @dev Get the last request by the claimer
     * @return The last request ID and flight information
     * @notice Retrieve the caller's most recent claim request and its corresponding flight information
     */
    function getLastRequest() external view returns (bytes32, FlightInfo memory) {
        FlightInfo memory flight = flightData[flightIds[lastRequestId].flightNumber][flightIds[lastRequestId].date];
        return (lastRequestId, flight);
    }

    /*
     * @dev Get the oracle fee
     * @return The oracle fee
     * @notice Get the fee required to make a request to the Oracle
     */
    function getOracleFee() external view returns (uint256) {
        return oracle.requestFee();
    }

    /**
     * @dev Implementation of _handleResponse from RestApiClient
     * @param requestId Unique identifier for the request
     * @param success Whether the API request was successful
     * @param data ABI-encoded response data according to the requested fields
     * @notice Internal function that processes the Oracle's response and pays out claims if applicable
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
        flight.landed = isLanded;
        flight.delayed = isLanded && isDelayed;
        if (isLanded) {
            flight.delayMinutes = delayMinutes;
        }
        flight.flightNumber = flightNumber;
        flight.date = date;

        emit FlightDelayVerified(flightNumber, date, flight.delayed, delayMinutes);
        if (flight.delayed) {
            flight.claimed = true;
            flight.claimTimestamp = block.timestamp;
            // Transfer payout to claimant
            SafeTransferLib.safeTransferETH(claimer, INSURANCE_PAYOUT);
            emit ClaimPaid(claimer, flightNumber, date, INSURANCE_PAYOUT);
        }
        flightData[flightNumber][date] = flight;
        flightIds[requestId].date = date;
    }
}
