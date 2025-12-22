// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ERC6551BytecodeLib
 * @dev Library for generating ERC-6551 token-bound account bytecode
 * @notice Provides utilities for creating minimal proxy bytecode with appended context data
 *
 * The bytecode structure follows EIP-1167 minimal proxy pattern with additional
 * immutable data appended after the proxy bytecode:
 *
 * [EIP-1167 Creation Code (10 bytes)]
 * [EIP-1167 Runtime Code (45 bytes)] = [Header (10 bytes)][Implementation (20 bytes)][Footer (15 bytes)]
 * [Salt (32 bytes)]
 * [Chain ID (32 bytes)]
 * [Token Contract (32 bytes)]
 * [Token ID (32 bytes)]
 *
 * Total: 10 + 45 + 128 = 183 bytes (0xB7)
 */
library ERC6551BytecodeLib {
    /**
     * @notice Generates the creation code for a token-bound account
     * @dev The creation code deploys an EIP-1167 minimal proxy with appended context data
     *
     * Bytecode breakdown:
     * - 0x3d60ad80600a3d3981f3: Creation code that copies runtime code to memory and returns it
     * - 0x363d3d373d3d3d363d73: EIP-1167 proxy header
     * - [implementation]: 20-byte implementation address
     * - 0x5af43d82803e903d91602b57fd5bf3: EIP-1167 proxy footer
     * - [salt]: 32-byte salt
     * - [chainId]: 32-byte chain ID
     * - [tokenContract]: 32-byte token contract address (left-padded)
     * - [tokenId]: 32-byte token ID
     *
     * @param implementation The address of the account implementation contract
     * @param salt The salt value for CREATE2
     * @param chainId The chain ID where the token exists
     * @param tokenContract The token contract address
     * @param tokenId The token ID
     * @return code The complete creation bytecode
     */
    function getCreationCode(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal pure returns (bytes memory code) {
        // EIP-1167 creation code prefix (deploys the proxy)
        // 3d60ad80600a3d3981f3 = RETURNDATASIZE PUSH1 0xAD DUP1 PUSH1 0x0A RETURNDATASIZE CODECOPY DUP2 RETURN
        // This copies 0xAD (173) bytes starting from offset 0x0A to memory and returns them

        // EIP-1167 runtime code:
        // 363d3d373d3d3d363d73 = CALLDATASIZE RETURNDATASIZE RETURNDATASIZE CALLDATACOPY RETURNDATASIZE RETURNDATASIZE RETURNDATASIZE CALLDATASIZE RETURNDATASIZE PUSH20
        // [implementation address - 20 bytes]
        // 5af43d82803e903d91602b57fd5bf3 = GAS DELEGATECALL RETURNDATASIZE DUP3 DUP1 RETURNDATACOPY SWAP1 RETURNDATASIZE SWAP2 PUSH1 0x2B JUMPI REVERT JUMPDEST RETURN

        code = abi.encodePacked(
            // Creation code (10 bytes)
            hex"3d60ad80600a3d3981f3",
            // Runtime code - EIP-1167 proxy header (10 bytes)
            hex"363d3d373d3d3d363d73",
            // Implementation address (20 bytes)
            implementation,
            // Runtime code - EIP-1167 proxy footer (15 bytes)
            hex"5af43d82803e903d91602b57fd5bf3",
            // Appended immutable data (128 bytes total)
            salt,                                    // 32 bytes
            chainId,                                 // 32 bytes
            uint256(uint160(tokenContract)),         // 32 bytes (address left-padded)
            tokenId                                  // 32 bytes
        );
    }

    /**
     * @notice Computes the deterministic address for a token-bound account
     * @dev Uses CREATE2 address computation formula:
     *      address = keccak256(0xff ++ deployingAddress ++ salt ++ keccak256(bytecode))[12:]
     *
     * @param registry The address of the registry deploying the account
     * @param implementation The address of the account implementation
     * @param salt The salt value
     * @param chainId The chain ID where the token exists
     * @param tokenContract The token contract address
     * @param tokenId The token ID
     * @return The computed account address
     */
    function computeAddress(
        address registry,
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal pure returns (address) {
        bytes memory code = getCreationCode(implementation, salt, chainId, tokenContract, tokenId);
        bytes32 bytecodeHash = keccak256(code);

        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            registry,
                            salt,
                            bytecodeHash
                        )
                    )
                )
            )
        );
    }
}
