# TeeAPI: On-Chain API using TEE for EthGlobal Trifecta

TeeAPI is a Trusted Execution Environment (TEE) powered bridge between blockchain smart contracts and external REST APIs. It enables smart contracts to securely consume data from external APIs while maintaining decentralization and security principles.

## 📑 Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Technology Stack](#technology-stack)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Running the Oracle Service](#running-the-oracle-service)
  - [Testing with Foundry](#testing-with-foundry)
- [Developer Guide](#developer-guide)
  - [Using the Oracle in Your Smart Contracts](#using-the-oracle-in-your-smart-contracts)
  - [Making API Requests](#making-api-requests)
  - [Handling Responses](#handling-responses)
  - [Using Encryption Features](#using-encryption-features)
  - [Using Conditional Verification](#using-conditional-verification)
- [Architecture](#architecture)
- [Security Considerations](#security-considerations)
- [License](#license)

## 🔍 Overview

TeeAPI solves a fundamental problem in blockchain technology: accessing off-chain data in a secure, decentralized manner. By utilizing Trusted Execution Environments (TEEs), TeeAPI enables smart contracts to:

1. Make REST API requests to external services
2. Process and validate responses in a verifiable environment
3. Receive the data on-chain in a secure, tamper-proof way

This approach eliminates centralized oracle dependencies while providing smart contracts with secure access to the vast world of web APIs.

## 📂 Project Structure

The project consists of two main components:

```
TeeAPI/
├── contracts/            # Smart contract code
│   ├── src/              # Main contract implementations
│   │   ├── Oracle.sol    # Core Oracle contract
│   │   ├── RestApiClient.sol  # Base class for API consumers
│   │   ├── interfaces/   # Contract interfaces
│   │   └── examples/     # Example consumer contracts
│   └── test/             # Foundry test files
└── tee/                  # TEE Service
    ├── main.py           # Service entry point
    ├── services/         # Core services implementation
    │   ├── blockchain.py # Blockchain interaction service
    │   ├── api_client.py # External API client
    │   └── response_processor.py # Response processing logic
    ├── models/           # Data models
    └── utils/            # Utility functions
        ├── crypto.py     # Cryptography utilities
        ├── encrypt_value.py # Tool for encrypting values for contracts
        ├── generate_keypair.py # Tool for generating Ethereum keypairs
        └── set_public_key.py # Tool for setting public key in contract
```

## 🛠️ Technology Stack

### Smart Contracts
- **Solidity** - Smart contract language
- **Foundry** - Development framework for testing and deployment
- **Solady** - Gas-optimized Solidity components

### TEE Service
- **Python** - Core language for the TEE service
- **dstack-sdk** - SDK for TEE attestation and secure key management
- **Web3.py** - Ethereum interaction library
- **eciespy** - ECIES encryption for secp256k1 keys
- **aiohttp** - Asynchronous HTTP client/server
- **Docker** - Containerization for easy deployment

## 🚀 Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- An Ethereum node/provider (local Anvil or testnet/mainnet)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/TeeAPI.git
cd TeeAPI
```

2. Install dependencies:
```bash
# Install contract dependencies
cd contracts
forge install

# Build the TEE service Docker image
cd ../tee
docker build -t tee-oracle .
```

### Running the Oracle Service

1. Start a local Ethereum node (if testing locally):
```bash
cd contracts
anvil
```

2. Deploy the Oracle contract:
```bash
forge script script/DeployOracle.s.sol --broadcast --rpc-url http://localhost:8545
```

3. Generate and set an Ethereum keypair (see [Setting Up Public Keys](#setting-up-public-keys) section for details)

4. Run the TEE service:
```bash
docker run --rm -p 3000:3000 \
  -e WEB3_PROVIDER="http://host.docker.internal:8545" \
  -e ORACLE_ADDRESS="0x<deployed_oracle_address>" \
  -e DSTACK_SIMULATOR_ENDPOINT="http://host.docker.internal:8090" \
  tee-oracle
```

### Testing with Foundry

Run the test suite to verify everything works:
```bash
cd contracts
forge test -vvv
```

## 👨‍💻 Developer Guide

### Using the Oracle in Your Smart Contracts

1. Inherit from the `RestApiClient` contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RestApiClient} from "path/to/RestApiClient.sol";
import {IOracle} from "path/to/interfaces/IOracle.sol";

contract MyConsumer is RestApiClient {
    constructor(address _oracle) RestApiClient(_oracle) {}
    
    // Your contract implementation...
}
```

2. Implement the required callback function:

```solidity
function _handleResponse(bytes32 requestId, bool success, bytes calldata data) 
    internal 
    override 
{
    // Handle the response data
    require(success, "API request failed");
    
    // Decode the response data based on your responseFields
    (uint256 value1, string memory value2) = abi.decode(data, (uint256, string));
    
    // Use the data in your contract logic
    // ...
}
```

### Making API Requests

Create a function to make API requests:

```solidity
function requestExternalData() external payable returns (bytes32) {
    // Define response fields to extract from the JSON
    IOracle.ResponseField[] memory responseFields = new IOracle.ResponseField[](2);
    responseFields[0] = IOracle.ResponseField({
        path: "$.field1", 
        responseType: "uint256"
    });
    responseFields[1] = IOracle.ResponseField({
        path: "$.field2", 
        responseType: "string"
    });

    // Create query parameters (optional)
    IOracle.KeyValue[] memory queryParams = new IOracle.KeyValue[](1);
    queryParams[0] = IOracle.KeyValue({key: "param1", value: "value1"});

    // Make the request
    bytes32 requestId = makeRequest({
        method: IOracle.HttpMethod.GET,
        url: "https://api.example.com/endpoint",
        urlEncrypted: false,
        headers: new IOracle.KeyValue[](0),
        queryParams: queryParams,
        body: "",
        bodyEncrypted: false,
        responseFields: responseFields
    });

    return requestId;
}
```

### Handling Responses

The Oracle service will automatically process your request, call the external API, and call back to your contract with the result. Your implementation of `_handleResponse` will be triggered with the processed data.

```solidity
event DataReceived(uint256 value1, string value2);

function _handleResponse(bytes32 requestId, bool success, bytes calldata data) 
    internal 
    override 
{
    require(success, "API request failed");
    
    // Decode the response data
    (uint256 value1, string memory value2) = abi.decode(data, (uint256, string));
    
    // Emit an event with the received data
    emit DataReceived(value1, value2);
    
    // Store the data or perform other operations
    // ...
}
```

### Using Encryption Features

For secure API requests that contain sensitive data like API keys, you can use the Ethereum-based ECIES encryption:

1. Get the Oracle's Ethereum public key and address:
```solidity
string memory publicKey = oracle.getPublicKey();
address keyAddress = oracle.getPublicKeyAddress();
```

2. Encrypt values off-chain using the `encrypt_value.py` utility:
```bash
python tee/utils/encrypt_value.py "my-api-key" --oracle 0x<oracle_address> --provider http://localhost:8545
```
or `/encrypt` endpoint of the API.

3. Use the encrypted value in your API request:
```solidity
// Create query parameters with an encrypted API key
IOracle.KeyValue[] memory queryParams = new IOracle.KeyValue[](1);
queryParams[0] = IOracle.KeyValue({
    key: "api_key", 
    value: "encrypted-value-from-script", 
    encrypted: true
});

// Make the request
bytes32 requestId = makeRequest({
    method: IOracle.HttpMethod.GET,
    url: "https://api.example.com/endpoint",
    urlEncrypted: false,
    headers: headers,
    queryParams: queryParams,
    body: "",
    bodyEncrypted: false,
    responseFields: responseFields
});
```

### Using Conditional Verification

The conditional verification feature allows you to verify values against conditions without revealing the actual data on-chain. This is useful for privacy-preserving verifications:

1. Define a response field with a condition:
```solidity
// Define a condition to check if bank balance > threshold
IOracle.Condition memory condition = IOracle.Condition({
    operator: "gt",  // greater than
    value: "1000",   // threshold value to check against
    encrypted: false // can be encrypted for privacy
});

// Set up the response field with condition
IOracle.ResponseField[] memory responseFields = new IOracle.ResponseField[](1);
responseFields[0] = IOracle.ResponseField({
    path: "$.account.balance", // JSON path to the balance field
    responseType: "uint256",   // Type of the data being compared
    condition: condition       // The condition to check
});
```

2. Make the request as usual:
```solidity
bytes32 requestId = makeRequest({
    method: IOracle.HttpMethod.GET,
    url: "https://api.bank.example/accounts/123",
    urlEncrypted: false,
    headers: headers,
    queryParams: new IOracle.KeyValue[](0),
    body: "",
    bodyEncrypted: false,
    responseFields: responseFields
});
```

3. Handle the response (which will now be a boolean result):
```solidity
function _handleResponse(bytes32 requestId, bool success, bytes calldata data) 
    internal 
    override 
{
    require(success, "API request failed");
    
    // Decode the boolean verification result
    bool isConditionMet = abi.decode(data, (bool));
    
    // Use the verification result in your logic
    if (isConditionMet) {
        // Condition was met (e.g., balance > threshold)
        // Proceed with operation that requires this condition
    } else {
        // Condition was not met
        // Handle the failure case
    }
}
```

4. Available Condition Operators:
   - `"eq"` or `"equals"`: Equal to
   - `"neq"` or `"not_equals"`: Not equal to
   - `"gt"` or `"greater_than"`: Greater than
   - `"gte"` or `"greater_than_or_equals"`: Greater than or equal to
   - `"lt"` or `"less_than"`: Less than
   - `"lte"` or `"less_than_or_equals"`: Less than or equal to
   - `"contains"`: String contains substring (for string types)
   - `"startswith"`: String starts with prefix (for string types)
   - `"endswith"`: String ends with suffix (for string types)

5. Privacy Preservation:
   When using conditions, the actual values from the API are never exposed on-chain, only the boolean result of the condition check. This allows for sensitive data to be verified in the TEE without being publicly revealed.

## 🏗️ Architecture

TeeAPI operates in three key steps:

1. **Request**: A smart contract calls the Oracle contract to request external API data
2. **Execution**: The TEE service monitors for request events, makes the API call, and processes the response
3. **Fulfillment**: The TEE service submits the API response back to the Oracle contract, which forwards it to the requesting contract

The system uses TEEs to ensure that the API requests and response processing happen in a tamper-proof environment, maintaining the security and integrity of the data.

## 🔒 Security Considerations

- The Oracle uses a role-based access control system to ensure only authorized TEEs can submit responses
- Response data is processed in a secure TEE environment
- Smart contracts should validate API responses before using them for critical operations
- Be mindful of gas costs when processing large responses

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

### Using the API Server

The TeeAPI includes a simple API server that provides an endpoint for encrypting values. The API server is available at `http://localhost:3000` when running locally.

#### API Endpoints

- **GET /encrypt** - Encrypt a value
  ```
  GET /encrypt?value=sensitive_data_to_encrypt
  ```
  Response: The encrypted value as plain text
  
  This endpoint allows clients to encrypt sensitive data that can be sent to the blockchain and later decrypted inside the TEE service.