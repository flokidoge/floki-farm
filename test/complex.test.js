const { expectRevert } = require("@openzeppelin/test-helpers");
const { assert } = require("chai");

// const FlokiToken = artifacts.require('FlokiToken');
// const MasterChef = artifacts.require('MasterChef');

// const { expect } = require("chai");

describe("Floki Bug", function() {
  it("Should return the new greeting once it's changed", async function() {
    this.timeout(0);
    const accounts = await hre.ethers.getSigners();
    const FlokiToken = await hre.ethers.getContractFactory("FlokiToken");
    const pt = await FlokiToken.deploy();
    await pt.deployed();
    console.log("FlokiToken contract deployed to:", pt.address);
    const MasterChef = await hre.ethers.getContractFactory("MasterChef");
    const mc = await MasterChef.deploy(pt.address, 0, hre.ethers.utils.parseEther("2800"));
    await mc.deployed();
    console.log("masterchef contract deployed to:", mc.address);
    const Referal = await hre.ethers.getContractFactory("FlokiReferral");
    const r = await Referal.deploy();
    await r.deployed();
    console.log("Referal contract deployed to:", r.address);
    let tx = await mc.setFlokiReferral(r.address);
    await tx.wait();
    let tx00 = await r.updateOperator(mc.address, true);
    await tx00.wait();
    let tx01 = await r.updateOperator(pt.address, true);
    await tx01.wait();
    let tx1 = await pt.transferOwnership(mc.address);
    await tx1.wait();
    let tx2 = await mc.add(1000, pt.address, 400, 1, true);
    await tx2.wait();
    let tx3 = await pt.approve(mc.address, hre.ethers.utils.parseEther("10000000000"));
    await tx3.wait();
    let tx4 = await mc.deposit(0, hre.ethers.utils.parseEther("100"), accounts[1].address);
    await tx4.wait();
    let tx7 = await mc.withdraw(0, hre.ethers.utils.parseEther("50"));
    await tx7.wait();
    console.log(await pt.balanceOf(accounts[1].address))
  });
});
