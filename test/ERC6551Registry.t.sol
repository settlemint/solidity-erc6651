// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ERC6551Registry} from "../contracts/registry/ERC6551Registry.sol";
import {TokenBoundAccount} from "../contracts/account/TokenBoundAccount.sol";
import {ERC1271TokenBoundAccount} from "../contracts/account/ERC1271TokenBoundAccount.sol";
import {ExampleNFT} from "../contracts/examples/ExampleNFT.sol";
import {IERC6551Registry} from "../contracts/interfaces/IERC6551Registry.sol";
import {ERC6551BytecodeLib} from "../contracts/lib/ERC6551BytecodeLib.sol";

/**
 * @title ERC6551RegistryTest
 * @dev Comprehensive tests for the ERC6551Registry contract
 */
contract ERC6551RegistryTest is Test {
    ERC6551Registry public registry;
    TokenBoundAccount public implementation;
    ERC1271TokenBoundAccount public erc1271Implementation;
    ExampleNFT public nft;

    address public owner;
    address public other;

    bytes32 constant SALT = bytes32(0);
    bytes32 constant SALT_2 = bytes32(uint256(1));

    event ERC6551AccountCreated(
        address account,
        address indexed implementation,
        bytes32 salt,
        uint256 chainId,
        address indexed tokenContract,
        uint256 indexed tokenId
    );

    function setUp() public {
        owner = makeAddr("owner");
        other = makeAddr("other");

        // Deploy contracts
        registry = new ERC6551Registry();
        implementation = new TokenBoundAccount();
        erc1271Implementation = new ERC1271TokenBoundAccount();
        nft = new ExampleNFT("Test NFT", "TNFT", "https://example.com/");

        // Mint some NFTs
        vm.startPrank(owner);
        nft.mint(owner); // Token 1
        nft.mint(owner); // Token 2
        nft.mint(other); // Token 3
        vm.stopPrank();
    }

    // ============ Account Address Computation Tests ============

    function test_Account_ReturnsDeterministicAddress() public view {
        address addr1 = registry.account(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        address addr2 = registry.account(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        assertEq(addr1, addr2, "Addresses should be deterministic");
    }

    function test_Account_DifferentTokenIdsDifferentAddresses() public view {
        address addr1 = registry.account(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        address addr2 = registry.account(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            2
        );

        assertTrue(addr1 != addr2, "Different token IDs should have different addresses");
    }

    function test_Account_DifferentSaltsDifferentAddresses() public view {
        address addr1 = registry.account(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        address addr2 = registry.account(
            address(implementation),
            SALT_2,
            block.chainid,
            address(nft),
            1
        );

        assertTrue(addr1 != addr2, "Different salts should have different addresses");
    }

    function test_Account_DifferentImplementationsDifferentAddresses() public view {
        address addr1 = registry.account(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        address addr2 = registry.account(
            address(erc1271Implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        assertTrue(addr1 != addr2, "Different implementations should have different addresses");
    }

    function test_Account_DifferentChainIdsDifferentAddresses() public view {
        address addr1 = registry.account(
            address(implementation),
            SALT,
            1,
            address(nft),
            1
        );

        address addr2 = registry.account(
            address(implementation),
            SALT,
            2,
            address(nft),
            1
        );

        assertTrue(addr1 != addr2, "Different chain IDs should have different addresses");
    }

    function test_Account_DifferentTokenContractsDifferentAddresses() public {
        ExampleNFT nft2 = new ExampleNFT("NFT 2", "NFT2", "");

        address addr1 = registry.account(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        address addr2 = registry.account(
            address(implementation),
            SALT,
            block.chainid,
            address(nft2),
            1
        );

        assertTrue(addr1 != addr2, "Different token contracts should have different addresses");
    }

    // ============ Account Creation Tests ============

    function test_CreateAccount_DeploysToComputedAddress() public {
        address computedAddr = registry.account(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        address deployedAddr = registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        assertEq(deployedAddr, computedAddr, "Deployed address should match computed");
    }

    function test_CreateAccount_DeploysCode() public {
        address accountAddr = registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        assertTrue(accountAddr.code.length > 0, "Account should have code");
    }

    function test_CreateAccount_EmitsEvent() public {
        address expectedAddr = registry.account(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        vm.expectEmit(true, true, true, true);
        emit ERC6551AccountCreated(
            expectedAddr,
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );
    }

    function test_CreateAccount_DoesNotRedeployExisting() public {
        // Create account first time
        address addr1 = registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        // Create same account again - should return same address without reverting
        address addr2 = registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        assertEq(addr1, addr2, "Should return same address");
    }

    function test_CreateAccount_AccountHasCorrectTokenInfo() public {
        address accountAddr = registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        TokenBoundAccount account = TokenBoundAccount(payable(accountAddr));
        (uint256 chainId, address tokenContract, uint256 tokenId) = account.token();

        assertEq(chainId, block.chainid, "Chain ID mismatch");
        assertEq(tokenContract, address(nft), "Token contract mismatch");
        assertEq(tokenId, 1, "Token ID mismatch");
    }

    function test_CreateAccount_AccountOwnerIsNFTOwner() public {
        address accountAddr = registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        TokenBoundAccount account = TokenBoundAccount(payable(accountAddr));
        assertEq(account.owner(), owner, "Account owner should be NFT owner");
    }

    function test_CreateAccount_CanCreateMultipleAccountsForSameToken() public {
        address addr1 = registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        address addr2 = registry.createAccount(
            address(implementation),
            SALT_2,
            block.chainid,
            address(nft),
            1
        );

        assertTrue(addr1 != addr2, "Should create different accounts with different salts");
        assertTrue(addr1.code.length > 0, "First account should have code");
        assertTrue(addr2.code.length > 0, "Second account should have code");
    }

    function test_CreateAccount_WorksWithDifferentImplementations() public {
        address addr1 = registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        address addr2 = registry.createAccount(
            address(erc1271Implementation),
            SALT,
            block.chainid,
            address(nft),
            1
        );

        assertTrue(addr1 != addr2, "Different implementations should have different addresses");

        // Both should be functional
        TokenBoundAccount account1 = TokenBoundAccount(payable(addr1));
        ERC1271TokenBoundAccount account2 = ERC1271TokenBoundAccount(payable(addr2));

        assertEq(account1.owner(), owner);
        assertEq(account2.owner(), owner);
    }

    // ============ Fuzz Tests ============

    function testFuzz_Account_Deterministic(
        bytes32 salt,
        uint256 chainId,
        uint256 tokenId
    ) public view {
        address addr1 = registry.account(
            address(implementation),
            salt,
            chainId,
            address(nft),
            tokenId
        );

        address addr2 = registry.account(
            address(implementation),
            salt,
            chainId,
            address(nft),
            tokenId
        );

        assertEq(addr1, addr2, "Addresses should be deterministic");
    }

    function testFuzz_CreateAccount_DeploysToComputedAddress(bytes32 salt) public {
        // Mint a new NFT for each fuzz run
        vm.prank(owner);
        uint256 tokenId = nft.mint(owner);

        address computedAddr = registry.account(
            address(implementation),
            salt,
            block.chainid,
            address(nft),
            tokenId
        );

        address deployedAddr = registry.createAccount(
            address(implementation),
            salt,
            block.chainid,
            address(nft),
            tokenId
        );

        assertEq(deployedAddr, computedAddr, "Deployed address should match computed");
    }

    // ============ Edge Cases ============

    function test_CreateAccount_WithZeroTokenId() public {
        // Some NFTs use token ID 0
        vm.prank(address(nft.owner()));
        nft.mintWithId(owner, 0);

        address accountAddr = registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            0
        );

        TokenBoundAccount account = TokenBoundAccount(payable(accountAddr));
        (, , uint256 tokenId) = account.token();

        assertEq(tokenId, 0, "Token ID should be 0");
    }

    function test_CreateAccount_WithMaxTokenId() public {
        vm.prank(address(nft.owner()));
        nft.mintWithId(owner, type(uint256).max);

        address accountAddr = registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            type(uint256).max
        );

        TokenBoundAccount account = TokenBoundAccount(payable(accountAddr));
        (, , uint256 tokenId) = account.token();

        assertEq(tokenId, type(uint256).max, "Token ID should be max uint256");
    }

    function test_CreateAccount_ForDifferentChain() public {
        // Create account for a token on a different chain
        address accountAddr = registry.createAccount(
            address(implementation),
            SALT,
            999, // Different chain
            address(nft),
            1
        );

        TokenBoundAccount account = TokenBoundAccount(payable(accountAddr));
        (uint256 chainId, , ) = account.token();

        assertEq(chainId, 999, "Chain ID should be 999");
        // Owner should be address(0) since we're not on chain 999
        assertEq(account.owner(), address(0), "Owner should be zero for different chain");
    }
}
