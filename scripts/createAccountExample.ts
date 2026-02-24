import fs from "fs";
import path from "path";
import hre from "hardhat";
import {
  encodeFunctionData,
  parseEther,
  parseUnits,
  zeroHash,
  type Address,
} from "viem";

/**
 * Example script demonstrating how to create and use a token-bound account
 *
 * This script:
 * 1. Gets deployed contract addresses
 * 2. Mints an NFT
 * 3. Computes the expected account address
 * 4. Creates the token-bound account
 * 5. Sends ETH to the account
 * 6. Executes an ETH transfer through the account
 * 7. Mints ERC-20 tokens to the owner
 * 8. Transfers ERC-20 tokens to the TBA
 * 9. Executes an ERC-20 transfer FROM the TBA
 *
 * Usage:
 *   npx hardhat run scripts/createAccountExample.ts --network <network>
 *
 * Addresses are auto-detected from Ignition deployment artifacts.
 * You can override any address via environment variables.
 */

/**
 * Load deployed contract addresses from Ignition deployment artifacts.
 * Matches the chain-<id> directory to the current network's chain ID.
 */
function loadDeployedAddresses(chainId: number): Record<string, string> {
  try {
    const deploymentsDir = path.join(
      __dirname,
      "..",
      "ignition",
      "deployments",
    );
    if (!fs.existsSync(deploymentsDir)) return {};
    const chainDir = `chain-${chainId}`;
    const fullPath = path.join(
      deploymentsDir,
      chainDir,
      "deployed_addresses.json",
    );
    if (!fs.existsSync(fullPath)) return {};
    return JSON.parse(fs.readFileSync(fullPath, "utf8"));
  } catch {
    return {};
  }
}

async function main() {
  console.log("=== ERC-6551 Token Bound Account Example ===\n");

  // Get the public client and wallet client
  const publicClient = await hre.viem.getPublicClient();
  const [owner] = await hre.viem.getWalletClients();

  console.log("Using account:", owner.account.address);

  // Auto-detect addresses from Ignition artifacts, with env var overrides
  const chainId = await publicClient.getChainId();
  const deployed = loadDeployedAddresses(chainId);
  if (Object.keys(deployed).length > 0) {
    console.log(
      `Auto-detected addresses from Ignition deployment (chain ${chainId})`,
    );
  }

  const REGISTRY_ADDRESS = (process.env.REGISTRY_ADDRESS ||
    deployed["ERC6551Module#ERC6551Registry"]) as Address;
  const IMPLEMENTATION_ADDRESS = (process.env.IMPLEMENTATION_ADDRESS ||
    deployed["ERC6551Module#TokenBoundAccount"]) as Address;
  const NFT_ADDRESS = (process.env.NFT_ADDRESS ||
    deployed["ERC6551Module#ExampleNFT"]) as Address;
  const ERC20_ADDRESS = (process.env.ERC20_ADDRESS ||
    deployed["ERC6551Module#ExampleERC20"]) as Address;

  if (
    !REGISTRY_ADDRESS ||
    !IMPLEMENTATION_ADDRESS ||
    !NFT_ADDRESS ||
    !ERC20_ADDRESS
  ) {
    console.error(
      "\nCould not find contract addresses. Either deploy first or set environment variables:",
    );
    console.error("  REGISTRY_ADDRESS - The ERC6551Registry contract address");
    console.error(
      "  IMPLEMENTATION_ADDRESS - The TokenBoundAccount implementation address",
    );
    console.error("  NFT_ADDRESS - The ExampleNFT contract address");
    console.error("  ERC20_ADDRESS - The ExampleERC20 contract address");
    console.error("\nDeploy first:");
    console.error(
      "  bunx settlemint scs hardhat deploy remote -m ignition/modules/main.ts --accept-defaults",
    );
    console.error("\nOr set env vars manually:");
    console.error(
      "  REGISTRY_ADDRESS=0x... IMPLEMENTATION_ADDRESS=0x... NFT_ADDRESS=0x... ERC20_ADDRESS=0x... npx hardhat run scripts/createAccountExample.ts",
    );
    process.exit(1);
  }

  // Get contract instances
  const registry = await hre.viem.getContractAt(
    "ERC6551Registry",
    REGISTRY_ADDRESS,
  );
  const nft = await hre.viem.getContractAt("ExampleNFT", NFT_ADDRESS);
  const implementation = await hre.viem.getContractAt(
    "TokenBoundAccount",
    IMPLEMENTATION_ADDRESS,
  );
  const erc20 = await hre.viem.getContractAt("ExampleERC20", ERC20_ADDRESS);

  console.log("\nContract Addresses:");
  console.log("  Registry:", REGISTRY_ADDRESS);
  console.log("  Implementation:", IMPLEMENTATION_ADDRESS);
  console.log("  NFT:", NFT_ADDRESS);
  console.log("  ERC20:", ERC20_ADDRESS);

  // Step 1: Mint an NFT
  console.log("\n1. Minting NFT...");
  const mintTx = await nft.write.mint([owner.account.address]);
  await publicClient.waitForTransactionReceipt({ hash: mintTx });

  // Get the minted token ID (it's the previous nextTokenId)
  const tokenId = (await nft.read.nextTokenId()) - 1n;
  console.log("   Minted token ID:", tokenId.toString());

  // Step 2: Compute the account address
  console.log("\n2. Computing account address...");
  const chainIdBigInt = BigInt(chainId);
  const salt = zeroHash; // Using zero salt for simplicity

  const accountAddress = await registry.read.account([
    IMPLEMENTATION_ADDRESS,
    salt,
    chainIdBigInt,
    NFT_ADDRESS,
    tokenId,
  ]);
  console.log("   Predicted account address:", accountAddress);

  // Check if account already exists
  const existingCode = await publicClient.getBytecode({
    address: accountAddress,
  });
  console.log(
    "   Account exists:",
    existingCode !== undefined && existingCode !== "0x",
  );

  // Step 3: Create the account
  console.log("\n3. Creating token-bound account...");
  const createTx = await registry.write.createAccount([
    IMPLEMENTATION_ADDRESS,
    salt,
    chainIdBigInt,
    NFT_ADDRESS,
    tokenId,
  ]);
  const receipt = await publicClient.waitForTransactionReceipt({
    hash: createTx,
  });
  console.log("   Transaction hash:", createTx);
  console.log("   Gas used:", receipt.gasUsed.toString());

  // Verify the account was created at the predicted address
  const account = await hre.viem.getContractAt(
    "TokenBoundAccount",
    accountAddress,
  );
  const [tokenChainId, tokenContract, accountTokenId] =
    await account.read.token();
  console.log("   Account created successfully!");
  console.log(
    "   Token info - Chain:",
    tokenChainId.toString(),
    "Contract:",
    tokenContract,
    "ID:",
    accountTokenId.toString(),
  );

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
    owner.account.address, // to
    executeAmount, // value
    "0x", // data (empty for simple transfer)
    0, // operation (0 = CALL)
  ]);
  await publicClient.waitForTransactionReceipt({ hash: executeTx });
  console.log("   Execution hash:", executeTx);

  const finalBalance = await publicClient.getBalance({
    address: accountAddress,
  });
  console.log("   Final account balance:", finalBalance.toString(), "wei");

  // Step 6: Check account state
  console.log("\n6. Checking account state...");
  const state = await account.read.state();
  console.log(
    "   Account state:",
    state.toString(),
    "(increments on each execution)",
  );

  const accountOwner = await account.read.owner();
  console.log("   Account owner:", accountOwner);
  console.log("   NFT owner:", await nft.read.ownerOf([tokenId]));

  // Step 7: Mint ERC-20 tokens to the owner
  console.log("\n7. Minting ERC-20 tokens to owner...");
  const mintAmount = parseUnits("1000", 18); // 1000 tokens
  const mintErc20Tx = await erc20.write.mint([
    owner.account.address,
    mintAmount,
  ]);
  await publicClient.waitForTransactionReceipt({ hash: mintErc20Tx });

  const ownerErc20Balance = await erc20.read.balanceOf([owner.account.address]);
  console.log("   Owner ERC-20 balance:", ownerErc20Balance.toString());

  // Step 8: Transfer ERC-20 tokens to the TBA
  console.log("\n8. Transferring ERC-20 tokens to TBA...");
  const transferToTbaAmount = parseUnits("100", 18); // 100 tokens
  const transferTx = await erc20.write.transfer([
    accountAddress,
    transferToTbaAmount,
  ]);
  await publicClient.waitForTransactionReceipt({ hash: transferTx });

  const tbaErc20Balance = await erc20.read.balanceOf([accountAddress]);
  console.log("   TBA ERC-20 balance:", tbaErc20Balance.toString());

  // Step 9: Execute an ERC-20 transfer FROM the TBA
  // This demonstrates the TBA acting as a wallet — the NFT owner
  // instructs the TBA to send ERC-20 tokens to another address.
  console.log("\n9. Executing ERC-20 transfer from TBA...");
  const transferFromTbaAmount = parseUnits("25", 18); // 25 tokens

  // Encode the ERC-20 transfer(address,uint256) calldata
  const transferCalldata = encodeFunctionData({
    abi: [
      {
        name: "transfer",
        type: "function",
        inputs: [
          { name: "to", type: "address" },
          { name: "amount", type: "uint256" },
        ],
        outputs: [{ name: "", type: "bool" }],
      },
    ],
    functionName: "transfer",
    args: [owner.account.address, transferFromTbaAmount],
  });

  const executeErc20Tx = await account.write.execute([
    ERC20_ADDRESS, // to: the ERC-20 contract
    0n, // value: no ETH
    transferCalldata, // data: encoded transfer call
    0, // operation: CALL
  ]);
  await publicClient.waitForTransactionReceipt({ hash: executeErc20Tx });
  console.log("   Execution hash:", executeErc20Tx);

  const tbaFinalErc20Balance = await erc20.read.balanceOf([accountAddress]);
  const ownerFinalErc20Balance = await erc20.read.balanceOf([
    owner.account.address,
  ]);
  console.log("   TBA ERC-20 balance after:", tbaFinalErc20Balance.toString());
  console.log(
    "   Owner ERC-20 balance after:",
    ownerFinalErc20Balance.toString(),
  );

  // Final state check
  const finalState = await account.read.state();

  console.log("\n=== Example Complete ===");
  console.log("\nSummary:");
  console.log("  Token ID:", tokenId.toString());
  console.log("  Account Address:", accountAddress);
  console.log("  Account Owner:", accountOwner);
  console.log("  Account State:", finalState.toString());
  console.log("  Account ETH Balance:", finalBalance.toString(), "wei");
  console.log("  Account ERC-20 Balance:", tbaFinalErc20Balance.toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
