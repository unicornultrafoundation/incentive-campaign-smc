import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {

  const mockUsdt = await ethers.deployContract("MockERC20", []);
  await mockUsdt.waitForDeployment();
  console.log(`Mock usdt deployed to ${mockUsdt.target}`);

  let tx;
  const pUSDT = mockUsdt.target
  const admin_address = "0x556180984Ec8B4d28476376f99A071042f262a5c"
  const pool1_address = "0x9aEfB3a61787d30f33B4049382647e1D85Eb50EB"

  const publicPool2 = await ethers.deployContract("IncentivePoolV2", [pUSDT, pool1_address]);
  await publicPool2.waitForDeployment();
  console.log(`Public pool 2 deployed to ${publicPool2.target}`);
  const publicPoolContract = publicPool2.target

  const SIGNER_ROLE = await  publicPool2.POOL_SIGNER()

  tx = await publicPool2.grantRole(SIGNER_ROLE, admin_address)

  const pusdtAt = await ethers.getContractAt("MockERC20", pUSDT);
  tx = await pusdtAt.approve(publicPoolContract, "1000000000000")

  try {
    await hre.run("verify:verify", {
      address: publicPoolContract,
      constructorArguments: [pUSDT, pool1_address],
    });
  } catch (error) {
    console.log('publicPool2: ', error);
  }

  try {
    await hre.run("verify:verify", {
      address: pUSDT,
      constructorArguments: [],
    });
  } catch (error) {
    console.log('pUSDT: ', error);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


// npx hardhat verify --network nebulas 0x965aD51893144E91086c0c3EcbEB7066dA451320 0xBBF92F72a4627CEc4517aAcD817144014a8f64D8 0x9aEfB3a61787d30f33B4049382647e1D85Eb50EB

// Mock usdt deployed to 0xBBF92F72a4627CEc4517aAcD817144014a8f64D8
// Public pool 2 deployed to 0x965aD51893144E91086c0c3EcbEB7066dA451320