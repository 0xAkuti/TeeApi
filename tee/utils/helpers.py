"""
Helper utilities for the TEE Oracle.

This module provides common helper functions used throughout the application.
"""
from typing import Optional


def get_external_ip() -> Optional[str]:
    """
    Get the external IP address of the machine.
    
    Returns:
        The external IP address, or None if it cannot be determined
    """
    try:
        import requests
        response = requests.get('https://api.ipify.org', timeout=5)
        return response.text
    except Exception:
        return None 