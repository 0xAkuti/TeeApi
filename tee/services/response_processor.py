"""
Response processor service for the TEE Oracle.

This module provides a service for processing API responses.
"""
import logging
import sys
from pathlib import Path
from typing import List, Dict, Any, Optional

# Add the parent directory to the path so imports work correctly
parent_dir = str(Path(__file__).parent.parent.absolute())
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

import jsonpath_ng
from eth_abi import abi
from web3 import Web3

from models.request import RequestEvent
from models.response import ApiResponse, ProcessedResponse, ExtractedData, ExtractionResult
from utils.logging import get_logger

logger = get_logger(__name__)


class ResponseProcessor:
    """Service for processing API responses"""
    
    def process_response(self, request_event: RequestEvent, api_response: ApiResponse) -> ProcessedResponse:
        """Process an API response"""
        logger.info(f"Processing response for request {request_event.requestId}")
        
        # Extract data from the API response
        extracted_data = self._extract_data(request_event, api_response)
        
        # Encode the data for on-chain consumption
        encoded_data = self._encode_data(extracted_data)
        
        # Create and return the processed response
        return ProcessedResponse(
            requestId=request_event.requestId,
            requester=request_event.requester,
            success=extracted_data.success,
            data=extracted_data.results,
            encoded_data=encoded_data
        )
    
    def _extract_data(self, request_event: RequestEvent, api_response: ApiResponse) -> ExtractedData:
        """Extract data from an API response using JSONPath"""
        if not api_response.success:
            logger.error(f"API request failed: {api_response.error}")
            return ExtractedData(
                success=False,
                results=[],
                error=api_response.error
            )
        
        results = []
        raw_data = api_response.data
        
        # Handle string responses (non-JSON)
        if isinstance(raw_data, str):
            logger.warning(f"Response is a string, not JSON. Cannot apply JSONPath expressions.")
            # For each response field, add the raw string
            for i, field_path in enumerate(request_event.request.responseFields):
                results.append(ExtractionResult(
                    path=field_path,
                    value=raw_data,
                    type_hint="string"
                ))
        else:
            # Process each JSONPath expression
            for field_path in request_event.request.responseFields:
                try:
                    # Parse and apply the JSONPath expression
                    jsonpath_expr = jsonpath_ng.parse(field_path)
                    matches = [match.value for match in jsonpath_expr.find(raw_data)]
                    
                    if matches:
                        # Take the first match
                        value = matches[0]
                        # Determine the type
                        type_hint = self._get_type_hint(value)
                        
                        results.append(ExtractionResult(
                            path=field_path,
                            value=value,
                            type_hint=type_hint
                        ))
                    else:
                        logger.warning(f"No matches found for JSONPath: {field_path}")
                        results.append(ExtractionResult(
                            path=field_path,
                            value=None,
                            type_hint=None
                        ))
                
                except Exception as e:
                    logger.error(f"Error extracting field {field_path}: {str(e)}", exc_info=True)
                    results.append(ExtractionResult(
                        path=field_path,
                        value=None,
                        type_hint=None
                    ))
        
        return ExtractedData(
            success=True,
            results=results
        )
    
    def _get_type_hint(self, value: Any) -> Optional[str]:
        """Determine the Solidity type hint for a value"""
        if value is None:
            return None
        if isinstance(value, bool):
            return "bool"
        if isinstance(value, int):
            return "uint256" if value >= 0 else "int256"
        if isinstance(value, float):
            return "int256"  # Use int256 for floats, will need to be scaled
        if isinstance(value, str):
            return "string"
        if isinstance(value, list):
            return "array"
        if isinstance(value, dict):
            return "object"
        return "bytes"  # Default type
    
    def _prepare_value_for_encoding(self, value: Any, type_hint: Optional[str]) -> Any:
        """Prepare a value for encoding"""
        if value is None:
            # Handle None values based on type hint
            if type_hint == "bool":
                return False
            if type_hint in ["uint256", "int256"]:
                return 0
            if type_hint == "string":
                return ""
            if type_hint in ["array", "object"]:
                return []
            return b""  # bytes
        
        # Handle floats by scaling to integers
        if isinstance(value, float):
            # Scale by 10^18 for precision
            return int(value * 10**18)
        
        # Handle other types directly
        return value
    
    def _encode_data(self, extracted_data: ExtractedData) -> bytes:
        """Encode extracted data for on-chain consumption"""
        if not extracted_data.success:
            # Encode error message
            return Web3.to_bytes(text=extracted_data.error or "Unknown error")
        
        # Prepare values for encoding
        values = []
        types = []
        
        for result in extracted_data.results:
            # Get the type hint or default to bytes
            type_hint = result.type_hint or "bytes"
            
            # Prepare the value
            value = self._prepare_value_for_encoding(result.value, type_hint)
            
            # Add to our lists
            values.append(value)
            types.append(type_hint)
        
        try:
            # Encode the data using the updated abi.encode function
            return abi.encode(types, values)
        except Exception as e:
            logger.error(f"Error encoding data: {str(e)}", exc_info=True)
            # Fall back to encoding as bytes
            return Web3.to_bytes(text=f"Encoding error: {str(e)}") 