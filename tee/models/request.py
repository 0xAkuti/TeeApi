"""
Request models for the TEE Oracle.

These models represent API requests coming from smart contracts.
"""
from pydantic import BaseModel, Field, field_validator
from typing import List, Optional, Dict, Any
from enum import IntEnum
from eth_typing import ChecksumAddress, HexStr


class HttpMethod(IntEnum):
    """HTTP method enum matching Solidity"""
    GET = 0
    POST = 1
    PUT = 2
    DELETE = 3
    PATCH = 4


class KeyValue(BaseModel):
    """Key-value pair for headers or query parameters"""
    key: str
    value: str
    encrypted: bool = False


class Condition(BaseModel):
    """Condition for response verification matching Solidity struct"""
    operator: str  # "gt", "lt", "eq", "contains", etc.
    value: str
    encrypted: bool = False


class ResponseField(BaseModel):
    """Field to extract from JSON response"""
    path: str
    responseType: str
    condition: Optional[Condition] = None
    
    def has_condition(self) -> bool:
        """Check if this field has a condition that should be verified"""
        return self.condition is not None and self.condition.operator != ""


class RequestData(BaseModel):
    """Model for a REST API request matching Solidity contract struct"""
    method: HttpMethod
    url: str
    urlEncrypted: bool = False
    headers: List[KeyValue] = Field(default_factory=list)
    queryParams: List[KeyValue] = Field(default_factory=list)
    body: str = ""
    bodyEncrypted: bool = False
    responseFields: List[ResponseField]
    
    def get_headers_dict(self) -> Dict[str, str]:
        """Convert headers list to dictionary"""
        return {h.key: h.value for h in self.headers}
    
    def get_full_url(self) -> str:
        """Get full URL with query parameters"""
        if not self.queryParams:
            return self.url
            
        query_string = "&".join([f"{param.key}={param.value}" for param in self.queryParams])
        connector = "?" if "?" not in self.url else "&"
        return f"{self.url}{connector}{query_string}"


class RequestEvent(BaseModel):
    """Model for a REST API request event from the blockchain"""
    requestId: HexStr
    requester: ChecksumAddress
    request: RequestData
    blockNumber: int
    transactionHash: HexStr 