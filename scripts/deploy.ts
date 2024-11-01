import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {
  let tx;
  const pUSDT = "0x8Fef26D79DA3Ac2AE5DaC2acfb5A802Fb043E6F0"
  const signer_role = "0xece0090efe769fae380dcd2ae676ddd28ca1b22e739a0f915e9d654a2214334d"
  const admin_address = "0x556180984Ec8B4d28476376f99A071042f262a5c"
  const startTime = 1730354400
  const publicPool = await ethers.deployContract("IncentivePool", [pUSDT, startTime]);
  await publicPool.waitForDeployment();
  console.log(`Public pool deployed to ${publicPool.target}`);
  const publicPoolContract = publicPool.target
  tx = await publicPool.grantRole(signer_role, admin_address)

  const bigetPool = await ethers.deployContract("IncentivePool", [pUSDT, startTime]);
  await bigetPool.waitForDeployment();
  console.log(`Bitget pool deployed to ${bigetPool.target}`);
  const bigetPoolContract = bigetPool.target
  tx = await bigetPool.grantRole(signer_role, admin_address)

  try {
    await hre.run("verify:verify", {
      address: publicPoolContract,
      constructorArguments: [pUSDT, startTime],
    });
  } catch (error) {
    console.log('publicPoolContract: ', error);
  }
  try {
    await hre.run("verify:verify", {
      address: bigetPoolContract,
      constructorArguments: [pUSDT, startTime],
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

// Public pool deployed to 0xc444aFA8C8007B7594C54B40AEA51Ada5589725C
// Bitget pool deployed to 0x286AD6DA882A4600a0Ed92d20ce1541a8Dc5c34b