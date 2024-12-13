import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {

  const mockUsdt = await ethers.deployContract("MockERC20", []);
  await mockUsdt.waitForDeployment();
  console.log(`Mock usdt deployed to ${mockUsdt.target}`);

  let tx;
  const pUSDT = "0xBBF92F72a4627CEc4517aAcD817144014a8f64D8"
  
  const admin_address = "0x556180984Ec8B4d28476376f99A071042f262a5c"

  const publicPoolV1 = "0x9aEfB3a61787d30f33B4049382647e1D85Eb50EB"
  
  const publicPoolv2 = await ethers.deployContract("IncentivePoolV2", [pUSDT, publicPoolV1]);
  await publicPoolv2.waitForDeployment();
  console.log(`Public pool deployed to ${publicPoolv2.target}`);
  const publicPoolv2PoolContract = publicPoolv2.target

  const POOL_SIGNER = await publicPoolv2.POOL_SIGNER()
  tx = await publicPoolv2.grantRole(POOL_SIGNER, admin_address)

 
  try {
    await hre.run("verify:verify", {
      address: publicPoolv2PoolContract,
      constructorArguments: [pUSDT, publicPoolV1],
    });
  } catch (error) {
    console.log('publicPool2: ', error);
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