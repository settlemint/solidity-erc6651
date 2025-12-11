import hre from "hardhat";
import { parseEther, zeroHash, type Address } from "viem";

/**
 * Example script demonstrating how to create and use a token-bound account
 *
 * This script:
 * 1. Gets deployed contract addresses
 * 2. Mints an NFT
 * 3. Computes the expected account address
 * 4. Creates the token-bound account
 * 5. Sends ETH to the account
 * 6. Executes a transaction through the account
 *
 * Usage:
 *   npx hardhat run scripts/createAccountExample.ts --network <network>
 */
async function main() {
  console.log("=== ERC-6551 Token Bound Account Example ===\n");

  // Get the public client and wallet client
  const publicClient = await hre.viem.getPublicClient();
  const [owner] = await hre.viem.getWalletClients();

  console.log("Using account:", owner.account.address);

  // These addresses should be updated after deployment
  // You can get them from the Hardhat Ignition deployment output
  const REGISTRY_ADDRESS = process.env.REGISTRY_ADDRESS as Address;
  const IMPLEMENTATION_ADDRESS = process.env.IMPLEMENTATION_ADDRESS as Address;
  const NFT_ADDRESS = process.env.NFT_ADDRESS as Address;

  if (!REGISTRY_ADDRESS || !IMPLEMENTATION_ADDRESS || !NFT_ADDRESS) {
    console.error("\nPlease set the following environment variables:");
    console.error("  REGISTRY_ADDRESS - The ERC6551Registry contract address");
    console.error("  IMPLEMENTATION_ADDRESS - The TokenBoundAccount implementation address");
    console.error("  NFT_ADDRESS - The ExampleNFT contract address");
    console.error("\nExample:");
    console.error("  REGISTRY_ADDRESS=0x... IMPLEMENTATION_ADDRESS=0x... NFT_ADDRESS=0x... npx hardhat run scripts/createAccountExample.ts");
    process.exit(1);
  }

  // Get contract instances
  const registry = await hre.viem.getContractAt("ERC6551Registry", REGISTRY_ADDRESS);
  const nft = await hre.viem.getContractAt("ExampleNFT", NFT_ADDRESS);
  const implementation = await hre.viem.getContractAt("TokenBoundAccount", IMPLEMENTATION_ADDRESS);

  console.log("\nContract Addresses:");
  console.log("  Registry:", REGISTRY_ADDRESS);
  console.log("  Implementation:", IMPLEMENTATION_ADDRESS);
  console.log("  NFT:", NFT_ADDRESS);

  // Step 1: Mint an NFT
  console.log("\n1. Minting NFT...");
  const mintTx = await nft.write.mint([owner.account.address]);
  await publicClient.waitForTransactionReceipt({ hash: mintTx });

  // Get the minted token ID (it's the previous nextTokenId)
  const tokenId = (await nft.read.nextTokenId()) - 1n;
  console.log("   Minted token ID:", tokenId.toString());

  // Step 2: Compute the account address
  console.log("\n2. Computing account address...");
  const chainId = BigInt(await publicClient.getChainId());
  const salt = zeroHash; // Using zero salt for simplicity

  const accountAddress = await registry.read.account([
    IMPLEMENTATION_ADDRESS,
    salt,
    chainId,
    NFT_ADDRESS,
    tokenId,
  ]);
  console.log("   Predicted account address:", accountAddress);

  // Check if account already exists
  const existingCode = await publicClient.getBytecode({ address: accountAddress });
  console.log("   Account exists:", existingCode !== undefined && existingCode !== "0x");

  // Step 3: Create the account
  console.log("\n3. Creating token-bound account...");
  const createTx = await registry.write.createAccount([
    IMPLEMENTATION_ADDRESS,
    salt,
    chainId,
    NFT_ADDRESS,
    tokenId,
  ]);
  const receipt = await publicClient.waitForTransactionReceipt({ hash: createTx });
  console.log("   Transaction hash:", createTx);
  console.log("   Gas used:", receipt.gasUsed.toString());

  // Verify the account was created at the predicted address
  const account = await hre.viem.getContractAt("TokenBoundAccount", accountAddress);
  const [tokenChainId, tokenContract, accountTokenId] = await account.read.token();
  console.log("   Account created successfully!");
  console.log("   Token info - Chain:", tokenChainId.toString(), "Contract:", tokenContract, "ID:", accountTokenId.toString());

  // Step 4: Send ETH to the account
  console.log("\n4. Sending ETH to account...");
  const sendAmount = parseEther("0.01");
  const sendTx = await owner.sendTransaction({
    to: accountAddress,
    value: sendAmount,
  });
  await publicClient.waitForTransactionReceipt({ hash: sendTx });

  const balance = await publicClient.getBalance({ address: accountAddress });
  console.log("   Account balance:", balance.toString(), "wei");

  // Step 5: Execute a transaction through the account
  console.log("\n5. Executing transaction through account...");

  // Create a simple transaction to send ETH back to the owner
  const executeAmount = parseEther("0.005");
  const executeTx = await account.write.execute([
    owner.account.address,  // to
    executeAmount,          // value
    "0x",                  // data (empty for simple transfer)
    0,                     // operation (0 = CALL)
  ]);
  await publicClient.waitForTransactionReceipt({ hash: executeTx });
  console.log("   Execution hash:", executeTx);

  const finalBalance = await publicClient.getBalance({ address: accountAddress });
  console.log("   Final account balance:", finalBalance.toString(), "wei");

  // Step 6: Check account state
  console.log("\n6. Checking account state...");
  const state = await account.read.state();
  console.log("   Account state:", state.toString(), "(increments on each execution)");

  const accountOwner = await account.read.owner();
  console.log("   Account owner:", accountOwner);
  console.log("   NFT owner:", await nft.read.ownerOf([tokenId]));

  console.log("\n=== Example Complete ===");
  console.log("\nSummary:");
  console.log("  Token ID:", tokenId.toString());
  console.log("  Account Address:", accountAddress);
  console.log("  Account Owner:", accountOwner);
  console.log("  Account State:", state.toString());
  console.log("  Account Balance:", finalBalance.toString(), "wei");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
