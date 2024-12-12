import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {
    
  let tx;
  const pUSDT = "0xCEe1525E6A5eBc6c918c12b42B0c57f58013012f"
  const admin_address = "0xc1A5746944c732482752992fe902236416850383"
  const startTime = 1731398400
  const claimableTime = 1732953600

  const publicPool = await ethers.deployContract("IncentivePool", [pUSDT, startTime, claimableTime]);
  await publicPool.waitForDeployment();
  console.log(`Public pool deployed to ${publicPool.target}`);
  const publicPoolContract = publicPool.target

  const SIGNER_ROLE = await publicPool.POOL_SIGNER()
  tx = await publicPool.grantRole(SIGNER_ROLE, admin_address)

  try {
    await hre.run("verify:verify", {
      address: publicPoolContract,
      constructorArguments: [pUSDT, startTime, claimableTime],
    });
  } catch (error) {
    console.log('publicPoolContract: ', error);
  }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


// Public pool deployed to 0x07cF4b1F02F49Ca6dEe8eF12153da0D619c9E1EF