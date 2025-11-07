const { expect } = require("chai");
const { ethers } = require("hardhat");
const { upgrades } = require("hardhat");

describe("Counter", function () {
  let counter;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    // 获取签名者
    [owner, addr1, addr2] = await ethers.getSigners();
    
    // 部署可升级合约
    const Counter = await ethers.getContractFactory("Counter");
    counter = await upgrades.deployProxy(Counter, { initializer: 'initialize' });
    await counter.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the initial count to 0", async function () {
      expect(await counter.count()).to.equal(0);
    });

    it("Should set the owner correctly", async function () {
      expect(await counter.owner()).to.equal(owner.address);
    });
  });

  describe("Increment", function () {
    it("Should increment the counter", async function () {
      await counter.increment();
      expect(await counter.count()).to.equal(1);
      
      await counter.increment();
      expect(await counter.count()).to.equal(2);
    });

    it("Should emit CountIncremented event", async function () {
      await expect(counter.increment())
        .to.emit(counter, "CountIncremented")
        .withArgs(1, owner.address);
    });

    it("Should allow anyone to increment", async function () {
      await counter.connect(addr1).increment();
      expect(await counter.count()).to.equal(1);
    });
  });

  describe("Decrement", function () {
    it("Should decrement the counter when called by owner", async function () {
      await counter.increment();
      await counter.increment();
      expect(await counter.count()).to.equal(2);
      
      await counter.decrement();
      expect(await counter.count()).to.equal(1);
    });

    it("Should fail to decrement when called by non-owner", async function () {
      await counter.increment();
      await expect(counter.connect(addr1).decrement())
        .to.be.revertedWithCustomError(counter, "OwnableUnauthorizedAccount")
        .withArgs(addr1.address);
    });

    it("Should fail to decrement below zero", async function () {
      await expect(counter.decrement())
        .to.be.revertedWith("Counter: cannot decrement below zero");
    });

    it("Should emit CountDecremented event", async function () {
      await counter.increment();
      await expect(counter.decrement())
        .to.emit(counter, "CountDecremented")
        .withArgs(0, owner.address);
    });
  });

  describe("Reset", function () {
    it("Should reset the counter to zero when called by owner", async function () {
      await counter.increment();
      await counter.increment();
      expect(await counter.count()).to.equal(2);
      
      await counter.reset();
      expect(await counter.count()).to.equal(0);
    });

    it("Should fail to reset when called by non-owner", async function () {
      await expect(counter.connect(addr1).reset())
        .to.be.revertedWithCustomError(counter, "OwnableUnauthorizedAccount")
        .withArgs(addr1.address);
    });

    it("Should emit CountReset event", async function () {
      await counter.increment();
      await expect(counter.reset())
        .to.emit(counter, "CountReset")
        .withArgs(owner.address);
    });
  });

  describe("Upgrade", function () {
    it("Should upgrade the contract correctly", async function () {
      // 获取当前实现地址
      const currentImplAddress = await upgrades.erc1967.getImplementationAddress(await counter.getAddress());
      
      // 部署新版本合约
      const CounterV2 = await ethers.getContractFactory("Counter");
      const upgradedCounter = await upgrades.upgradeProxy(counter, CounterV2);
      
      // 检查实现地址是否改变
      const newImplAddress = await upgrades.erc1967.getImplementationAddress(await upgradedCounter.getAddress());
      
      // 由于是同一个合约，实现地址应该相同
      expect(newImplAddress).to.equal(currentImplAddress);
      
      // 确保状态保持不变
      expect(await upgradedCounter.count()).to.equal(0);
    });
  });
});