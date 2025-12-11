// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {TokenBoundAccount} from "../contracts/account/TokenBoundAccount.sol";
import {ERC6551Registry} from "../contracts/registry/ERC6551Registry.sol";
import {ExampleNFT} from "../contracts/examples/ExampleNFT.sol";
import {IERC6551Account} from "../contracts/interfaces/IERC6551Account.sol";
import {IERC6551Executable} from "../contracts/interfaces/IERC6551Executable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title TokenBoundAccountTest
 * @dev Comprehensive tests for the TokenBoundAccount contract
 */
contract TokenBoundAccountTest is Test {
    ERC6551Registry public registry;
    TokenBoundAccount public implementation;
    ExampleNFT public nft;

    address public owner;
    address public other;
    uint256 public tokenId;
    address public accountAddress;
    TokenBoundAccount public account;

    bytes32 constant SALT = bytes32(0);

    event Executed(address indexed to, uint256 value, bytes data, uint8 operation);

    function setUp() public {
        owner = makeAddr("owner");
        other = makeAddr("other");

        // Deploy contracts
        registry = new ERC6551Registry();
        implementation = new TokenBoundAccount();
        nft = new ExampleNFT("Test NFT", "TNFT", "https://example.com/");

        // Mint an NFT to owner
        vm.prank(owner);
        tokenId = nft.mint(owner);

        // Create a token-bound account
        accountAddress = registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenId
        );

        account = TokenBoundAccount(payable(accountAddress));

        // Fund the owner
        vm.deal(owner, 10 ether);
        vm.deal(other, 10 ether);
    }

    // ============ Token Function Tests ============

    function test_Token_ReturnsCorrectValues() public view {
        (uint256 chainId, address tokenContract, uint256 returnedTokenId) = account.token();

        assertEq(chainId, block.chainid, "Chain ID mismatch");
        assertEq(tokenContract, address(nft), "Token contract mismatch");
        assertEq(returnedTokenId, tokenId, "Token ID mismatch");
    }

    function test_Token_ImmutableAfterCreation() public {
        // Get initial values
        (uint256 chainId1, address tokenContract1, uint256 tokenId1) = account.token();

        // Execute some operations
        vm.prank(owner);
        account.execute{value: 0}(address(0), 0, "", 0);

        // Get values again
        (uint256 chainId2, address tokenContract2, uint256 tokenId2) = account.token();

        // Values should be unchanged
        assertEq(chainId1, chainId2, "Chain ID changed");
        assertEq(tokenContract1, tokenContract2, "Token contract changed");
        assertEq(tokenId1, tokenId2, "Token ID changed");
    }

    // ============ Owner Function Tests ============

    function test_Owner_ReturnsNFTOwner() public view {
        address accountOwner = account.owner();
        assertEq(accountOwner, owner, "Owner mismatch");
    }

    function test_Owner_UpdatesAfterTransfer() public {
        // Verify initial owner
        assertEq(account.owner(), owner, "Initial owner mismatch");

        // Transfer NFT
        vm.prank(owner);
        nft.transferFrom(owner, other, tokenId);

        // Verify new owner
        assertEq(account.owner(), other, "New owner mismatch");
    }

    function test_Owner_ReturnsZeroForDifferentChain() public {
        // Create account on different chain
        vm.chainId(999);

        // Create a new account
        address differentChainAccount = registry.createAccount(
            address(implementation),
            SALT,
            1, // Original chain ID
            address(nft),
            tokenId
        );

        TokenBoundAccount diffAccount = TokenBoundAccount(payable(differentChainAccount));

        // Owner should be zero because we're on different chain
        assertEq(diffAccount.owner(), address(0), "Owner should be zero on different chain");
    }

    // ============ State Function Tests ============

    function test_State_InitiallyZero() public view {
        assertEq(account.state(), 0, "Initial state should be 0");
    }

    function test_State_IncrementsOnExecute() public {
        uint256 initialState = account.state();

        vm.prank(owner);
        account.execute(address(0), 0, "", 0);

        assertEq(account.state(), initialState + 1, "State should increment");
    }

    function test_State_IncrementsOnMultipleExecutes() public {
        vm.startPrank(owner);

        account.execute(address(0), 0, "", 0);
        account.execute(address(0), 0, "", 0);
        account.execute(address(0), 0, "", 0);

        vm.stopPrank();

        assertEq(account.state(), 3, "State should be 3 after 3 executions");
    }

    // ============ isValidSigner Tests ============

    function test_IsValidSigner_ValidOwner() public view {
        bytes4 result = account.isValidSigner(owner, "");
        assertEq(result, IERC6551Account.isValidSigner.selector, "Owner should be valid signer");
    }

    function test_IsValidSigner_InvalidNonOwner() public view {
        bytes4 result = account.isValidSigner(other, "");
        assertEq(result, bytes4(0), "Non-owner should be invalid signer");
    }

    function test_IsValidSigner_InvalidZeroAddress() public view {
        bytes4 result = account.isValidSigner(address(0), "");
        assertEq(result, bytes4(0), "Zero address should be invalid signer");
    }

    function test_IsValidSigner_UpdatesAfterTransfer() public {
        // Initially owner is valid
        assertEq(account.isValidSigner(owner, ""), IERC6551Account.isValidSigner.selector);

        // Transfer NFT
        vm.prank(owner);
        nft.transferFrom(owner, other, tokenId);

        // Now other is valid, owner is invalid
        assertEq(account.isValidSigner(other, ""), IERC6551Account.isValidSigner.selector);
        assertEq(account.isValidSigner(owner, ""), bytes4(0));
    }

    // ============ Execute Tests ============

    function test_Execute_OnlyOwnerCanCall() public {
        vm.prank(other);
        vm.expectRevert(TokenBoundAccount.NotAuthorized.selector);
        account.execute(address(0), 0, "", 0);
    }

    function test_Execute_OwnerCanCall() public {
        vm.prank(owner);
        account.execute(address(0), 0, "", 0);
        // Should not revert
    }

    function test_Execute_CallOperation() public {
        // Send ETH to account
        vm.deal(accountAddress, 1 ether);

        // Execute a call to send ETH
        vm.prank(owner);
        account.execute(other, 0.5 ether, "", 0);

        assertEq(other.balance, 10.5 ether, "ETH transfer failed");
        assertEq(accountAddress.balance, 0.5 ether, "Account balance incorrect");
    }

    function test_Execute_CallWithData() public {
        // Create a mock contract to call
        MockReceiver receiver = new MockReceiver();

        bytes memory data = abi.encodeWithSelector(MockReceiver.receiveCall.selector, 42);

        vm.prank(owner);
        bytes memory result = account.execute(address(receiver), 0, data, 0);

        uint256 returnValue = abi.decode(result, (uint256));
        assertEq(returnValue, 42, "Return value mismatch");
    }

    function test_Execute_DelegateCallOperation() public {
        // Create a mock implementation
        MockDelegate delegate = new MockDelegate();

        bytes memory data = abi.encodeWithSelector(MockDelegate.setValue.selector, 123);

        vm.prank(owner);
        account.execute(address(delegate), 0, data, 1);

        // Note: delegatecall modifies the account's storage, not the delegate's
    }

    function test_Execute_CreateOperation() public {
        // Bytecode for a simple contract that just stores a value
        bytes memory initCode = type(SimpleContract).creationCode;

        vm.prank(owner);
        bytes memory result = account.execute(address(0), 0, initCode, 2);

        address deployed = abi.decode(result, (address));
        assertTrue(deployed != address(0), "Contract not deployed");
        assertTrue(deployed.code.length > 0, "No code at deployed address");
    }

    function test_Execute_Create2Operation() public {
        bytes32 salt = keccak256("test");
        bytes memory initCode = type(SimpleContract).creationCode;
        bytes memory data = abi.encodePacked(salt, initCode);

        vm.prank(owner);
        bytes memory result = account.execute(address(0), 0, data, 3);

        address deployed = abi.decode(result, (address));
        assertTrue(deployed != address(0), "Contract not deployed");
    }

    function test_Execute_UnsupportedOperation() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(TokenBoundAccount.UnsupportedOperation.selector, 4));
        account.execute(address(0), 0, "", 4);
    }

    function test_Execute_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Executed(other, 0, "", 0);
        account.execute(other, 0, "", 0);
    }

    function test_Execute_BubblesUpRevertReason() public {
        MockReverter reverter = new MockReverter();

        bytes memory data = abi.encodeWithSelector(MockReverter.alwaysReverts.selector);

        vm.prank(owner);
        vm.expectRevert("Always reverts");
        account.execute(address(reverter), 0, data, 0);
    }

    // ============ Receive Tests ============

    function test_Receive_AcceptsETH() public {
        vm.prank(owner);
        (bool success, ) = accountAddress.call{value: 1 ether}("");
        assertTrue(success, "ETH transfer failed");
        assertEq(accountAddress.balance, 1 ether, "Balance incorrect");
    }

    // ============ SupportsInterface Tests ============

    function test_SupportsInterface_IERC165() public view {
        assertTrue(account.supportsInterface(type(IERC165).interfaceId));
    }

    function test_SupportsInterface_IERC6551Account() public view {
        // 0x6faff5f1
        assertTrue(account.supportsInterface(type(IERC6551Account).interfaceId));
    }

    function test_SupportsInterface_IERC6551Executable() public view {
        // 0x51945447
        assertTrue(account.supportsInterface(type(IERC6551Executable).interfaceId));
    }

    function test_SupportsInterface_InvalidInterface() public view {
        assertFalse(account.supportsInterface(bytes4(0xdeadbeef)));
    }

    // ============ Authorization After Transfer Tests ============

    function test_Authorization_NewOwnerCanExecute() public {
        // Transfer NFT
        vm.prank(owner);
        nft.transferFrom(owner, other, tokenId);

        // New owner should be able to execute
        vm.prank(other);
        account.execute(address(0), 0, "", 0);
    }

    function test_Authorization_OldOwnerCannotExecute() public {
        // Transfer NFT
        vm.prank(owner);
        nft.transferFrom(owner, other, tokenId);

        // Old owner should not be able to execute
        vm.prank(owner);
        vm.expectRevert(TokenBoundAccount.NotAuthorized.selector);
        account.execute(address(0), 0, "", 0);
    }
}

// ============ Helper Contracts ============

contract MockReceiver {
    function receiveCall(uint256 value) external pure returns (uint256) {
        return value;
    }
}

contract MockDelegate {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}

contract MockReverter {
    function alwaysReverts() external pure {
        revert("Always reverts");
    }
}

contract SimpleContract {
    uint256 public value = 42;
}
