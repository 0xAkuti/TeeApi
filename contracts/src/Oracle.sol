// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IOracle.sol";
import "./interfaces/IRestApiConsumer.sol";
import "solady/auth/OwnableRoles.sol";
import "solady/utils/SafeTransferLib.sol";
import "./libraries/ResponseLib.sol";

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

    /**
     * @dev Modifier to ensure a request is not already fulfilled
     */
    modifier notFulfilled(bytes32 requestId) {
        require(requestStatus[requestId] == REQUEST_ACTIVE, "Request not active");
        _;
    }

    /**
     * @dev Constructor
     * @param _requestFee Initial fee for making a request
     */
    constructor(uint256 _requestFee) {
        _initializeOwner(msg.sender);
        requestFee = _requestFee;
    }

    /**
     * @dev Implementation of the requestRestApi function from IOracle
     * @param request The REST API request details
     * @return requestId Unique identifier for the request
     */
    function requestRestApi(Request calldata request) external payable virtual returns (bytes32 requestId) {
        require(msg.value >= requestFee, "Insufficient fee");
        require(msg.sender.code.length > 0, "Requester must be a contract");

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
        notFulfilled(requestId)
        returns (bool)
    {
        address requester = ResponseLib.recoverRequester(requestId);

        require(requester != address(0) && requester.code.length > 0, "Invalid requester");

        requestStatus[requestId] = REQUEST_INACTIVE; // get gas refund

        // Process the response and call the callback on the requester
        bool success = ResponseLib.executeCallback(
            requester,
            requestId,
            true, // Assuming success for Phase 1
            responseData
        );

        emit RestApiResponse(requestId, success);

        return success;
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
     * @dev Withdraw fees collected by the oracle
     * @param recipient The address to send the fees to
     */
    function withdraw(address payable recipient) external onlyOwner {
        require(recipient != address(0), "Invalid recipient address");
        SafeTransferLib.safeTransferAllETH(recipient);
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
}
