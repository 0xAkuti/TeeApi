"""
ABI loading utilities for the TEE Oracle.

This module provides functions to load contract ABIs.
"""
import json
import os
from pathlib import Path
from typing import Dict, Any, Optional, List


def load_contract_json(contract_name: str) -> Dict[str, Any]:
    """
    Load contract JSON from the compiled output.
    
    Args:
        contract_name: The name of the contract (without .sol extension)
        
    Returns:
        The contract JSON data
    """
    # Define possible paths
    paths = [
        # Path if running from the tee directory
        Path("../contracts/out") / f"{contract_name}.sol" / f"{contract_name}.json",
        # Path if running from the project root
        Path("contracts/out") / f"{contract_name}.sol" / f"{contract_name}.json",
    ]
    
    # Try to find the file
    for path in paths:
        if path.exists():
            with open(path, "r") as f:
                return json.load(f)
    
    # If we get here, the file wasn't found
    raise FileNotFoundError(f"Could not find contract JSON for {contract_name}")


def get_contract_abi(contract_name: str) -> List[Dict[str, Any]]:
    """
    Get the ABI for a contract.
    
    Args:
        contract_name: The name of the contract (without .sol extension)
        
    Returns:
        The contract ABI
    """
    contract_json = load_contract_json(contract_name)
    return contract_json.get("abi", []) 