// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC6551Account
 * @dev Interface for ERC-6551 Token Bound Accounts
 * @notice This interface defines the core functionality for token-bound accounts
 *
 * ERC-165 Interface ID: 0x6faff5f1
 *
 * Token bound accounts are smart contract accounts owned by a single ERC-721 token.
 * The account is bound to the token and moves with it when transferred.
 */
interface IERC6551Account {
    /**
     * @notice Allows the account to receive native tokens (ETH)
     * @dev Accounts MUST implement a receive function to accept native token transfers
     */
    receive() external payable;

    /**
     * @notice Returns the identifier of the ERC-721 token that owns this account
     * @dev This value MUST be constant and MUST NOT change over the lifetime of the account
     * @return chainId The EIP-155 chain ID of the chain the token exists on
     * @return tokenContract The address of the ERC-721 token contract
     * @return tokenId The ID of the ERC-721 token that owns this account
     */
    function token() external view returns (uint256 chainId, address tokenContract, uint256 tokenId);

    /**
     * @notice Returns a value that changes each time the account state changes
     * @dev This value SHOULD be modified each time the account changes state
     *      This allows external contracts to verify that account state has not changed
     *      between calls by checking if state() returns the same value
     * @return The current account state value
     */
    function state() external view returns (uint256);

    /**
     * @notice Validates whether a given signer is authorized to act on behalf of the account
     * @dev The holder of the ERC-721 token that owns this account MUST be considered a valid signer
     *      Accounts MAY implement additional authorization logic
     * @param signer The address to validate as a signer
     * @param context Additional data used to determine validity of the signer
     * @return magicValue 0x523e3260 if the signer is valid, any other value otherwise
     */
    function isValidSigner(address signer, bytes calldata context) external view returns (bytes4 magicValue);
}
