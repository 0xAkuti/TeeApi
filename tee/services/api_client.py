"""
API client service for the TEE Oracle.

This module provides a service for making external API requests.
"""
import asyncio
import json
import logging
import sys
from pathlib import Path
from typing import Dict, Any, Optional, List

# Add the parent directory to the path so imports work correctly
parent_dir = str(Path(__file__).parent.parent.absolute())
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

import aiohttp

from config.settings import settings
from models.request import RequestData, HttpMethod, KeyValue, ResponseField, Condition
from models.response import ApiResponse
from utils.loggingx import get_logger
from utils.crypto import crypto_manager

logger = get_logger(__name__)


class ApiClient:
    """Client for making external API requests"""
    
    def __init__(self, timeout: Optional[int] = None):
        """Initialize the API client"""
        self.timeout = timeout or settings.api_timeout
    
    async def make_request(self, request: RequestData) -> ApiResponse:
        """Make an API request"""
        # Process the request to decrypt any encrypted fields
        request = await self._process_encrypted_fields(request)
        
        # Get the full URL with query parameters
        url = request.get_full_url()
        logger.info(f"Making {request.method.name} request to {url}")
        
        # Prepare headers
        headers = request.get_headers_dict()
        
        try:
            # Create timeout
            timeout = aiohttp.ClientTimeout(total=self.timeout)
            
            async with aiohttp.ClientSession(timeout=timeout) as session:
                # Get the appropriate request method
                method_func = getattr(session, request.method.name.lower())
                
                # For GET and DELETE requests
                if request.method in [HttpMethod.GET, HttpMethod.DELETE]:
                    async with method_func(url, headers=headers) as response:
                        return await self._process_response(response)
                
                # For POST, PUT, PATCH requests
                else:
                    # Prepare the request body
                    body_data = request.body
                    content_type = headers.get('Content-Type', '')
                    
                    # If JSON content type and body is string, try to parse as JSON
                    if 'application/json' in content_type and body_data:
                        try:
                            body_data = json.loads(body_data)
                        except json.JSONDecodeError:
                            logger.warning(f"Failed to parse body as JSON despite Content-Type")
                    
                    # Make the request
                    kwargs = {
                        'headers': headers,
                    }
                    
                    # Add the appropriate body parameter
                    if isinstance(body_data, dict):
                        kwargs['json'] = body_data
                    elif body_data:
                        kwargs['data'] = body_data
                    
                    # Make the request
                    async with method_func(url, **kwargs) as response:
                        return await self._process_response(response)
        
        except asyncio.TimeoutError:
            logger.error(f"Request to {url} timed out after {self.timeout} seconds")
            return ApiResponse(
                success=False,
                error=f"Request timed out after {self.timeout} seconds"
            )
        
        except Exception as e:
            logger.error(f"Error making request to {url}: {str(e)}", exc_info=True)
            return ApiResponse(
                success=False,
                error=f"Request failed: {str(e)}"
            )
    
    async def _process_encrypted_fields(self, request: RequestData) -> RequestData:
        """Process and decrypt encrypted fields in the request"""
        # Create a new request object to avoid modifying the original
        processed_request = RequestData(
            method=request.method,
            url=request.url,
            urlEncrypted=request.urlEncrypted,
            headers=[],  # Will be filled in
            queryParams=[],  # Will be filled in
            body=request.body,
            bodyEncrypted=request.bodyEncrypted,
            responseFields=[]  # Will be filled in with processed conditions
        )
        
        # Decrypt URL if needed
        if request.urlEncrypted:
            processed_request.url = crypto_manager.decrypt_from_contract(request.url)
            processed_request.urlEncrypted = False
            logger.info(f"Decrypted URL: {processed_request.url}")
        
        # Decrypt body if needed
        if request.bodyEncrypted:
            processed_request.body = crypto_manager.decrypt_from_contract(request.body)
            processed_request.bodyEncrypted = False
            logger.info("Request body was decrypted")
        
        # Process headers
        for header in request.headers:
            if header.encrypted:
                # Decrypt the header value
                decrypted_value = crypto_manager.decrypt_from_contract(header.value)
                processed_request.headers.append(KeyValue(
                    key=header.key,
                    value=decrypted_value,
                    encrypted=False
                ))
                logger.info(f"Decrypted header: {header.key}")
            else:
                # Keep as-is
                processed_request.headers.append(header)
        
        # Process query parameters
        for param in request.queryParams:
            if param.encrypted:
                # Decrypt the parameter value
                decrypted_value = crypto_manager.decrypt_from_contract(param.value)
                processed_request.queryParams.append(KeyValue(
                    key=param.key,
                    value=decrypted_value,
                    encrypted=False
                ))
                logger.info(f"Decrypted query parameter: {param.key}")
            else:
                # Keep as-is
                processed_request.queryParams.append(param)
        
        # Process response fields with conditions
        for field in request.responseFields:
            processed_field = ResponseField(
                path=field.path,
                responseType=field.responseType
            )
            
            # Process condition if present
            if field.condition:
                condition_value = field.condition.value
                
                # Decrypt the condition value if encrypted
                if field.condition.encrypted:
                    condition_value = crypto_manager.decrypt_from_contract(condition_value)
                    logger.info(f"Decrypted condition value for field: {field.path}")
                
                # Create new condition with decrypted value
                processed_field.condition = Condition(
                    operator=field.condition.operator,
                    value=condition_value,
                    encrypted=False  # Mark as already decrypted
                )
            else:
                # No condition or already decrypted
                processed_field.condition = field.condition
                
            processed_request.responseFields.append(processed_field)
        
        return processed_request
    
    async def _process_response(self, response: aiohttp.ClientResponse) -> ApiResponse:
        """Process an HTTP response"""
        try:
            # Try to parse as JSON first
            try:
                data = await response.json()
            except:
                # Fall back to text
                data = await response.text()
                
            logger.info(f"Response data: {data}")
            
            # Check if the response is successful
            if response.status < 400:
                logger.info(f"Request succeeded with status {response.status}")
                return ApiResponse(
                    success=True,
                    status=response.status,
                    data=data
                )
            else:
                logger.error(f"Request failed with status {response.status}")
                return ApiResponse(
                    success=False,
                    status=response.status,
                    error=f"Request failed with status {response.status}",
                    data=data
                )
        
        except Exception as e:
            logger.error(f"Error processing response: {str(e)}", exc_info=True)
            return ApiResponse(
                success=False,
                error=f"Error processing response: {str(e)}"
            ) 