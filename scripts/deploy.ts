import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {
  const pUSDT = "0x8Fef26D79DA3Ac2AE5DaC2acfb5A802Fb043E6F0"
  const startTime = 1730354400
  const incentivePool = await ethers.deployContract("IncentivePool", [pUSDT, startTime]);
  await incentivePool.waitForDeployment();
  console.log(`IncentivePool deployed to ${incentivePool.target}`);
  const incentivePoolContract = incentivePool.target
  try {
    await hre.run("verify:verify", {
      address: incentivePoolContract,
      constructorArguments: [pUSDT, startTime],
    });
  } catch (error) {
    console.log('dailyQuest: ', error);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
