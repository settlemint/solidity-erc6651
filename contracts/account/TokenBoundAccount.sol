// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC6551Account} from "../interfaces/IERC6551Account.sol";
import {IERC6551Executable} from "../interfaces/IERC6551Executable.sol";

/**
 * @title TokenBoundAccount
 * @dev Implementation of ERC-6551 Token Bound Account
 * @author SettleMint
 * @notice A smart contract account owned by a single ERC-721 token
 *
 * This contract implements both IERC6551Account and IERC6551Executable interfaces,
 * allowing the NFT owner to execute arbitrary transactions through this account.
 *
 * Key features:
 * - Immutable binding to an ERC-721 token (data stored in bytecode)
 * - Execution of CALL, DELEGATECALL, CREATE, and CREATE2 operations
 * - State tracking for change detection
 * - ERC-165 interface detection
 *
 * @custom:security-contact security@settlemint.com
 */
contract TokenBoundAccount is IERC6551Account, IERC6551Executable, IERC165 {
    /**
     * @notice The current state of the account, incremented on each state change
     * @dev Used by external contracts to detect if account state has changed
     */
    uint256 private _state;

    /**
     * @notice Emitted when an operation is executed through this account
     * @param to The target address of the operation
     * @param value The ETH value sent with the operation
     * @param data The calldata of the operation
     * @param operation The type of operation (0=CALL, 1=DELEGATECALL, 2=CREATE, 3=CREATE2)
     */
    event Executed(address indexed to, uint256 value, bytes data, uint8 operation);

    /**
     * @notice Thrown when a non-owner tries to execute an operation
     */
    error NotAuthorized();

    /**
     * @notice Thrown when an unsupported operation type is requested
     * @param operation The unsupported operation type
     */
    error UnsupportedOperation(uint8 operation);

    /**
     * @notice Thrown when an operation execution fails
     */
    error ExecutionFailed();

    /**
     * @notice Allows the account to receive native tokens (ETH)
     */
    receive() external payable override {}

    /**
     * @inheritdoc IERC6551Account
     * @dev Reads the token information from the bytecode appended during deployment
     *      The data is stored at a fixed offset in the deployed bytecode:
     *      - Offset 0x2d (45 bytes from start): Start of appended data (salt)
     *      - Offset 0x4d (77 bytes from start): Start of chainId
     *      - Layout: [salt (32)][chainId (32)][tokenContract (32)][tokenId (32)]
     *      We skip salt and read chainId, tokenContract, tokenId (96 bytes starting at 0x4d)
     */
    function token() public view virtual override returns (uint256 chainId, address tokenContract, uint256 tokenId) {
        bytes memory data = new bytes(96);

        assembly {
            // Copy 96 bytes from bytecode offset 0x4d (start of chainId) to memory
            // Runtime bytecode layout:
            // 0x00 - 0x09: EIP-1167 header (10 bytes)
            // 0x0a - 0x1d: implementation address (20 bytes)
            // 0x1e - 0x2c: EIP-1167 footer (15 bytes)
            // 0x2d - 0x4c: salt (32 bytes)
            // 0x4d - 0x6c: chainId (32 bytes) <-- start reading here
            // 0x6d - 0x8c: tokenContract (32 bytes)
            // 0x8d - 0xac: tokenId (32 bytes)
            extcodecopy(address(), add(data, 0x20), 0x4d, 0x60)
        }

        // Decode the packed data
        (chainId, tokenContract, tokenId) = abi.decode(data, (uint256, address, uint256));
    }

    /**
     * @inheritdoc IERC6551Account
     */
    function state() external view virtual override returns (uint256) {
        return _state;
    }

    /**
     * @inheritdoc IERC6551Account
     * @dev Returns the magic value if the signer is the current owner of the bound NFT
     *      and the NFT is on the current chain
     */
    function isValidSigner(address signer, bytes calldata) external view virtual override returns (bytes4) {
        if (_isValidSigner(signer)) {
            return IERC6551Account.isValidSigner.selector; // 0x523e3260
        }
        return bytes4(0);
    }

    /**
     * @inheritdoc IERC6551Executable
     * @dev Executes operations on behalf of the NFT owner
     *      Supported operations:
     *      - 0 (CALL): Standard external call
     *      - 1 (DELEGATECALL): Delegate call (preserves context)
     *      - 2 (CREATE): Deploy new contract
     *      - 3 (CREATE2): Deploy new contract with salt
     */
    function execute(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external payable virtual override returns (bytes memory result) {
        if (!_isValidSigner(msg.sender)) {
            revert NotAuthorized();
        }

        // Increment state to indicate a change
        unchecked {
            ++_state;
        }

        bool success;

        if (operation == 0) {
            // CALL
            (success, result) = to.call{value: value}(data);
        } else if (operation == 1) {
            // DELEGATECALL
            (success, result) = to.delegatecall(data);
        } else if (operation == 2) {
            // CREATE
            // Copy calldata to memory for assembly access
            bytes memory initCode = data;
            address deployed;
            assembly {
                deployed := create(value, add(initCode, 0x20), mload(initCode))
            }
            success = deployed != address(0);
            result = abi.encode(deployed);
        } else if (operation == 3) {
            // CREATE2
            // First 32 bytes of data is the salt, rest is init code
            bytes32 salt;
            bytes memory initCode;

            if (data.length >= 32) {
                salt = bytes32(data[:32]);
                initCode = data[32:];
            } else {
                revert ExecutionFailed();
            }

            address deployed;
            assembly {
                deployed := create2(value, add(initCode, 0x20), mload(initCode), salt)
            }
            success = deployed != address(0);
            result = abi.encode(deployed);
        } else {
            revert UnsupportedOperation(operation);
        }

        if (!success) {
            // Bubble up the revert reason if available
            assembly {
                revert(add(result, 0x20), mload(result))
            }
        }

        emit Executed(to, value, data, operation);
    }

    /**
     * @notice Returns the current owner of this account
     * @dev The owner is the current holder of the bound ERC-721 token
     *      Returns address(0) if the token is on a different chain
     * @return The address of the account owner, or address(0) if not on this chain
     */
    function owner() public view virtual returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token();

        if (chainId != block.chainid) {
            return address(0);
        }

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId || // 0x01ffc9a7
            interfaceId == type(IERC6551Account).interfaceId || // 0x6faff5f1
            interfaceId == type(IERC6551Executable).interfaceId; // 0x51945447
    }

    /**
     * @notice Internal function to check if an address is a valid signer
     * @dev A signer is valid if they are the current owner of the bound NFT
     *      and the NFT is on the current chain
     * @param signer The address to check
     * @return True if the signer is valid, false otherwise
     */
    function _isValidSigner(address signer) internal view virtual returns (bool) {
        return signer == owner() && signer != address(0);
    }
}
