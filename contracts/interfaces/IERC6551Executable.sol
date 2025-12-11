// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC6551Executable
 * @dev Interface for ERC-6551 account execution functionality
 * @notice This interface defines execution capabilities for token-bound accounts
 *
 * ERC-165 Interface ID: 0x51945447
 *
 * Accounts implementing this interface can execute arbitrary operations
 * on behalf of the ERC-721 token owner.
 */
interface IERC6551Executable {
    /**
     * @notice Executes a low-level operation if the caller is a valid signer
     * @dev Accounts MUST support the following operation types:
     *      - 0 = CALL: Standard external call
     *      - 1 = DELEGATECALL: Delegate call (use with caution)
     *      - 2 = CREATE: Deploy a new contract
     *      - 3 = CREATE2: Deploy a new contract with CREATE2
     *
     *      Accounts MAY support additional operations or restrict certain operations
     *      Accounts MAY restrict certain signers from executing certain operations
     *
     * @param to The target address for the operation (ignored for CREATE/CREATE2)
     * @param value The native token value to send with the operation
     * @param data The calldata for the operation (or init code for CREATE/CREATE2)
     * @param operation The type of operation to perform:
     *                  0 = CALL, 1 = DELEGATECALL, 2 = CREATE, 3 = CREATE2
     * @return result The result of the operation
     *
     * @custom:reverts if the operation fails
     * @custom:reverts if the caller is not a valid signer
     */
    function execute(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external payable returns (bytes memory result);
}
