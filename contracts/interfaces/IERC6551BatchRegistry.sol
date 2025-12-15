// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC6551Registry} from "./IERC6551Registry.sol";

/**
 * @title IERC6551BatchRegistry
 * @dev Interface for batch creation of ERC-6551 token-bound accounts
 * @notice Gas-optimized batch operations for creating multiple accounts in a single transaction
 *
 * This interface extends the ERC-6551 ecosystem with batch functionality,
 * enabling significant gas savings when creating accounts for multiple tokens.
 */
interface IERC6551BatchRegistry {
    /**
     * @notice Emitted when a batch of accounts is created
     * @param accounts Array of created account addresses
     * @param implementation The implementation contract used for all accounts
     * @param chainId The chain ID where the tokens exist
     * @param tokenContract The ERC-721 contract address
     * @param newlyCreated Number of accounts that were newly deployed (vs already existed)
     */
    event BatchAccountsCreated(
        address[] accounts,
        address indexed implementation,
        uint256 indexed chainId,
        address indexed tokenContract,
        uint256 newlyCreated
    );

    /**
     * @notice Thrown when batch is empty
     */
    error EmptyBatch();

    /**
     * @notice Thrown when batch exceeds maximum allowed size
     * @param size The requested batch size
     * @param max The maximum allowed batch size
     */
    error BatchTooLarge(uint256 size, uint256 max);

    /**
     * @notice Returns the underlying ERC-6551 registry
     * @return The registry contract
     */
    function registry() external view returns (IERC6551Registry);

    /**
     * @notice Returns the maximum batch size allowed
     * @return The maximum number of accounts per batch
     */
    function MAX_BATCH_SIZE() external view returns (uint256);

    /**
     * @notice Creates multiple token-bound accounts in a single transaction
     * @dev Uses uniform parameters (same implementation, salt, chainId, tokenContract)
     *      for all accounts. Only the tokenId varies per account.
     *
     *      If an account already exists, returns the existing address without reverting.
     *      The returned array maintains the same order as the input tokenIds.
     *
     * @param implementation The address of the account implementation contract
     * @param salt Salt value for CREATE2 (same for all accounts)
     * @param chainId The EIP-155 chain ID where the tokens exist
     * @param tokenContract The address of the ERC-721 token contract
     * @param tokenIds Array of token IDs to create accounts for
     * @return accounts Array of created/existing account addresses
     */
    function batchCreateAccounts(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256[] calldata tokenIds
    ) external returns (address[] memory accounts);

    /**
     * @notice Computes addresses for multiple accounts without deploying
     * @dev This is a view function that returns predicted addresses and existence status.
     *      Useful for gas estimation and checking which accounts already exist.
     *
     * @param implementation The address of the account implementation contract
     * @param salt Salt value for CREATE2 computation
     * @param chainId The EIP-155 chain ID where the tokens exist
     * @param tokenContract The address of the ERC-721 token contract
     * @param tokenIds Array of token IDs to compute addresses for
     * @return accounts Array of computed account addresses
     * @return exists Array indicating whether each account already exists
     */
    function batchComputeAddresses(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256[] calldata tokenIds
    ) external view returns (address[] memory accounts, bool[] memory exists);
}
