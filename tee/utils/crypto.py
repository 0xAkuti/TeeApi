"""
Cryptography utilities for the TEE Oracle.

This module provides encryption and decryption functions for secure API requests.
"""
import base64
import os
from typing import Dict, Any, Optional, Union, Tuple

from ecies import encrypt as ecies_encrypt, decrypt as ecies_decrypt
from ecies.utils import generate_eth_key
from web3 import Web3
from dstack_sdk import AsyncTappdClient

from utils.logging import get_logger

logger = get_logger(__name__)

class CryptoManager:
    """Manages encryption and decryption for the TEE service using Ethereum keys"""
    
    def __init__(self):
        """Initialize the crypto manager"""
        self._private_key = None        # Ethereum private key (hex string)
        self._public_key = None         # Ethereum public key (hex string)
        self._address = None            # Ethereum address
        self._dstack_client = AsyncTappdClient()
        self._initialized = False
    
    async def initialize(self) -> None:
        """Initialize cryptography with DStack private key"""
        if self._initialized:
            return
            
        logger.info("Initializing cryptography manager with DStack key")
        
        # Get the private key from DStack
        try:
            derive_key = await self._dstack_client.derive_key('/', 'tee-oracle')
            private_key_bytes = derive_key.toBytes(32)
            
            # Set the private key as hex string
            self._private_key = '0x' + private_key_bytes.hex()
            
            # Derive address from private key
            account = Web3().eth.account.from_key(self._private_key)
            self._address = account.address
            
            self._initialized = True
            logger.info(f"Cryptography manager initialized with DStack key for address {self._address}")
        except Exception as e:
            logger.error(f"Failed to initialize cryptography manager: {str(e)}", exc_info=True)
            raise
    
    def set_public_key(self, public_key: str) -> None:
        """
        Set the public key manually
        
        Args:
            public_key: The public key as hex string (with or without 0x prefix)
        """
        try:
            # Ensure the public key has 0x prefix
            if not public_key.startswith('0x'):
                public_key = '0x' + public_key
                
            self._public_key = public_key
            self._initialized = True
            logger.info("Public key set manually")
        except Exception as e:
            logger.error(f"Failed to set public key: {str(e)}", exc_info=True)
            raise
    
    @property
    def public_key(self) -> str:
        """Get the public key as hex string"""
        if not self._initialized:
            raise ValueError("Crypto manager not initialized")
        return self._public_key
    
    @property
    def address(self) -> str:
        """Get the Ethereum address associated with the key"""
        if not self._initialized:
            raise ValueError("Crypto manager not initialized")
        return self._address
    
    def encrypt_for_contract(self, data: str) -> str:
        """
        Encrypt data for use in smart contracts
        
        This method encrypts data using the public key so it can be safely stored on-chain
        and later decrypted by the TEE service.
        
        Args:
            data: The string data to encrypt
            
        Returns:
            Base64-encoded encrypted data
        """
        if not self._initialized:
            raise ValueError("Crypto manager not initialized")
        
        if not self._public_key:
            raise ValueError("Public key not set")
        
        # Convert data to bytes
        data_bytes = data.encode('utf-8')
        
        # Encrypt with ECIES
        encrypted_bytes = ecies_encrypt(self._public_key, data_bytes)
        
        # Encode to base64 for contract storage
        return base64.b64encode(encrypted_bytes).decode('utf-8')
    
    def decrypt_from_contract(self, encrypted_data_b64: str) -> str:
        """
        Decrypt data that was encrypted for use in smart contracts
        
        Args:
            encrypted_data_b64: Base64-encoded encrypted data
            
        Returns:
            Decrypted data as a string
        """
        if not self._initialized:
            raise ValueError("Crypto manager not initialized")
            
        if not self._private_key:
            raise ValueError("Private key not available")
        
        # Decode the base64 data
        encrypted_bytes = base64.b64decode(encrypted_data_b64)
        
        # Decrypt with ECIES
        decrypted_bytes = ecies_decrypt(self._private_key, encrypted_bytes)
        
        return decrypted_bytes.decode('utf-8')
    
    def process_encrypted_request_data(self, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process a request with potentially encrypted fields
        
        Recursively searches through request data for specially marked encrypted fields
        and decrypts them. Fields are marked with the prefix "encrypted:" or can be in the
        form of {"encrypted": true, "data": "encrypted_data"}.
        
        Args:
            request_data: The request data dictionary
            
        Returns:
            Processed request data with decrypted values
        """
        if not self._initialized:
            raise ValueError("Crypto manager not initialized")
        
        def process_value(value):
            if isinstance(value, str) and value.startswith("encrypted:"):
                # String format: "encrypted:base64data"
                encrypted_value = value[10:]  # Remove "encrypted:" prefix
                return self.decrypt_from_contract(encrypted_value)
            elif isinstance(value, dict) and value.get("encrypted") is True and "data" in value:
                # Object format: {"encrypted": true, "data": "base64data"}
                return self.decrypt_from_contract(value["data"])
            elif isinstance(value, dict):
                # Recursively process nested dictionaries
                return {k: process_value(v) for k, v in value.items()}
            elif isinstance(value, list):
                # Recursively process lists
                return [process_value(item) for item in value]
            else:
                # Return unencrypted values as-is
                return value
        
        # Process the entire request_data dictionary
        return process_value(request_data)


# Create a singleton instance
crypto_manager = CryptoManager() 