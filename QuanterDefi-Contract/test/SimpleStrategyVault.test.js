const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Simple StrategyVault Test", function () {
  let strategyVault;
  let mockUSDC;
  let owner, admin, manager, user1;

  beforeEach(async function () {
    [owner, admin, manager, user1] = await ethers.getSigners();

    // 部署MockUSDC代币
    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    mockUSDC = await MockUSDC.deploy();
    await mockUSDC.waitForDeployment();

    console.log("MockUSDC deployed to:", await mockUSDC.getAddress());
  });

  it("Should deploy StrategyVault implementation with initialization", async function () {
    // 部署StrategyVault实现合约
    const StrategyVault = await ethers.getContractFactory("StrategyVault");
    
    const strategyId = 1;
    const strategyName = "Test Strategy";
    const vaultName = "Test Vault";
    const vaultSymbol = "TVLT";
    const endTime = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60; // 一年后
    const performanceFeeRate = 1000; // 10%
    const investmentTargets = [0, 1, 2]; // BTC, ETH, SOL
    
    // 使用deployProxy部署可升级合约并初始化
    strategyVault = await upgrades.deployProxy(StrategyVault, [
      admin.address,
      manager.address,
      await mockUSDC.getAddress(),
      vaultName,
      vaultSymbol,
      strategyId,
      strategyName,
      investmentTargets,
      endTime,
      performanceFeeRate
    ], {
      kind: "uups"
    });
    
    await strategyVault.waitForDeployment();
    console.log("StrategyVault deployed to:", await strategyVault.getAddress());
    
    // 检查是否正确初始化
    const strategyInfo = await strategyVault.getStrategyInfo();
    console.log("Strategy info ID:", strategyInfo.Id.toString());
    console.log("Strategy name:", strategyInfo.name);
    expect(strategyInfo.Id).to.equal(strategyId);
    expect(strategyInfo.name).to.equal(strategyName);
  });
});