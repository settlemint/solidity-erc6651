import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Hardhat Ignition module for a complete ERC-6551 deployment
 *
 * This module deploys:
 * - ERC6551Registry: The central registry for creating accounts
 * - TokenBoundAccount: Base implementation
 * - ERC1271TokenBoundAccount: Implementation with signature validation
 * - ExampleNFT: Test NFT for demonstration (optional in production)
 *
 * Usage:
 *   npx hardhat ignition deploy ignition/modules/FullDeployment.ts --network <network>
 */
const FullDeploymentModule = buildModule("FullDeployment", (m) => {
  // Configuration parameters
  const nftName = m.getParameter("nftName", "Example Token Bound NFT");
  const nftSymbol = m.getParameter("nftSymbol", "TBNFT");
  const nftBaseURI = m.getParameter("nftBaseURI", "https://example.com/metadata/");

  // Deploy the registry
  const registry = m.contract("ERC6551Registry");

  // Deploy implementations
  const tokenBoundAccount = m.contract("TokenBoundAccount");
  const erc1271Account = m.contract("ERC1271TokenBoundAccount");

  // Deploy example NFT (for testing - can be omitted in production)
  const exampleNFT = m.contract("ExampleNFT", [nftName, nftSymbol, nftBaseURI]);

  // Deploy example usage contract
  const exampleUsage = m.contract("ExampleUsage", [registry, tokenBoundAccount]);

  return {
    registry,
    tokenBoundAccount,
    erc1271Account,
    exampleNFT,
    exampleUsage,
  };
});

export default FullDeploymentModule;
