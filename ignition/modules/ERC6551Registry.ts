import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Hardhat Ignition module for deploying the ERC6551Registry contract
 *
 * The registry is the central contract for creating token-bound accounts.
 * It should be deployed once per network and can be shared by all users.
 *
 * Usage:
 *   npx hardhat ignition deploy ignition/modules/ERC6551Registry.ts --network <network>
 */
const ERC6551RegistryModule = buildModule("ERC6551Registry", (m) => {
  // Deploy the registry contract
  const registry = m.contract("ERC6551Registry");

  return { registry };
});

export default ERC6551RegistryModule;
