import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = process.env.HARDHAT_NETWORK || "testnet";

  // Get addresses based on network
  const prefix = network === "mainnet" ? "MAIN_" : "TEST_";

  const deployerPk = process.env[`${prefix}DEPLOYER_PK`];
  const rolesManager = process.env[`${prefix}ROLES_MANAGER`];
  const tokenContractManager = process.env[`${prefix}TOKEN_CONTRACT_MANAGER`];
  const tokenRecoveryManager = process.env[`${prefix}TOKEN_RECOVERY_MANAGER`];
  const multisig = process.env[`${prefix}MULTISIG`];
  const pegManager = process.env[`${prefix}PEG_MANAGER`];
  const bridge = process.env[`${prefix}BRIDGE_ADDRESS`];

  if (
    !deployerPk ||
    !rolesManager ||
    !tokenContractManager ||
    !tokenRecoveryManager ||
    !multisig ||
    !pegManager ||
    !bridge
  ) {
    throw new Error("Missing required environment variables");
  }

  console.log(`\nDeploying to ${network} with:`);
  console.log("Deployer:", deployer.address);
  console.log("Roles Manager:", rolesManager);
  console.log("Token Contract Manager:", tokenContractManager);
  console.log("Token Recovery Manager:", tokenRecoveryManager);
  console.log("Multisig:", multisig);
  console.log("Peg Manager:", pegManager);
  console.log("Bridge:", bridge);

  // Deploy Token
  const Token = await ethers.getContractFactory("Token");
  const token = await Token.deploy(
    rolesManager,
    tokenContractManager,
    tokenRecoveryManager,
    multisig
  );
  await token.deployed();
  console.log("\nToken deployed to:", token.address);

  // Deploy TokenPeg
  const TokenPeg = await ethers.getContractFactory("TokenPeg");
  const peg = await TokenPeg.deploy(
    bridge,
    token.address,
    rolesManager,
    pegManager
  );
  await peg.deployed();
  console.log("TokenPeg deployed to:", peg.address);

  // Initialize token with peg address
  const rolesManagerSigner = new ethers.Wallet(
    process.env[`${prefix}ROLES_MANAGER_PK`] as string,
    ethers.provider
  );
  await token.connect(rolesManagerSigner).init(peg.address);
  console.log("Token initialized with peg:", peg.address);

  console.log("\nVerification commands:");
  console.log(
    "Token:",
    `npx hardhat verify --network ${network} ${token.address} "${rolesManager}" "${tokenContractManager}" "${tokenRecoveryManager}" "${multisig}"`
  );
  console.log(
    "TokenPeg:",
    `npx hardhat verify --network ${network} ${peg.address} "${bridge}" "${token.address}" "${rolesManager}" "${pegManager}"`
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
