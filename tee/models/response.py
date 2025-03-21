"""
Response models for the TEE Oracle.

These models represent API responses to be sent back to smart contracts.
"""
from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional, Union
from eth_typing import ChecksumAddress, HexStr


class ApiResponse(BaseModel):
    """Model for an API response"""
    success: bool
    status: Optional[int] = None
    data: Any = None
    error: Optional[str] = None


class ProcessedResponse(BaseModel):
    """Model for a processed API response ready for blockchain submission"""
    requestId: HexStr
    requester: ChecksumAddress
    success: bool
    data: Any
    encoded_data: bytes


class ExtractionResult(BaseModel):
    """Model for data extracted from an API response"""
    path: str
    value: Any
    type_hint: Optional[str] = None
    

class ExtractedData(BaseModel):
    """Model for all extracted data from an API response"""
    success: bool
    results: List[ExtractionResult]
    error: Optional[str] = None 