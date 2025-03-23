"""
API Server for the TEE Oracle.

This module provides a FastAPI server with endpoints for interacting with the TEE Oracle.
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from pydantic import BaseModel
from eth_keys import keys

from utils.crypto import crypto_manager
from utils.loggingx import get_logger

logger = get_logger(__name__)

# Define API response models
class KeyInfoResponse(BaseModel):
    address: str
    public_key: str
    initialized: bool

class HealthResponse(BaseModel):
    status: str
    crypto_initialized: bool
    version: str = "1.0.0"

class ApiServer:
    """API Server for the TEE Oracle"""
    
    def __init__(self, host: str = "0.0.0.0", port: int = 3000):
        """Initialize the API server"""
        self.host = host
        self.port = port
        self.app = FastAPI(
            title="TEE Oracle API",
            description="API for interacting with the TEE Oracle service",
            version="1.0.0"
        )
        self._setup_routes()
        self._setup_middleware()
        
    def _setup_middleware(self):
        """Set up the CORS middleware"""
        self.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],  # Adjust in production
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
    
    def _setup_routes(self):
        """Set up the API routes"""
        @self.app.get("/", response_model=HealthResponse)
        async def root():
            """Root endpoint with basic service info"""
            return {
                "status": "online",
                "crypto_initialized": crypto_manager._initialized,
                "version": "1.0.0"
            }
        
        @self.app.get("/health", response_model=HealthResponse)
        async def health_check():
            """Check the health of the service"""
            try:
                return {
                    "status": "ok",
                    "crypto_initialized": crypto_manager._initialized,
                    "version": "1.0.0"
                }
            except Exception as e:
                logger.error(f"Health check failed: {str(e)}")
                raise HTTPException(status_code=500, detail=f"Health check failed: {str(e)}")
        
        @self.app.get("/keys", response_model=KeyInfoResponse)
        async def get_key_info():
            """Get the public key and address used by the TEE Oracle"""
            try:
                if not crypto_manager._initialized:
                    # Return empty data but with initialized=False
                    return {
                        "address": "",
                        "public_key": "",
                        "initialized": False
                    }
                
                # If we have a private key, derive the public key
                public_key = ""
                if crypto_manager._private_key:
                    private_key_obj = keys.PrivateKey(bytes.fromhex(crypto_manager._private_key[2:]))
                    public_key_obj = private_key_obj.public_key
                    public_key = public_key_obj.to_hex()
                
                return {
                    "address": crypto_manager._address or "",
                    "public_key": public_key,
                    "initialized": crypto_manager._initialized
                }
            except Exception as e:
                logger.error(f"Failed to get key info: {str(e)}")
                raise HTTPException(status_code=500, detail=f"Failed to get key info: {str(e)}")

        @self.app.get("/encrypt/{value}")
        async def encrypt(value: str):
            """
            Simple endpoint to encrypt a value
            
            Args:
                value: The value to encrypt passed as a query parameter
                
            Returns:
                The encrypted value
            """
            try:
                if not crypto_manager._initialized:
                    raise HTTPException(status_code=503, detail="Crypto manager not initialized")
                
                # Encrypt the value
                encrypted_value = crypto_manager.encrypt_for_contract(value)
                
                # Return just the encrypted value as plain text
                return encrypted_value
            except Exception as e:
                logger.error(f"Failed to encrypt value: {str(e)}")
                raise HTTPException(status_code=500, detail=f"Failed to encrypt value: {str(e)}")


    async def start(self):
        """Start the API server"""
        logger.info(f"Starting API server on {self.host}:{self.port}")
        config = uvicorn.Config(
            app=self.app,
            host=self.host,
            port=self.port,
            loop="asyncio",
            log_level="info"
        )
        server = uvicorn.Server(config)
        await server.serve()
    
    def get_app(self) -> FastAPI:
        """Get the FastAPI application"""
        return self.app 