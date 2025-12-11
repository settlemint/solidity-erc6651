// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC6551Registry
 * @dev Interface for the ERC-6551 Account Registry
 * @notice Registry for creating and querying token-bound account addresses
 *
 * The registry uses CREATE2 to deploy minimal proxy contracts that delegate
 * to an implementation contract. Each account is uniquely determined by:
 * - The implementation address
 * - A salt value
 * - The chain ID where the token exists
 * - The token contract address
 * - The token ID
 */
interface IERC6551Registry {
    /**
     * @notice Emitted when a new token-bound account is created
     * @param account The address of the created account
     * @param implementation The address of the implementation contract
     * @param salt The salt used for CREATE2 deployment
     * @param chainId The chain ID where the token exists
     * @param tokenContract The address of the ERC-721 token contract
     * @param tokenId The ID of the ERC-721 token
     */
    event ERC6551AccountCreated(
        address account,
        address indexed implementation,
        bytes32 salt,
        uint256 chainId,
        address indexed tokenContract,
        uint256 indexed tokenId
    );

    /**
     * @notice Thrown when CREATE2 deployment fails
     */
    error AccountCreationFailed();

    /**
     * @notice Creates a token-bound account for an ERC-721 token
     * @dev If the account already exists, returns the existing account address
     *      without reverting. The account is deployed as a minimal proxy (EIP-1167)
     *      pointing to the implementation contract.
     *
     *      The account address is deterministic and can be computed ahead of time
     *      using the account() function.
     *
     * @param implementation The address of the implementation contract
     * @param salt A salt value for CREATE2 (allows multiple accounts per token)
     * @param chainId The EIP-155 chain ID where the token exists
     * @param tokenContract The address of the ERC-721 token contract
     * @param tokenId The ID of the ERC-721 token
     * @return account The address of the created (or existing) account
     */
    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address account);

    /**
     * @notice Computes the address of a token-bound account
     * @dev This function returns the same address regardless of whether
     *      the account has been created or not. The address is deterministic
     *      based on the input parameters.
     *
     * @param implementation The address of the implementation contract
     * @param salt A salt value for the CREATE2 computation
     * @param chainId The EIP-155 chain ID where the token exists
     * @param tokenContract The address of the ERC-721 token contract
     * @param tokenId The ID of the ERC-721 token
     * @return account The computed account address
     */
    function account(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external view returns (address account);
}
