const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Basic StrategyVaultFactory Test", function () {
  it("Should deploy factory", async function () {
    // 获取测试账户
    const [owner, user1] = await ethers.getSigners();

    // 部署一个简单的合约作为实现
    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    const mockImpl = await MockUSDC.deploy();
    await mockImpl.waitForDeployment();

    // 部署工厂合约
    const StrategyVaultFactory = await ethers.getContractFactory("StrategyVaultFactory");
    const factory = await StrategyVaultFactory.deploy(mockImpl.address);
    await factory.waitForDeployment();

    console.log("Factory deployed at:", factory.address);
  });
});