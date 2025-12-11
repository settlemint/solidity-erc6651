// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {TokenBoundAccount} from "./TokenBoundAccount.sol";
import {IERC1271} from "../interfaces/IERC1271.sol";

/**
 * @title ERC1271TokenBoundAccount
 * @dev Extended Token Bound Account with ERC-1271 signature validation
 * @author SettleMint
 * @notice A token-bound account that can validate signatures on behalf of the NFT owner
 *
 * This contract extends TokenBoundAccount with ERC-1271 support, allowing external
 * contracts and protocols to verify that a signature was created by the account's
 * owner (the NFT holder).
 *
 * Use cases:
 * - Gasless transactions (meta-transactions)
 * - Off-chain order signing (NFT marketplaces, DEXs)
 * - Permit-style approvals
 * - Multi-signature schemes
 *
 * @custom:security-contact security@settlemint.com
 */
contract ERC1271TokenBoundAccount is TokenBoundAccount, IERC1271 {
    using ECDSA for bytes32;

    /**
     * @notice The magic value returned when a signature is valid
     * @dev This is the function selector of isValidSignature(bytes32,bytes)
     */
    bytes4 internal constant MAGIC_VALUE = 0x1626ba7e;

    /**
     * @notice The value returned when a signature is invalid
     */
    bytes4 internal constant INVALID_SIGNATURE = 0xffffffff;

    /**
     * @inheritdoc IERC1271
     * @dev Validates a signature by recovering the signer and checking if they are the owner
     *
     * The signature validation process:
     * 1. Recover the signer address from the hash and signature using ECDSA
     * 2. Check if the recovered signer is the current NFT owner
     * 3. Return MAGIC_VALUE (0x1626ba7e) if valid, INVALID_SIGNATURE otherwise
     *
     * Note: This implementation uses raw ECDSA recovery. For EIP-712 typed data,
     * the hash should be the digest of the typed data structure, not the raw data.
     *
     * @param hash The hash of the data that was signed (e.g., EIP-712 digest)
     * @param signature The signature bytes (65 bytes: r, s, v)
     * @return magicValue MAGIC_VALUE if valid, INVALID_SIGNATURE otherwise
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view virtual override returns (bytes4 magicValue) {
        // Get the current owner of the account
        address accountOwner = owner();

        // If owner is address(0), signature is invalid (token on different chain)
        if (accountOwner == address(0)) {
            return INVALID_SIGNATURE;
        }

        // Try to recover the signer from the signature
        // Using tryRecover to handle invalid signatures gracefully
        (address recovered, ECDSA.RecoverError error, ) = ECDSA.tryRecover(hash, signature);

        // Check if recovery was successful and signer matches owner
        if (error == ECDSA.RecoverError.NoError && recovered == accountOwner) {
            return MAGIC_VALUE;
        }

        return INVALID_SIGNATURE;
    }

    /**
     * @inheritdoc TokenBoundAccount
     * @dev Extended to include IERC1271 interface support
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC1271).interfaceId || // 0x1626ba7e
            super.supportsInterface(interfaceId);
    }
}
