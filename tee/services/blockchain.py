"""
Blockchain service for the TEE Oracle.

This module provides a service for interacting with the blockchain.
"""
import asyncio
import logging
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
from utils.logging import get_logger

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
        logger.info(f"Found {len(events)} events")
        return events
    
    def parse_request_event(self, event: EventData) -> RequestEvent:
        """Parse an event into a RequestEvent model"""
        args = event.args
        
        logger.info(f"Parsing request event: {args}")
        
        # Convert requestId from bytes to hex string
        request_id_hex = Web3.to_hex(args.requestId)
        
        logger.info(f"Request ID: {request_id_hex}")
        
        # Create request data
        request_data = RequestData(
            url=args.request.url,  # url is at index 1
            method=args.request.method,  # method is at index 0
            headers=args.request.headers,  # headers is at index 2
            queryParams=args.request.queryParams,  # queryParams is at index 3
            body=args.request.body,  # body is at index 4
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
            # Use dstack to sign and send the transaction
            request_id_bytes = Web3.to_bytes(hexstr=request_id)
            
            # Create transaction data
            tx_data = await self.oracle_contract.functions.fulfillRestApiRequest(
                request_id_bytes,
                response_data
            ).build_transaction({
                'from': None,  # Will be filled by dstack
                'gas': 500000,
                'maxFeePerGas': await self.web3.eth.gas_price,
                'nonce': None,  # Will be filled by dstack
            })
            
            # Sign transaction within the TEE
            derive_key = await self.dstack_client.derive_key('/', 'tee-oracle')
            asBytes = derive_key.toBytes()
            assert isinstance(asBytes, bytes)
            limitedSize = derive_key.toBytes(32)
            
            # TODO: Need to implement transaction sending through dstack
            # This is a placeholder until the dstack API is better understood
            
            # For now, log the transaction data
            logger.info(f"Transaction data: {tx_data}")
            logger.info(f"Would sign with derive key: {asBytes.hex()}")
            logger.info(f"Key limited to 32 bytes: {limitedSize.hex()}")
            
            # Get address from private key bytes
            account = self.web3.eth.account.from_key(limitedSize)
            address = account.address
            logger.info(f"Derived address: {address}")
            
            # Return a dummy receipt for now
            return {"transactionHash": "0x0"}
            
        except Exception as e:
            logger.error(f"Error submitting response: {str(e)}", exc_info=True)
            raise 