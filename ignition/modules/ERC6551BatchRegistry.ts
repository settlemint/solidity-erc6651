import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Hardhat Ignition module for deploying ERC6551BatchRegistry
 *
 * This module deploys the batch registry wrapper that enables
 * gas-efficient creation of multiple token-bound accounts.
 *
 * Prerequisites:
 *   - ERC6551Registry must be deployed first
 *
 * Usage:
 *   npx hardhat ignition deploy ignition/modules/ERC6551BatchRegistry.ts \
 *     --parameters '{"registry": "0x..."}' \
 *     --network <network>
 */
const ERC6551BatchRegistryModule = buildModule("ERC6551BatchRegistry", (m) => {
  // Registry address parameter (required)
  const registry = m.getParameter<string>("registry");

  // Deploy the batch registry wrapper
  const batchRegistry = m.contract("ERC6551BatchRegistry", [registry]);

  return { batchRegistry };
});

export default ERC6551BatchRegistryModule;
