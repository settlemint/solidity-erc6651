// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {ERC6551Registry} from "../contracts/registry/ERC6551Registry.sol";
import {ERC6551BatchRegistry} from "../contracts/registry/ERC6551BatchRegistry.sol";
import {TokenBoundAccount} from "../contracts/account/TokenBoundAccount.sol";
import {ExampleNFT} from "../contracts/examples/ExampleNFT.sol";
import {IERC6551BatchRegistry} from "../contracts/interfaces/IERC6551BatchRegistry.sol";

/**
 * @title ERC6551BatchRegistryTest
 * @dev Comprehensive tests for the ERC6551BatchRegistry contract
 */
contract ERC6551BatchRegistryTest is Test {
    ERC6551Registry public registry;
    ERC6551BatchRegistry public batchRegistry;
    TokenBoundAccount public implementation;
    ExampleNFT public nft;

    address public owner;
    address public other;

    bytes32 constant SALT = bytes32(0);
    bytes32 constant SALT_2 = bytes32(uint256(1));

    event BatchAccountsCreated(
        address[] accounts,
        address indexed implementation,
        uint256 indexed chainId,
        address indexed tokenContract,
        uint256 newlyCreated
    );

    function setUp() public {
        owner = makeAddr("owner");
        other = makeAddr("other");

        // Deploy contracts
        registry = new ERC6551Registry();
        batchRegistry = new ERC6551BatchRegistry(address(registry));
        implementation = new TokenBoundAccount();
        nft = new ExampleNFT("Test NFT", "TNFT", "https://example.com/");

        // Mint NFTs for testing (tokens 1-110 to test batch limits)
        vm.startPrank(owner);
        for (uint256 i = 1; i <= 110; i++) {
            nft.mint(owner);
        }
        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsRegistry() public view {
        assertEq(address(batchRegistry.registry()), address(registry));
    }

    function test_Constructor_SetsMaxBatchSize() public view {
        assertEq(batchRegistry.MAX_BATCH_SIZE(), 100);
    }

    // ============ Happy Path Tests ============

    function test_BatchCreateAccounts_CreatesSingleAccount() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        address[] memory accounts = batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        assertEq(accounts.length, 1);
        assertTrue(accounts[0].code.length > 0);
    }

    function test_BatchCreateAccounts_Creates10Accounts() public {
        uint256[] memory tokenIds = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            tokenIds[i] = i + 1;
        }

        address[] memory accounts = batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        assertEq(accounts.length, 10);
        for (uint256 i = 0; i < 10; i++) {
            assertTrue(accounts[i].code.length > 0, "Account should have code");
            // Verify each account has correct token info
            TokenBoundAccount account = TokenBoundAccount(payable(accounts[i]));
            (, , uint256 tokenId) = account.token();
            assertEq(tokenId, i + 1);
        }
    }

    function test_BatchCreateAccounts_Creates100Accounts() public {
        uint256[] memory tokenIds = new uint256[](100);
        for (uint256 i = 0; i < 100; i++) {
            tokenIds[i] = i + 1;
        }

        address[] memory accounts = batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        assertEq(accounts.length, 100);
        for (uint256 i = 0; i < 100; i++) {
            assertTrue(accounts[i].code.length > 0, "Account should have code");
        }
    }

    function test_BatchCreateAccounts_AddressesMatchPredictions() public {
        uint256[] memory tokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = i + 1;
        }

        // Get predicted addresses
        (address[] memory predicted, ) = batchRegistry.batchComputeAddresses(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        // Create accounts
        address[] memory accounts = batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        // Verify addresses match
        for (uint256 i = 0; i < 5; i++) {
            assertEq(accounts[i], predicted[i], "Address should match prediction");
        }
    }

    function test_BatchCreateAccounts_EmitsEvent() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        // Get predicted addresses for event check
        (address[] memory predicted, ) = batchRegistry.batchComputeAddresses(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        vm.expectEmit(true, true, true, true);
        emit BatchAccountsCreated(
            predicted,
            address(implementation),
            block.chainid,
            address(nft),
            3 // All newly created
        );

        batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );
    }

    // ============ Edge Cases ============

    function test_BatchCreateAccounts_RevertsOnEmptyBatch() public {
        uint256[] memory tokenIds = new uint256[](0);

        vm.expectRevert(IERC6551BatchRegistry.EmptyBatch.selector);
        batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );
    }

    function test_BatchCreateAccounts_RevertsOnBatchTooLarge() public {
        uint256[] memory tokenIds = new uint256[](101);
        for (uint256 i = 0; i < 101; i++) {
            tokenIds[i] = i + 1;
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC6551BatchRegistry.BatchTooLarge.selector,
                101,
                100
            )
        );
        batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );
    }

    function test_BatchCreateAccounts_HandlesDuplicateTokenIds() public {
        // Create batch with duplicate tokenIds
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 1; // Duplicate

        address[] memory accounts = batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        // Should return same address for duplicate
        assertEq(accounts[0], accounts[2], "Duplicate tokenIds should return same address");
        assertTrue(accounts[0] != accounts[1], "Different tokenIds should have different addresses");
    }

    function test_BatchCreateAccounts_HandlesExistingAccounts() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        // Create first batch
        address[] memory firstBatch = batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        // Create same batch again - should return existing addresses
        address[] memory secondBatch = batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        for (uint256 i = 0; i < 3; i++) {
            assertEq(firstBatch[i], secondBatch[i], "Should return existing address");
        }
    }

    function test_BatchCreateAccounts_MixedNewAndExisting() public {
        // Create account for token 2 first
        uint256[] memory singleId = new uint256[](1);
        singleId[0] = 2;
        batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            singleId
        );

        // Now create batch with mix of new (1, 3) and existing (2)
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1; // New
        tokenIds[1] = 2; // Existing
        tokenIds[2] = 3; // New

        address[] memory accounts = batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        // All should have code
        for (uint256 i = 0; i < 3; i++) {
            assertTrue(accounts[i].code.length > 0);
        }

        // Token 2 address should match original creation
        (address[] memory original, ) = batchRegistry.batchComputeAddresses(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            singleId
        );
        assertEq(accounts[1], original[0]);
    }

    function test_BatchCreateAccounts_TracksNewlyCreatedCount() public {
        // Create account for token 2 first
        uint256[] memory singleId = new uint256[](1);
        singleId[0] = 2;
        batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            singleId
        );

        // Create batch with mix - expect event to show 2 newly created
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2; // Already exists
        tokenIds[2] = 3;

        // We need to capture the event to verify newlyCreated count
        vm.recordLogs();
        batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        // Get logs and verify last parameter (newlyCreated)
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Find BatchAccountsCreated event
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("BatchAccountsCreated(address[],address,uint256,address,uint256)")) {
                // Decode the non-indexed parameters
                (address[] memory accounts, uint256 newlyCreated) = abi.decode(entries[i].data, (address[], uint256));
                assertEq(newlyCreated, 2, "Should report 2 newly created accounts");
                assertEq(accounts.length, 3);
                break;
            }
        }
    }

    // ============ BatchComputeAddresses Tests ============

    function test_BatchComputeAddresses_ReturnsCorrectAddresses() public view {
        uint256[] memory tokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = i + 1;
        }

        (address[] memory accounts, bool[] memory exists) = batchRegistry.batchComputeAddresses(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        assertEq(accounts.length, 5);
        assertEq(exists.length, 5);

        // Verify addresses match individual registry.account() calls
        for (uint256 i = 0; i < 5; i++) {
            address expected = registry.account(
                address(implementation),
                SALT,
                block.chainid,
                address(nft),
                tokenIds[i]
            );
            assertEq(accounts[i], expected);
            assertFalse(exists[i], "Account should not exist yet");
        }
    }

    function test_BatchComputeAddresses_CorrectlyReportsExistence() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        // Create account for token 2
        registry.createAccount(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            2
        );

        (address[] memory accounts, bool[] memory exists) = batchRegistry.batchComputeAddresses(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        assertFalse(exists[0], "Token 1 account should not exist");
        assertTrue(exists[1], "Token 2 account should exist");
        assertFalse(exists[2], "Token 3 account should not exist");
    }

    function test_BatchComputeAddresses_EmptyArray() public view {
        uint256[] memory tokenIds = new uint256[](0);

        (address[] memory accounts, bool[] memory exists) = batchRegistry.batchComputeAddresses(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        assertEq(accounts.length, 0);
        assertEq(exists.length, 0);
    }

    // ============ Fuzz Tests ============

    function testFuzz_BatchCreateAccounts_VariableBatchSize(uint8 size) public {
        vm.assume(size > 0 && size <= 100);

        uint256[] memory tokenIds = new uint256[](size);
        for (uint256 i = 0; i < size; i++) {
            tokenIds[i] = i + 1;
        }

        address[] memory accounts = batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );

        assertEq(accounts.length, size);
        for (uint256 i = 0; i < size; i++) {
            assertTrue(accounts[i].code.length > 0);
        }
    }

    function testFuzz_BatchCreateAccounts_DifferentSalts(bytes32 salt) public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        address[] memory accounts = batchRegistry.batchCreateAccounts(
            address(implementation),
            salt,
            block.chainid,
            address(nft),
            tokenIds
        );

        // Verify all accounts are unique
        assertTrue(accounts[0] != accounts[1]);
        assertTrue(accounts[1] != accounts[2]);
        assertTrue(accounts[0] != accounts[2]);
    }

    // ============ Gas Benchmark Tests ============

    function test_GasBenchmark_BatchVsIndividual_10Accounts() public {
        uint256[] memory tokenIds = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            tokenIds[i] = i + 1;
        }

        // Measure batch creation gas
        uint256 gasBefore = gasleft();
        batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );
        uint256 batchGas = gasBefore - gasleft();

        // Log for comparison (run with -vvv to see)
        console2.log("Batch creation gas (10 accounts):", batchGas);
        console2.log("Per-account cost:", batchGas / 10);
    }

    function test_GasBenchmark_BatchVsIndividual_50Accounts() public {
        uint256[] memory tokenIds = new uint256[](50);
        for (uint256 i = 0; i < 50; i++) {
            tokenIds[i] = i + 1;
        }

        uint256 gasBefore = gasleft();
        batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );
        uint256 batchGas = gasBefore - gasleft();

        console2.log("Batch creation gas (50 accounts):", batchGas);
        console2.log("Per-account cost:", batchGas / 50);
    }

    function test_GasBenchmark_BatchVsIndividual_100Accounts() public {
        uint256[] memory tokenIds = new uint256[](100);
        for (uint256 i = 0; i < 100; i++) {
            tokenIds[i] = i + 1;
        }

        uint256 gasBefore = gasleft();
        batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds
        );
        uint256 batchGas = gasBefore - gasleft();

        console2.log("Batch creation gas (100 accounts):", batchGas);
        console2.log("Per-account cost:", batchGas / 100);
    }

    function test_GasBenchmark_LinearGrowth() public {
        // Test that gas grows linearly, not quadratically
        uint256[] memory tokenIds10 = new uint256[](10);
        uint256[] memory tokenIds20 = new uint256[](20);
        uint256[] memory tokenIds30 = new uint256[](30);

        for (uint256 i = 0; i < 30; i++) {
            if (i < 10) tokenIds10[i] = i + 1;
            if (i < 20) tokenIds20[i] = i + 1;
            tokenIds30[i] = i + 1;
        }

        // Measure 10 accounts
        uint256 gas10Before = gasleft();
        batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT,
            block.chainid,
            address(nft),
            tokenIds10
        );
        uint256 gas10 = gas10Before - gasleft();

        // Reset state by using different salt
        uint256 gas20Before = gasleft();
        batchRegistry.batchCreateAccounts(
            address(implementation),
            SALT_2,
            block.chainid,
            address(nft),
            tokenIds20
        );
        uint256 gas20 = gas20Before - gasleft();

        // Check linearity - gas for 20 should be roughly 2x gas for 10
        // Allow 20% variance for base costs
        uint256 perItem10 = gas10 / 10;
        uint256 perItem20 = gas20 / 20;

        console2.log("Per-item gas (10 accounts):", perItem10);
        console2.log("Per-item gas (20 accounts):", perItem20);

        // Per-item cost should be similar (within 30%)
        assertTrue(
            perItem20 < perItem10 * 130 / 100 && perItem20 > perItem10 * 70 / 100,
            "Gas growth should be approximately linear"
        );
    }
}
