"""
Logging utility for the TEE Oracle.

This module sets up logging for the entire application.
"""
import logging
import sys
from typing import Union


def setup_logging(level: Union[str, int] = "INFO"):
    """Set up logging for the application"""
    if isinstance(level, str):
        level = getattr(logging, level.upper())
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(level)
    
    # Clear existing handlers
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    
    # Create formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    console_handler.setFormatter(formatter)
    
    # Add handlers to logger
    root_logger.addHandler(console_handler)
    
    return root_logger


def get_logger(name: str):
    """Get a logger with the given name"""
    return logging.getLogger(name) 