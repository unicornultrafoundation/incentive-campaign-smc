import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {
    let tx;
    const signer_address = "0x556180984Ec8B4d28476376f99A071042f262a5c"

    const admin_address = "0xB246603EF552D8372c4c91c5BAEf2Eed9c902fF4"
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
        console.log('dailyQuest: ', error);
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

// AirdropPool to 0xf12256d2BbE4971e8F7f444596E47c390E869F5E
// npx hardhat verify --network nebulas 0xf12256d2BbE4971e8F7f444596E47c390E869F5E
// https://testnet.u2uscan.xyz/address/0x174d982Ff0A30f2e90D5aD9fF75802b96d847FA7#code