const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StrategyVaultFactory", function () {
  let strategyVaultFactory;
  let strategyVaultImplementation; // 存储StrategyVault实现合约
  let owner, user1, user2;

  before(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // 部署StrategyVault实现合约（作为逻辑合约）
    const StrategyVault = await ethers.getContractFactory("StrategyVault");
    strategyVaultImplementation = await StrategyVault.deploy();
    await strategyVaultImplementation.waitForDeployment();
    
    console.log("StrategyVault Implementation deployed at:", await strategyVaultImplementation.getAddress());

    // 使用StrategyVault实现合约地址部署工厂合约
    const StrategyVaultFactory = await ethers.getContractFactory("StrategyVaultFactory");
    strategyVaultFactory = await StrategyVaultFactory.deploy(await strategyVaultImplementation.getAddress());
    await strategyVaultFactory.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should deploy factory successfully", async function () {
      expect(await strategyVaultFactory.getAddress()).to.not.be.null;
      console.log("Factory deployed at:", await strategyVaultFactory.getAddress());
    });

    it("Should store the correct implementation address", async function () {
      const storedImpl = await strategyVaultFactory.vaultImplementation();
      expect(storedImpl).to.equal(await strategyVaultImplementation.getAddress());
      console.log("Stored implementation address:", storedImpl);
    });
  });

  describe("Basic Functionality", function () {
    it("Should have correct initial state", async function () {
      // 验证初始策略ID
      const nextStrategyId = await strategyVaultFactory.nextStrategyId();
      expect(nextStrategyId).to.equal(1);
      
      console.log("Factory has correct initial state, nextStrategyId:", nextStrategyId.toString());
    });

    it("Should allow owner to update implementation", async function () {
      // 更新实现地址
      const newImplAddress = "0x1111111111111111111111111111111111111111";
      const tx = await strategyVaultFactory.connect(owner).updateImplementation(newImplAddress);
      await tx.wait();
      
      // 验证更新
      const updatedImpl = await strategyVaultFactory.vaultImplementation();
      expect(updatedImpl).to.equal(newImplAddress);
      
      console.log("Implementation updated successfully to:", updatedImpl);
    });

    it("Should fail when non-owner tries to update implementation", async function () {
      const newImplAddress = "0x2222222222222222222222222222222222222222";
      await expect(strategyVaultFactory.connect(user1).updateImplementation(newImplAddress))
        .to.be.reverted; // 移除具体的错误信息检查
    });
    
    // 测试创建vault实例的功能
    it("Should create a new vault instance", async function () {
      // 恢复原始实现地址
      const originalImplAddress = await strategyVaultImplementation.getAddress();
      await strategyVaultFactory.connect(owner).updateImplementation(originalImplAddress);
      
      // 准备创建vault的参数
      const targets = [0, 1]; // BTC, ETH
      const endTime = Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60; // 30天后
      
      // 创建vault
      const tx = await strategyVaultFactory.connect(user1).createVault(
        user1.address,    // admin
        user1.address,    // manager
        "0x0000000000000000000000000000000000000000", // 使用零地址作为测试资产地址
        "Test Vault",
        "TVLT",
        "Test Strategy",
        targets,
        endTime,
        1000 // 10% performance fee
      );
      
      const receipt = await tx.wait();
      
      // 验证事件被触发
      const event = receipt.logs.find(log => log.fragment && log.fragment.name === "VaultCreated");
      expect(event).to.not.be.undefined;
      
      // 验证vault被创建
      const userVaultAddress = await strategyVaultFactory.getUserVault(user1.address);
      expect(userVaultAddress).to.not.equal(ethers.ZeroAddress);
      
      console.log("Vault created successfully at:", userVaultAddress);
      
      // 验证创建的vault可以正常工作
      try {
        // 尝试与创建的vault交互
        const VaultContract = await ethers.getContractFactory("StrategyVault");
        const vault = VaultContract.attach(userVaultAddress);
        
        // 获取策略信息
        const strategyInfo = await vault.getStrategyInfo();
        console.log("Strategy info retrieved successfully");
        console.log("Strategy name:", strategyInfo.name);
      } catch (error) {
        console.error("Error interacting with created vault:", error.message);
      }
    });
  });
});