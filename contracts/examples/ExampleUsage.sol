// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC6551Registry} from "../interfaces/IERC6551Registry.sol";
import {IERC6551Account} from "../interfaces/IERC6551Account.sol";
import {IERC6551Executable} from "../interfaces/IERC6551Executable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title ExampleUsage
 * @dev Demonstrates how to interact with ERC-6551 token-bound accounts
 * @author SettleMint
 * @notice Example contract showing common usage patterns
 *
 * This contract demonstrates:
 * - Computing account addresses before deployment
 * - Creating token-bound accounts
 * - Executing transactions through accounts
 * - Checking account state
 *
 * @custom:security-contact security@settlemint.com
 */
contract ExampleUsage {
    /**
     * @notice The ERC-6551 registry contract
     */
    IERC6551Registry public immutable registry;

    /**
     * @notice The token-bound account implementation
     */
    address public immutable accountImplementation;

    /**
     * @notice Emitted when a token-bound account is created through this contract
     */
    event AccountCreatedForToken(
        address indexed tokenContract,
        uint256 indexed tokenId,
        address indexed account
    );

    /**
     * @notice Emitted when a transaction is executed through a token-bound account
     */
    event TransactionExecuted(
        address indexed account,
        address indexed target,
        uint256 value,
        bytes data
    );

    /**
     * @notice Creates a new ExampleUsage contract
     * @param _registry The address of the ERC-6551 registry
     * @param _implementation The address of the account implementation
     */
    constructor(address _registry, address _implementation) {
        registry = IERC6551Registry(_registry);
        accountImplementation = _implementation;
    }

    /**
     * @notice Computes the address of a token-bound account without deploying
     * @dev Useful for determining the account address before creation
     * @param tokenContract The ERC-721 token contract address
     * @param tokenId The token ID
     * @param salt Optional salt for multiple accounts per token
     * @return account The computed account address
     */
    function getAccountAddress(
        address tokenContract,
        uint256 tokenId,
        bytes32 salt
    ) external view returns (address account) {
        return registry.account(
            accountImplementation,
            salt,
            block.chainid,
            tokenContract,
            tokenId
        );
    }

    /**
     * @notice Creates a token-bound account for an ERC-721 token
     * @dev The caller must own the token or be approved
     * @param tokenContract The ERC-721 token contract address
     * @param tokenId The token ID to bind the account to
     * @param salt Optional salt for multiple accounts per token
     * @return account The address of the created account
     */
    function createAccountForToken(
        address tokenContract,
        uint256 tokenId,
        bytes32 salt
    ) external returns (address account) {
        // Create the account
        account = registry.createAccount(
            accountImplementation,
            salt,
            block.chainid,
            tokenContract,
            tokenId
        );

        emit AccountCreatedForToken(tokenContract, tokenId, account);
    }

    /**
     * @notice Executes a transaction through a token-bound account
     * @dev Caller must be the owner of the token that controls the account
     * @param account The token-bound account address
     * @param target The target address for the transaction
     * @param value The ETH value to send
     * @param data The calldata for the transaction
     * @return result The return data from the transaction
     */
    function executeViaAccount(
        address account,
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory result) {
        // Execute the transaction (will revert if caller is not the owner)
        result = IERC6551Executable(account).execute(target, value, data, 0);

        emit TransactionExecuted(account, target, value, data);
    }

    /**
     * @notice Checks if an account exists (has been deployed)
     * @param tokenContract The ERC-721 token contract address
     * @param tokenId The token ID
     * @param salt The salt used for the account
     * @return exists True if the account has been deployed
     */
    function accountExists(
        address tokenContract,
        uint256 tokenId,
        bytes32 salt
    ) external view returns (bool exists) {
        address account = registry.account(
            accountImplementation,
            salt,
            block.chainid,
            tokenContract,
            tokenId
        );

        return account.code.length > 0;
    }

    /**
     * @notice Gets the owner of a token-bound account
     * @dev Returns address(0) if the account doesn't exist or token is on different chain
     * @param account The token-bound account address
     * @return owner The current owner of the account
     */
    function getAccountOwner(address account) external view returns (address owner) {
        // Check if account exists
        if (account.code.length == 0) {
            return address(0);
        }

        // Get token info and lookup owner
        (uint256 chainId, address tokenContract, uint256 tokenId) = IERC6551Account(account).token();

        if (chainId != block.chainid) {
            return address(0);
        }

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    /**
     * @notice Gets the state of a token-bound account
     * @dev Used to detect if account state has changed
     * @param account The token-bound account address
     * @return state The current state value
     */
    function getAccountState(address account) external view returns (uint256 state) {
        if (account.code.length == 0) {
            return 0;
        }

        return IERC6551Account(account).state();
    }

    /**
     * @notice Batch creates accounts for multiple tokens
     * @param tokenContract The ERC-721 token contract address
     * @param tokenIds Array of token IDs
     * @param salt Salt value (same for all accounts)
     * @return accounts Array of created account addresses
     */
    function batchCreateAccounts(
        address tokenContract,
        uint256[] calldata tokenIds,
        bytes32 salt
    ) external returns (address[] memory accounts) {
        accounts = new address[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            accounts[i] = registry.createAccount(
                accountImplementation,
                salt,
                block.chainid,
                tokenContract,
                tokenIds[i]
            );

            emit AccountCreatedForToken(tokenContract, tokenIds[i], accounts[i]);
        }
    }
}
