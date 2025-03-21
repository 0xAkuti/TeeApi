"""
Settings module for the TEE Oracle.

This module loads and manages configuration for the entire application.
"""
import os
from pydantic import BaseModel, Field
from typing import Optional


class OracleConfig(BaseModel):
    """Oracle configuration model"""
    web3_provider: str = Field(
        default=os.getenv("WEB3_PROVIDER", "http://localhost:8545"),
        description="Web3 provider URL"
    )
    oracle_address: str = Field(
        default=os.getenv("ORACLE_ADDRESS", ""),
        description="Address of the Oracle contract"
    )
    poll_interval: int = Field(
        default=int(os.getenv("POLL_INTERVAL", "5")),
        description="Interval in seconds for polling blockchain events"
    )
    api_timeout: int = Field(
        default=int(os.getenv("API_TIMEOUT", "30")),
        description="Timeout in seconds for API requests"
    )
    log_level: str = Field(
        default=os.getenv("LOG_LEVEL", "INFO"),
        description="Logging level"
    )


# Global settings instance
settings = OracleConfig()


def update_settings(**kwargs):
    """Update settings with the provided values"""
    global settings
    settings = OracleConfig(**{**settings.model_dump(), **kwargs})
    return settings 