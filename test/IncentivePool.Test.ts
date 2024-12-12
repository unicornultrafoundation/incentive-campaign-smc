import BigNumber from "bignumber.js";
import { expect } from "chai";
import { ethers } from "hardhat";
const zero_address = "0x0000000000000000000000000000000000000000"

describe("Vesting", function () {
  before(async function () {
    this.IncentivePool = await ethers.getContractFactory("IncentivePool");
    this.IncentivePoolV2 = await ethers.getContractFactory("IncentivePoolV2");
    this.MockERC20 = await ethers.getContractFactory("MockERC20");

    this.signers = await ethers.getSigners();
    this.admin = this.signers[0]
    this.adminAddr = this.signers[0].address
    this.bob = this.signers[1]
    this.bobAddr = this.signers[1].address
    this.alice = this.signers[2]
    this.aliceAddr = this.signers[2].address
    this.john = this.signers[3]
    this.johnAddr = this.signers[3].address
    console.log(`Admin address: ${this.adminAddr}`)

  })

  beforeEach(async function () {

    const block = await ethers.provider.getBlock("latest"); // Fetch the latest block
    const startTime = block ? block.timestamp + 300 : 0; // Get the timestamp from the block

    this.usdt1 = await this.MockERC20.deploy()
    console.log(`USDT address: ${this.usdt1.target}`)

    // Transfer USDT to BOB
    await this.usdt1.transfer(this.bobAddr, "10000000000")
    let bobUSDT1Balance = await this.usdt1.balanceOf(this.bobAddr)
    console.log(`BOB USDT balance: ${bobUSDT1Balance}`)

    this.usdt2 = await this.MockERC20.deploy()
    console.log(`USDT address: ${this.usdt2.target}`)

    this.poolV1 = await this.IncentivePool.deploy(this.usdt1.target, startTime, startTime)
    console.log(`IncentivePool address: ${this.poolV1.target}`)

    // BoB staking
    await this.usdt1.connect(this.bob).approve(this.poolV1.target, "10000000000")
    await this.poolV1.connect(this.bob).stake("10000000000")




    this.poolV2 = await this.IncentivePoolV2.deploy(this.usdt2.target, this.poolV1.target)
    console.log(`IncentivePoolV2 address: ${this.poolV2.target}`)

    const startTime1 = await this.poolV1.startTime()
    console.log(`Start time pool 1: ${startTime1}`)
    const startTime2 = await this.poolV2.startTime()
    console.log(`Start time pool 2: ${startTime2}`)
    expect(startTime1).to.equal(startTime2)

    const claimableTime1 = await this.poolV1.claimableTime()
    console.log(`Claimable time pool 1: ${startTime1}`)
    const claimableTim2 = await this.poolV2.claimableTime()
    console.log(`Claimable time pool 2: ${claimableTim2}`)
    expect(claimableTime1).to.equal(claimableTim2)

    const endTime1 = await this.poolV1.endTime()
    console.log(`End time pool 1: ${endTime1}`)
    const endTime2 = await this.poolV2.endTime()
    console.log(`End time pool 2: ${endTime2}`)
    expect(endTime1).to.equal(endTime2)

    const totalPool1Staked = await this.poolV1.totalPoolStaked()
    console.log(`Total staked pool 1: ${totalPool1Staked}`)
    const totalPool2Staked = await this.poolV2.totalPoolStaked()
    console.log(`Total staked pool 2: ${totalPool2Staked}`)
    expect(totalPool1Staked).to.equal(totalPool2Staked)

  })

  it("Incentive pool migration", async function () {
    let pool1Balance = await this.usdt1.balanceOf(this.poolV1.target)
    console.log(`Pool 1 USDT1 balance: ${pool1Balance}`)

    // BOB usdt2 balance
    await this.usdt2.transfer(this.bobAddr, "10000000000")
    let bobUSDT2Balance = await this.usdt2.balanceOf(this.bobAddr)
    console.log(`BOB USDT 2 balance: ${bobUSDT2Balance}`)

    // BoB staking to v2
    await this.usdt2.connect(this.bob).approve(this.poolV2.target, "10000000000")
    await this.poolV2.connect(this.bob).stake("10000000000")

    bobUSDT2Balance = await this.usdt2.balanceOf(this.bobAddr)
    console.log(`BOB USDT 2 balance: ${bobUSDT2Balance}`)

    await increaseTime(3600*24*90 + 300)


    // Send usdt2 to pool 2
    await this.usdt2.transfer(this.poolV2.target, "10000000000")
    let pool2USDT2Balance = await this.usdt2.balanceOf(this.poolV2.target)
    console.log(`POOL 2 USDT 2 balance: ${pool2USDT2Balance}`)

    await this.poolV2.connect(this.bob).legacyPoolUnstake()

    bobUSDT2Balance = await this.usdt2.balanceOf(this.bobAddr)
    console.log(`BOB USDT 2 balance: ${bobUSDT2Balance}`)

    await this.poolV2.connect(this.bob).unstake()

    bobUSDT2Balance = await this.usdt2.balanceOf(this.bobAddr)
    console.log(`BOB USDT 2 balance: ${bobUSDT2Balance}`)

    
  })
});


async function increaseTime(seconds: number) {
  await ethers.provider.send("evm_increaseTime", [seconds]);
  await ethers.provider.send("evm_mine", []);
}