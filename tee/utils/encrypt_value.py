#!/usr/bin/env python
"""
Command-line utility for encrypting values for use in smart contracts.

This script retrieves the Oracle's Ethereum address and encrypts data using
ECIES for secure storage in smart contract requests.
"""
import argparse
import sys
from pathlib import Path
from typing import Optional, Any

# Add the parent directory to the path so imports work correctly
parent_dir = str(Path(__file__).parent.parent.absolute())
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

import asyncio
import base64
from web3 import Web3
from ecies import encrypt as ecies_encrypt

from utils.abi import get_contract_abi
from utils.loggingx import get_logger

logger = get_logger(__name__)


async def get_oracle_ethereum_address(web3_url: str, oracle_address: str) -> str:
    """
    Get the Oracle's Ethereum address from the contract.
    
    Args:
        web3_url: URL of the Ethereum node
        oracle_address: Address of the Oracle contract
        
    Returns:
        The Oracle's Ethereum address
    """
    w3 = Web3(Web3.HTTPProvider(web3_url))
    oracle_abi = get_contract_abi("Oracle")
    oracle_contract = w3.eth.contract(address=oracle_address, abi=oracle_abi)
    
    try:
        eth_address = oracle_contract.functions.getPublicKeyAddress().call()
        if not eth_address or eth_address == "0x0000000000000000000000000000000000000000":
            raise ValueError("Oracle contract does not have a public key address set yet")
        return eth_address
    except Exception as e:
        logger.error(f"Error getting public key address: {str(e)}")
        raise


async def encrypt_value(value: str, web3_url: str, oracle_address: str) -> str:
    """
    Encrypt a value for use in a smart contract request using ECIES.
    
    Args:
        value: The value to encrypt
        web3_url: URL of the Ethereum node
        oracle_address: Address of the Oracle contract
        
    Returns:
        The encrypted value as base64-encoded string
    """
    try:
        # Get the Oracle's Ethereum address
        eth_address = await get_oracle_ethereum_address(web3_url, oracle_address)
        
        # Get the full public key for the address
        # In real implementation, this would retrieve the public key from the contract
        # For now we'll derive it from the contract
        oracle_abi = get_contract_abi("Oracle")
        w3 = Web3(Web3.HTTPProvider(web3_url))
        oracle_contract = w3.eth.contract(address=oracle_address, abi=oracle_abi)
        public_key = oracle_contract.functions.getPublicKey().call()
        
        if not public_key:
            raise ValueError("Oracle contract does not have a public key set")
            
        # Ensure the public key has 0x prefix
        if not public_key.startswith('0x'):
            public_key = '0x' + public_key
        
        # Encrypt the value with ECIES
        encrypted_bytes = ecies_encrypt(public_key, value.encode('utf-8'))
        
        # Convert to base64 for easier handling
        encrypted_b64 = base64.b64encode(encrypted_bytes).decode('utf-8')
        
        return encrypted_b64
    except Exception as e:
        logger.error(f"Error encrypting value: {str(e)}")
        raise


async def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(description="Encrypt values for use in smart contract requests")
    parser.add_argument("value", help="The value to encrypt")
    parser.add_argument("--provider", default="http://localhost:8545", help="Ethereum node URL")
    parser.add_argument("--oracle", required=True, help="Oracle contract address")
    
    args = parser.parse_args()
    
    try:
        encrypted = await encrypt_value(args.value, args.provider, args.oracle)
        print(f"\nEncrypted value: {encrypted}\n")
        print("Use this value in your smart contract request with the 'encrypted' flag set to true.")
        print("Example:")
        print("""
    IOracle.KeyValue memory apiKey = IOracle.KeyValue({
        key: "api_key", 
        value: "%s",
        encrypted: true
    });
        """ % encrypted)
    except Exception as e:
        print(f"Error: {str(e)}")
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main())) 