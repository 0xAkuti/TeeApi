#!/usr/bin/env python
"""
Utility for consistent ECIES keys using standard Ethereum libraries.

This script generates consistent keypairs for encryption/decryption using the same
elliptic curve implementation as Ethereum wallets. It ensures the same public key
is always derived from a given private key.
"""
import base64
import argparse
import os
from eth_account import Account
from eth_keys import keys
import ecies

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Generate consistent Ethereum keypairs for encryption")
    parser.add_argument("--private-key", help="Private key to use (with or without 0x prefix)")
    parser.add_argument("--url", default="https://jsonplaceholder.typicode.com/todos", help="URL to encrypt")
    parser.add_argument("--save-keys", action="store_true", help="Save keys to files")
    parser.add_argument("--output-dir", default=".", help="Directory to save key files")
    args = parser.parse_args()

    # Account.enable_unaudited_hdwallet_features()
    
    if args.private_key:
        # Use provided private key
        private_key_hex = args.private_key.replace("0x", "")
        
        # Format with 0x prefix
        private_key = "0x" + private_key_hex
        
        print("\n=== Using Existing Private Key ===")
    else:
        # Generate a fresh keypair - directly use eth_account which is more stable
        # than ecies.utils.generate_eth_key
        account = Account.create()
        private_key = account.key.hex()
        private_key_hex = private_key[2:]  # Remove 0x prefix
        
        print("\n=== Generated New Keys ===")

    # Consistently derive public key using eth_keys
    private_key_obj = keys.PrivateKey(bytes.fromhex(private_key_hex))
    public_key_obj = private_key_obj.public_key
    
    # Get public key as hex without 0x04 prefix (uncompressed format)
    public_key_hex = public_key_obj.to_hex()[2:]
    
    # Get Ethereum address
    eth_address = public_key_obj.to_checksum_address()

    print(f"Private Key: {private_key}")
    print(f"Public Key:  0x{public_key_hex}")
    print(f"ETH Address: {eth_address}")

    # Encrypt the URL using this public key with eciespy
    url = args.url
    encrypted = ecies.encrypt(public_key_hex, url.encode('utf-8'))
    encrypted_b64 = base64.b64encode(encrypted).decode('utf-8')

    # Save keys to files if requested
    if args.save_keys:
        os.makedirs(args.output_dir, exist_ok=True)
        private_key_file = os.path.join(args.output_dir, "private_key.txt")
        public_key_file = os.path.join(args.output_dir, "public_key.txt")
        address_file = os.path.join(args.output_dir, "address.txt")
        
        with open(private_key_file, "w") as f:
            f.write(private_key)
        
        with open(public_key_file, "w") as f:
            f.write(public_key_hex)  # Save without 0x prefix
        
        with open(address_file, "w") as f:
            f.write(eth_address)
            
        print(f"\nKeys saved to: {args.output_dir}")

    print("\n=== SET THESE VALUES IN THE CONTRACT ===")
    print(f"Oracle.setPublicKey(\"{public_key_hex}\")")
    # print(f"Oracle.setPublicKeyAddress(\"{eth_address}\")")

    print("\n=== USE THIS ENCRYPTED VALUE IN YOUR CONTRACT ===")
    print(f"Encrypted (base64): {encrypted_b64}")
    print(f"Original value: {url}")
    print("\nYour contract call should set urlEncrypted = true if encrypting a URL")

    # Test decryption to verify it works
    try:
        decrypted = ecies.decrypt(private_key_hex, encrypted)
        decrypted_str = decrypted.decode('utf-8')
        print(f"\nVerification - Decrypted value: {decrypted_str}")
        print("✅ Encryption/decryption test successful!")
    except Exception as e:
        print(f"\n❌ Decryption failed: {str(e)}")
        print("Please check your keys and try again.")

if __name__ == "__main__":
    main() 