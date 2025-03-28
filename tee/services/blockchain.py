"""
Blockchain service for the TEE Oracle.

This module provides a service for interacting with the blockchain.
"""
import asyncio
import logging
import os
import sys
from pathlib import Path
from typing import Callable, List, Dict, Any, Optional, Awaitable, Union

# Add the parent directory to the path so imports work correctly
parent_dir = str(Path(__file__).parent.parent.absolute())
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

from dstack_sdk import AsyncTappdClient, DeriveKeyResponse
from eth_typing import ChecksumAddress, HexStr
from web3 import Web3, AsyncWeb3, AsyncHTTPProvider
from web3.contract import Contract
from web3.exceptions import TransactionNotFound
from web3.types import EventData, TxReceipt

from config.settings import settings
from models.request import RequestEvent, RequestData
from utils.abi import get_contract_abi
from utils.loggingx import get_logger
from utils.crypto import crypto_manager

logger = get_logger(__name__)


class BlockchainService:
    """Service for interacting with the blockchain"""
    
    def __init__(self, provider_url: Optional[str] = None, oracle_address: Optional[str] = None):
        """Initialize the blockchain service"""
        self.provider_url = provider_url or settings.web3_provider
        self.oracle_address = oracle_address or settings.oracle_address
        self.dstack_client = AsyncTappdClient()
        self.web3 = None
        self.oracle_contract = None
        self.initialized = False
        self.last_processed_block = 0
    
    async def initialize(self):
        """Initialize the blockchain service"""
        if self.initialized:
            return
        
        # Set up Web3 provider
        logger.info(f"Initializing blockchain service with provider: {self.provider_url}")
        
        if not self.provider_url:
            raise ValueError("Web3 provider URL is required")
        
        if not self.oracle_address:
            raise ValueError("Oracle contract address is required")
        
        # Use AsyncWeb3 instead of Web3 for async support
        self.web3 = AsyncWeb3(AsyncHTTPProvider(self.provider_url))
        
        # Ensure address is checksum format
        self.oracle_address = Web3.to_checksum_address(self.oracle_address)
        
        # Load the oracle contract
        oracle_abi = get_contract_abi("Oracle")
        self.oracle_contract = self.web3.eth.contract(address=self.oracle_address, abi=oracle_abi)
        
        # Get the current block number as starting point
        self.last_processed_block = await self.web3.eth.block_number
        logger.info(f"Starting from block {self.last_processed_block}")
        
        # Get the Oracle's public key
        try:
            public_key = await self.oracle_contract.functions.getPublicKey().call()
            if public_key != crypto_manager._public_key:
                logger.error("Public key mismatch between contract and crypto manager. Expected %s, got %s", crypto_manager._public_key, public_key)
            else:
                logger.info("Public key matches between contract and crypto manager")
        except Exception as e:
            logger.critical(f"Could not retrieve Oracle public key: {str(e)}")
        
        self.initialized = True
        logger.info("Blockchain service initialized")
    
    async def get_past_events(
        self,
        from_block: int,
        to_block: Union[int, str] = 'latest'
    ) -> List[EventData]:
        """Get past events from the oracle contract"""
        if not self.initialized:
            await self.initialize()
        
        logger.info(f"Getting events from block {from_block} to {to_block}")
        events = await self.oracle_contract.events.RestApiRequest.get_logs(
            from_block=from_block,
            to_block=to_block
        )
        if len(events) > 0:
            logger.info(f"Found {len(events)} events")
        else:
            logger.info("No events found")
        return events
    
    def parse_request_event(self, event: EventData) -> RequestEvent:
        """Parse an event into a RequestEvent model"""
        args = event.args
        
        # Convert requestId from bytes to hex string
        request_id_hex = Web3.to_hex(args.requestId)
        
        logger.info(f"Request ID: {request_id_hex}")
        logger.info(f"Parsing request event: {args}")
        
        # Create request data
        request_data = RequestData(
            url=args.request.url,  # url is at index 1
            urlEncrypted=args.request.urlEncrypted,
            method=args.request.method,  # method is at index 0
            headers=args.request.headers,  # headers is at index 2
            queryParams=args.request.queryParams,  # queryParams is at index 3
            body=args.request.body,  # body is at index 4
            bodyEncrypted=args.request.bodyEncrypted,
            responseFields=args.request.responseFields  # responseFields is at index 5
        )
        
        # Create and return the event model
        return RequestEvent(
            requestId=request_id_hex,
            requester=args.requester,
            request=request_data,
            blockNumber=event.blockNumber,
            transactionHash=Web3.to_hex(event.transactionHash)
        )
    
    async def poll_events(
        self,
        callback: Callable[[RequestEvent], Awaitable[None]]
    ):
        """Poll for new events and process them"""
        if not self.initialized:
            await self.initialize()
        
        current_block = await self.web3.eth.block_number
        if current_block <= self.last_processed_block:
            # No new blocks
            return
        
        # Get events from the last processed block to the current block
        events = await self.get_past_events(self.last_processed_block + 1, current_block)
        
        # Process events
        for event in events:
            try:
                request_event = self.parse_request_event(event)
                await callback(request_event)
            except Exception as e:
                logger.error(f"Error processing event: {str(e)}", exc_info=True)
        
        # Update the last processed block
        self.last_processed_block = current_block
    
    async def submit_response(self, request_id: HexStr, response_data: bytes) -> TxReceipt:
        """Submit a response to the oracle contract"""
        if not self.initialized:
            await self.initialize()
        
        logger.info(f"Submitting response for request {request_id}")
        
        try:
            fixed_private_key = os.getenv('PRIVATE_KEY')
            if fixed_private_key:
                private_key_bytes = fixed_private_key
            else:
                # Get the TEE key for signing from DStack
                derive_key = await self.dstack_client.derive_key('/', 'tee-oracle')
                private_key_bytes = derive_key.toBytes(32)  # Get limited private key bytes

            # Get account from private key
            account = self.web3.eth.account.from_key(private_key_bytes)
            logger.debug(f"Using derived address for signing: {account.address}")
            
            # Convert request ID to bytes
            request_id_bytes = Web3.to_bytes(hexstr=request_id)
            
            # Create transaction data
            gas_price = await self.web3.eth.gas_price
            # Set priority fee to 80% of base fee to ensure it's always lower
            priority_fee = min(Web3.to_wei(0.1, 'gwei'), int(gas_price * 0.8))
            # Set max fee to base fee plus a 20% buffer
            max_fee = int(gas_price * 1.2)
            
            tx_data = await self.oracle_contract.functions.fulfillRestApiRequest(
                request_id_bytes,
                response_data
            ).build_transaction({
                'from': account.address, 
                'gas': 500000, # TODO estimate or get from request and how much was paid for callback gas
                'maxFeePerGas': max_fee,
                'maxPriorityFeePerGas': priority_fee,
                'nonce': await self.web3.eth.get_transaction_count(account.address),
                'chainId': await self.web3.eth.chain_id,
                'value': 0
            })
            
            # Log transaction data
            logger.debug(f"Transaction data: {tx_data}")
            
            # Sign the transaction
            signed_tx = self.web3.eth.account.sign_transaction(tx_data, private_key_bytes)
            
            # Send the raw transaction
            tx_hash = await self.web3.eth.send_raw_transaction(signed_tx.raw_transaction)
            logger.info(f"Transaction submitted with hash: {Web3.to_hex(tx_hash)}")
            
            # Wait for transaction receipt
            receipt = await self.web3.eth.wait_for_transaction_receipt(tx_hash, timeout=60)
            logger.info(f"Transaction confirmed in block {receipt['blockNumber']}")
            
            # Return the transaction receipt
            return receipt
            
        except Exception as e:
            logger.error(f"Error submitting response: {str(e)}", exc_info=True)
            raise 