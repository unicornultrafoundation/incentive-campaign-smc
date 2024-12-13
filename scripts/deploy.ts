import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {
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
    console.log('publicPoolContract: ', error);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// Public pool deployed to 0xc444aFA8C8007B7594C54B40AEA51Ada5589725C
// Bitget pool deployed to 0x286AD6DA882A4600a0Ed92d20ce1541a8Dc5c34b