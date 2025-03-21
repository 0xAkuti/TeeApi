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

3. Run the TEE service:
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
        headers: new IOracle.KeyValue[](0),
        queryParams: queryParams,
        body: "",
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