import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {
    let tx;
    const signer_address = "0xc1A5746944c732482752992fe902236416850383"

    const admin_address = "0x8204A1c6A7Db714eE20229eFD5D37ca271009259"
    const airdropPool = await ethers.deployContract("AirdropPool", []);

    await airdropPool.waitForDeployment();
    console.log(`AirdropPool to ${airdropPool.target}`);
    const airdropPoolContract = airdropPool.target
    const AIRDROP_ADMIN = await airdropPool.AIRDROP_ADMIN()
    tx = await airdropPool.grantRole(AIRDROP_ADMIN, admin_address)

    const POOL_SIGNER = await airdropPool.POOL_SIGNER()
    tx = await airdropPool.grantRole(POOL_SIGNER, signer_address)

    try {
        await hre.run("verify:verify", {
            address: airdropPoolContract,
            constructorArguments: [],
        });
    } catch (error) {
        console.log('AirdropPool: ', error);
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});


// AirdropPool to 0xC4403A81f7bdaA85b7f823226dbA1cba76227F25