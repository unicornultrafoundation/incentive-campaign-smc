import { ethers } from "hardhat";
import hre from "hardhat";

async function main() {
    let tx;
    const admin_address = "0xB246603EF552D8372c4c91c5BAEf2Eed9c902fF4"
    const airdropPool = await ethers.deployContract("AirdropPool", []);
    await airdropPool.waitForDeployment();
    console.log(`AirdropPool to ${airdropPool.target}`);
    const airdropPoolContract = airdropPool.target
    const AIRDROP_ADMIN = await airdropPool.AIRDROP_ADMIN()
    tx = await airdropPool.grantRole(AIRDROP_ADMIN, admin_address)
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

// AirdropPool to 0x174d982Ff0A30f2e90D5aD9fF75802b96d847FA7
// npx hardhat verify --network nebulas 0x174d982Ff0A30f2e90D5aD9fF75802b96d847FA7
// https://testnet.u2uscan.xyz/address/0x174d982Ff0A30f2e90D5aD9fF75802b96d847FA7#code