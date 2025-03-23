#!/usr/bin/env python
"""
TEE Oracle main entry point - standalone service mode.
"""
import argparse
import asyncio
import logging
import os
import sys
from pathlib import Path

# Add the tee directory to the path so imports work correctly
parent_dir = str(Path(__file__).parent.absolute())
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("tee-oracle")

# Import existing services (using absolute imports)
from services.blockchain import BlockchainService
from services.api_client import ApiClient
from services.response_processor import ResponseProcessor
from services.api_server import ApiServer
from utils.crypto import crypto_manager


async def oracle_loop(blockchain_service, api_client, processor, poll_interval=10):
    """Main Oracle service loop"""
    logger.info("Starting Oracle service loop")
    
    try:
        # Initialize the blockchain service
        await blockchain_service.initialize()
        
        # Process events callback
        async def process_event(event):
            logger.info(f"Processing request: {event.requestId}")
            
            try:
                # Make the API request
                api_response = await api_client.make_request(event.request)
                
                # Process the response
                processed_response = processor.process_response(event, api_response)
                
                # Submit to blockchain
                await blockchain_service.submit_response(
                    event.requestId,
                    processed_response.encoded_data
                )
                
                logger.info(f"Request {event.requestId} processed successfully")
            except Exception as e:
                logger.error(f"Error processing request {event.requestId}: {str(e)}")
        
        # Main loop
        while True:
            try:
                # Poll for new events
                await blockchain_service.poll_events(process_event)
                
                # Wait before the next poll
                await asyncio.sleep(poll_interval)
            except KeyboardInterrupt:
                logger.info("Oracle service interrupted by user")
                break
            except Exception as e:
                logger.error(f"Error in oracle loop: {str(e)}")
                await asyncio.sleep(poll_interval * 2)
    except Exception as e:
        logger.error(f"Fatal error in oracle loop: {str(e)}")
        raise


async def main():
    """
    Main function to run the TEE Oracle service.
    """
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='TEE Oracle Service')
    parser.add_argument('--provider', type=str, default=os.environ.get('WEB3_PROVIDER', 'http://localhost:8545'),
                        help='Web3 provider URL')
    parser.add_argument('--oracle-address', type=str, default=os.environ.get('ORACLE_ADDRESS'),
                        help='Oracle contract address')
    parser.add_argument('--poll-interval', type=int, default=os.environ.get('POLL_INTERVAL', 10),
                        help='Polling interval in seconds')
    parser.add_argument('--host', type=str, default=os.environ.get('HOSTNAME', '0.0.0.0'),
                        help='Host to run the API server on')
    parser.add_argument('--port', type=int, default=int(os.environ.get('PORT', 3000)),
                        help='Port to run the API server on')
    args = parser.parse_args()
    
    if not args.oracle_address:
        logger.error("Oracle contract address is required. Set it with --oracle-address or ORACLE_ADDRESS env var.")
        return 1
    
    try:
        # Initialize crypto manager with the DStack key
        logger.info("Initializing crypto manager with DStack key")
        await crypto_manager.initialize()
        logger.info("Crypto manager initialized")
    except Exception as e:
        logger.error(f"Failed to initialize crypto manager: {str(e)}")
        return 1
    
    # Create services
    blockchain_service = BlockchainService(args.provider, args.oracle_address)
    api_client = ApiClient()
    processor = ResponseProcessor()
    api_server = ApiServer(args.host, args.port)
    
    # Create tasks for the API server and Oracle service
    api_server_task = asyncio.create_task(api_server.start())
    oracle_task = asyncio.create_task(oracle_loop(blockchain_service, api_client, processor, args.poll_interval))
    
    try:
        # Wait for both tasks to complete (they run indefinitely unless interrupted)
        await asyncio.gather(oracle_task, api_server_task)
    except KeyboardInterrupt:
        logger.info("Stopping TEE Oracle service...")
    except Exception as e:
        logger.error(f"Error in TEE Oracle service: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    asyncio.run(main())