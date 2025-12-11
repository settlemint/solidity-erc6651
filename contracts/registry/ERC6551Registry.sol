// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC6551Registry} from "../interfaces/IERC6551Registry.sol";
import {ERC6551BytecodeLib} from "../lib/ERC6551BytecodeLib.sol";

/**
 * @title ERC6551Registry
 * @dev Registry for creating and managing ERC-6551 token-bound accounts
 * @author SettleMint
 * @notice Creates deterministic token-bound accounts using CREATE2
 *
 * This registry deploys minimal proxy contracts (EIP-1167) that delegate
 * to an implementation contract. Each account is uniquely identified by:
 * - Implementation address
 * - Salt value
 * - Chain ID
 * - Token contract address
 * - Token ID
 *
 * @custom:security-contact security@settlemint.com
 */
contract ERC6551Registry is IERC6551Registry {
    /**
     * @inheritdoc IERC6551Registry
     */
    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address accountAddress) {
        // Get the creation bytecode
        bytes memory code = ERC6551BytecodeLib.getCreationCode(
            implementation,
            salt,
            chainId,
            tokenContract,
            tokenId
        );

        // Compute the expected address
        accountAddress = ERC6551BytecodeLib.computeAddress(
            address(this),
            implementation,
            salt,
            chainId,
            tokenContract,
            tokenId
        );

        // If account already exists, return existing address
        if (accountAddress.code.length > 0) {
            return accountAddress;
        }

        // Deploy the account using CREATE2
        assembly {
            accountAddress := create2(0, add(code, 0x20), mload(code), salt)
        }

        // Verify deployment succeeded
        if (accountAddress == address(0)) {
            revert AccountCreationFailed();
        }

        // Emit the creation event
        emit ERC6551AccountCreated(
            accountAddress,
            implementation,
            salt,
            chainId,
            tokenContract,
            tokenId
        );
    }

    /**
     * @inheritdoc IERC6551Registry
     */
    function account(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external view returns (address) {
        return ERC6551BytecodeLib.computeAddress(
            address(this),
            implementation,
            salt,
            chainId,
            tokenContract,
            tokenId
        );
    }
}
