import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {

  let tx;
  const pUSDT = "0xCEe1525E6A5eBc6c918c12b42B0c57f58013012f"
  const admin_address = "0xc1A5746944c732482752992fe902236416850383"
  const startTime = 1731664800
  // const claimableTime = 1739440800
  const claimableTime = 1731664800

  const bigetPool = await ethers.deployContract("IncentivePool", [pUSDT, startTime, claimableTime]);
  await bigetPool.waitForDeployment();
  console.log(`Bitget pool deployed to ${bigetPool.target}`);
  const bigetPoolContract = bigetPool.target
  const SIGNER_ROLE = await bigetPool.POOL_SIGNER()

  tx = await bigetPool.grantRole(SIGNER_ROLE, admin_address)

  try {
    await hre.run("verify:verify", {
      address: bigetPoolContract,
      constructorArguments: [pUSDT, startTime, claimableTime],
    });
  } catch (error) {
    console.log('bigetPoolContract: ', error);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});



// Bitget pool deployed to 0x2183a87Eb7967EF5CB2F50c40F033aeDCe2f07fD