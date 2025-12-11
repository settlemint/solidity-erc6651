// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC1271
 * @dev Interface for ERC-1271: Standard Signature Validation Method for Contracts
 * @notice Allows contracts to validate signatures on behalf of the contract
 *
 * ERC-165 Interface ID: 0x1626ba7e (same as the magic value)
 *
 * This standard provides a way for contracts to verify whether a signature
 * was created by an authorized signer. This is essential for smart contract
 * wallets and accounts that need to sign messages or authorize transactions.
 */
interface IERC1271 {
    /**
     * @notice Validates whether the provided signature is valid for the given hash
     * @dev MUST return the magic value (0x1626ba7e) if the signature is valid
     *      MUST NOT modify state (view function)
     *
     *      Implementations should:
     *      - Recover the signer from the hash and signature
     *      - Check if the recovered signer is authorized
     *      - Return the magic value if authorized, any other value otherwise
     *
     * @param hash The hash of the data that was signed
     * @param signature The signature bytes to validate
     * @return magicValue 0x1626ba7e if signature is valid, any other bytes4 value otherwise
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}
