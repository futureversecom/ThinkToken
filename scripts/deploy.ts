import { ethers } from "hardhat";

async function main() {
  // Get deployer and other accounts
  const [deployer] = await ethers.getSigners();

  // Get addresses from env
  const manager = process.env.MANAGER_ADDRESS;
  const multisig = process.env.MULTISIG_ADDRESS;
  const peg = process.env.PEG_ADDRESS;

  if (!manager || !multisig || !peg) {
    throw new Error("Missing required environment variables");
  }

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Manager address:", manager);
  console.log("Multisig address:", multisig);
  console.log("Peg address:", peg);

  // Deploy ThinkToken
  const ThinkToken = await ethers.getContractFactory("ThinkToken");
  const token = await ThinkToken.deploy(manager, multisig);
  await token.deployed();
  console.log("ThinkToken deployed to:", token.address);

  // Initialize token with peg address
  // Note: This needs to be called by the manager account
  const managerSigner = await ethers.getSigner(manager);
  await token.connect(managerSigner).init(peg);
  console.log("Token initialized with peg:", peg);

  // Verify roles
  const hasManagerRole = await token.hasRole(
    ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MANAGER_ROLE")),
    manager
  );
  const hasMultisigRole = await token.hasRole(
    ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MULTISIG_ROLE")),
    multisig
  );

  console.log("Role verification:");
  console.log("- Manager role granted:", hasManagerRole);
  console.log("- Multisig role granted:", hasMultisigRole);

  // Log deployment info for verification
  console.log("\nDeployment Info for Verification:");
  console.log(
    "npx hardhat verify --network <network>",
    token.address,
    manager,
    multisig
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
