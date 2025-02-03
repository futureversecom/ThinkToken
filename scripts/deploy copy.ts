import { ethers } from "hardhat";

async function main() {
  // deploy bridge contract
  const BridgeFactory = await ethers.getContractFactory("Bridge");
  const bridge = await BridgeFactory.deploy();
  await bridge.deployed();
  console.log(`Bridge deployed to ${bridge.address}`);

  // deploy erc20Peg contract
  const ERC20PegFactory = await ethers.getContractFactory("ERC20Peg");
  const erc20Peg = await ERC20PegFactory.deploy(bridge.address);
  await erc20Peg.deployed();
  console.log(`ERC20Peg deployed to ${erc20Peg.address}`);

  // deploy mock erc20 token
  const MockERC20Factory = await ethers.getContractFactory("MockERC20");
  const mockERC20 = await MockERC20Factory.deploy(
    "Test Token",
    "TEST",
    1_000_000
  );

  // make deposit to erc20 peg contract
  const depositAmount = 5644;
  await mockERC20.approve(erc20Peg.address, depositAmount);
  const rootAddress =
    "0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d"; // TODO - invalid address
  const tx = await erc20Peg.deposit(
    mockERC20.address,
    depositAmount,
    rootAddress
  );
  await tx.wait();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
