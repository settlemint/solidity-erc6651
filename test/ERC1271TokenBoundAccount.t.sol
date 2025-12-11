// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ERC1271TokenBoundAccount} from "../contracts/account/ERC1271TokenBoundAccount.sol";
import {ERC6551Registry} from "../contracts/registry/ERC6551Registry.sol";
import {ExampleNFT} from "../contracts/examples/ExampleNFT.sol";
import {IERC1271} from "../contracts/interfaces/IERC1271.sol";
import {IERC6551Account} from "../contracts/interfaces/IERC6551Account.sol";
import {IERC6551Executable} from "../contracts/interfaces/IERC6551Executable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title ERC1271TokenBoundAccountTest
 * @dev Comprehensive tests for the ERC1271TokenBoundAccount contract
 */
contract ERC1271TokenBoundAccountTest is Test {
    ERC6551Registry public registry;
    ERC1271TokenBoundAccount public implementation;
    ExampleNFT public nft;

    address public owner;
    address public other;
    uint256 public ownerPrivateKey;
    uint256 public otherPrivateKey;
    uint256 public tokenId;
    address public accountAddress;
    ERC1271TokenBoundAccount public account;

    bytes32 constant SALT = bytes32(0);
    bytes4 constant MAGIC_VALUE = 0x1626ba7e;
    bytes4 constant INVALID_SIGNATURE = 0xffffffff;

    function setUp() public {
        // Create accounts with known private keys for signing
        ownerPrivateKey = 0xA11CE;
        otherPrivateKey = 0xB0B;
        owner = vm.addr(ownerPrivateKey);
        other = vm.addr(otherPrivateKey);

        // Deploy contracts
        registry = new ERC6551Registry();
        implementation = new ERC1271TokenBoundAccount();
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

        account = ERC1271TokenBoundAccount(payable(accountAddress));

        // Fund accounts
        vm.deal(owner, 10 ether);
        vm.deal(other, 10 ether);
    }

    // ============ Interface Support Tests ============

    function test_SupportsInterface_IERC1271() public view {
        assertTrue(account.supportsInterface(type(IERC1271).interfaceId));
    }

    function test_SupportsInterface_IERC6551Account() public view {
        assertTrue(account.supportsInterface(type(IERC6551Account).interfaceId));
    }

    function test_SupportsInterface_IERC6551Executable() public view {
        assertTrue(account.supportsInterface(type(IERC6551Executable).interfaceId));
    }

    function test_SupportsInterface_IERC165() public view {
        assertTrue(account.supportsInterface(type(IERC165).interfaceId));
    }

    // ============ Signature Validation Tests ============

    function test_IsValidSignature_ValidOwnerSignature() public view {
        bytes32 hash = keccak256("test message");

        // Sign the hash with owner's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = account.isValidSignature(hash, signature);
        assertEq(result, MAGIC_VALUE, "Valid signature should return magic value");
    }

    function test_IsValidSignature_InvalidNonOwnerSignature() public view {
        bytes32 hash = keccak256("test message");

        // Sign the hash with other's private key (not the owner)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(otherPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = account.isValidSignature(hash, signature);
        assertEq(result, INVALID_SIGNATURE, "Non-owner signature should return invalid");
    }

    function test_IsValidSignature_WrongHash() public view {
        bytes32 hash = keccak256("test message");
        bytes32 wrongHash = keccak256("wrong message");

        // Sign the correct hash with owner's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify against wrong hash
        bytes4 result = account.isValidSignature(wrongHash, signature);
        assertEq(result, INVALID_SIGNATURE, "Wrong hash should return invalid");
    }

    function test_IsValidSignature_MalformedSignature() public view {
        bytes32 hash = keccak256("test message");

        // Create a malformed signature (wrong length)
        bytes memory signature = hex"0123456789";

        bytes4 result = account.isValidSignature(hash, signature);
        assertEq(result, INVALID_SIGNATURE, "Malformed signature should return invalid");
    }

    function test_IsValidSignature_EmptySignature() public view {
        bytes32 hash = keccak256("test message");
        bytes memory signature = "";

        bytes4 result = account.isValidSignature(hash, signature);
        assertEq(result, INVALID_SIGNATURE, "Empty signature should return invalid");
    }

    // ============ Signature Validation After Transfer Tests ============

    function test_IsValidSignature_OldOwnerInvalidAfterTransfer() public {
        bytes32 hash = keccak256("test message");

        // Owner signs before transfer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify signature is valid before transfer
        assertEq(account.isValidSignature(hash, signature), MAGIC_VALUE);

        // Transfer NFT to other
        vm.prank(owner);
        nft.transferFrom(owner, other, tokenId);

        // Old owner's signature should now be invalid
        assertEq(account.isValidSignature(hash, signature), INVALID_SIGNATURE);
    }

    function test_IsValidSignature_NewOwnerValidAfterTransfer() public {
        bytes32 hash = keccak256("test message");

        // Transfer NFT to other
        vm.prank(owner);
        nft.transferFrom(owner, other, tokenId);

        // New owner signs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(otherPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // New owner's signature should be valid
        assertEq(account.isValidSignature(hash, signature), MAGIC_VALUE);
    }

    // ============ Different Chain Tests ============

    function test_IsValidSignature_InvalidOnDifferentChain() public {
        // Create account for different chain
        address diffChainAccountAddr = registry.createAccount(
            address(implementation),
            SALT,
            999, // Different chain
            address(nft),
            tokenId
        );

        ERC1271TokenBoundAccount diffChainAccount = ERC1271TokenBoundAccount(payable(diffChainAccountAddr));

        bytes32 hash = keccak256("test message");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should be invalid because owner() returns address(0) on different chain
        bytes4 result = diffChainAccount.isValidSignature(hash, signature);
        assertEq(result, INVALID_SIGNATURE, "Signature should be invalid on different chain");
    }

    // ============ EIP-712 Style Signing Tests ============

    function test_IsValidSignature_WithEthSignedMessageHash() public view {
        // Simulate signing with personal_sign (EIP-191)
        bytes32 messageHash = keccak256("test message");
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // The contract verifies against the provided hash directly
        // So we need to pass the eth signed hash
        bytes4 result = account.isValidSignature(ethSignedHash, signature);
        assertEq(result, MAGIC_VALUE, "ETH signed message hash should be valid");
    }

    // ============ Inherited Functionality Tests ============

    function test_Token_ReturnsCorrectValues() public view {
        (uint256 chainId, address tokenContract, uint256 returnedTokenId) = account.token();

        assertEq(chainId, block.chainid);
        assertEq(tokenContract, address(nft));
        assertEq(returnedTokenId, tokenId);
    }

    function test_Owner_ReturnsNFTOwner() public view {
        assertEq(account.owner(), owner);
    }

    function test_Execute_WorksForOwner() public {
        vm.deal(accountAddress, 1 ether);

        vm.prank(owner);
        account.execute(other, 0.5 ether, "", 0);

        assertEq(other.balance, 10.5 ether);
    }

    function test_Execute_RevertsForNonOwner() public {
        vm.prank(other);
        vm.expectRevert();
        account.execute(address(0), 0, "", 0);
    }

    function test_State_IncrementsOnExecute() public {
        uint256 initialState = account.state();

        vm.prank(owner);
        account.execute(address(0), 0, "", 0);

        assertEq(account.state(), initialState + 1);
    }

    // ============ Fuzz Tests ============

    function testFuzz_IsValidSignature_RandomHashes(bytes32 hash) public view {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = account.isValidSignature(hash, signature);
        assertEq(result, MAGIC_VALUE, "Owner signature should always be valid");
    }

    function testFuzz_IsValidSignature_InvalidSignerAlwaysFails(
        bytes32 hash,
        uint256 randomPrivateKey
    ) public view {
        // Ensure the random key is not the owner's key and is valid
        vm.assume(randomPrivateKey != ownerPrivateKey);
        vm.assume(randomPrivateKey > 0);
        vm.assume(randomPrivateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(randomPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = account.isValidSignature(hash, signature);
        assertEq(result, INVALID_SIGNATURE, "Non-owner signature should always fail");
    }

    // ============ Integration Tests ============

    function test_Integration_SignAndExecute() public {
        // This test simulates a real-world scenario where:
        // 1. An off-chain signature is created
        // 2. A relayer or contract verifies the signature
        // 3. An action is executed

        bytes32 actionHash = keccak256(abi.encode("transfer", other, 1 ether));

        // Owner signs the action
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, actionHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify signature is valid
        assertEq(account.isValidSignature(actionHash, signature), MAGIC_VALUE);

        // Execute the action (in a real scenario, this would be done by a relayer)
        vm.deal(accountAddress, 2 ether);
        vm.prank(owner);
        account.execute(other, 1 ether, "", 0);

        assertEq(other.balance, 11 ether);
    }
}
