const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("StrategyVault", function () {
  let strategyVault;
  let mockUSDC;
  let owner, admin, manager, user1, user2;

  const strategyId = 1;
  const strategyName = "Test Strategy";
  const vaultName = "Test Vault";
  const vaultSymbol = "TVLT";
  const endTime = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60; // 一年后
  const performanceFeeRate = 1000; // 10%
  const investmentTargets = [0, 1, 2]; // BTC, ETH, SOL

  beforeEach(async function () {
    [owner, admin, manager, user1, user2] = await ethers.getSigners();

    // 部署MockUSDC代币
    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    mockUSDC = await MockUSDC.deploy();
    await mockUSDC.waitForDeployment();

    // 部署并初始化StrategyVault
    const StrategyVault = await ethers.getContractFactory("StrategyVault");
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
  });

  describe("Deployment", function () {
    it("Should set the right admin and manager", async function () {
      // 检查角色分配
      const DEFAULT_ADMIN_ROLE = ethers.ZeroHash;
      const MANAGER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MANAGER"));
      
      expect(await strategyVault.hasRole(DEFAULT_ADMIN_ROLE, admin.address)).to.be.true;
      expect(await strategyVault.hasRole(MANAGER_ROLE, manager.address)).to.be.true;
    });

    it("Should set the correct strategy info", async function () {
      const strategyInfo = await strategyVault.getStrategyInfo();
      expect(strategyInfo.Id).to.equal(strategyId);
      expect(strategyInfo.name).to.equal(strategyName);
      expect(strategyInfo.tvl).to.equal(0);
    });
  });

  describe("Deposit", function () {
    const depositAmount = ethers.parseUnits("100", 6); // 100 USDC (6 decimals)

    beforeEach(async function () {
      // 为用户铸造代币
      await mockUSDC.mint(user1.address, depositAmount);
      // 用户授权合约使用代币
      await mockUSDC.connect(user1).approve(await strategyVault.getAddress(), depositAmount);
    });

    it("Should allow user to deposit assets", async function () {
      const vaultAddress = await strategyVault.getAddress();
      
      // 检查存款前余额
      const userBalanceBefore = await mockUSDC.balanceOf(user1.address);
      const vaultBalanceBefore = await mockUSDC.balanceOf(vaultAddress);

      // 执行存款
      await expect(strategyVault.connect(user1).deposit(strategyId, await mockUSDC.getAddress(), depositAmount))
        .to.emit(strategyVault, "Deposit")
        .withArgs(user1.address, strategyId, await mockUSDC.getAddress(), depositAmount);

      // 检查存款后余额
      const userBalanceAfter = await mockUSDC.balanceOf(user1.address);
      const vaultBalanceAfter = await mockUSDC.balanceOf(vaultAddress);
      const strategyInfo = await strategyVault.getStrategyInfo();

      expect(userBalanceAfter).to.equal(userBalanceBefore - depositAmount);
      expect(vaultBalanceAfter).to.equal(vaultBalanceBefore + depositAmount);
      expect(strategyInfo.tvl).to.equal(depositAmount);

      // 检查用户资产
      const userAsset = await strategyVault.connect(user1).getUserAsset();
      expect(userAsset.totalAmount).to.equal(depositAmount);
      expect(userAsset.strategyId).to.equal(strategyId);
    });

    it("Should fail to deposit with zero amount", async function () {
      await expect(strategyVault.connect(user1).deposit(strategyId, await mockUSDC.getAddress(), 0))
        .to.be.revertedWithCustomError(strategyVault, "ZeroAmount");
    });

    it("Should fail to deposit with insufficient allowance", async function () {
      // 授权少于存款金额
      await mockUSDC.connect(user1).approve(await strategyVault.getAddress(), depositAmount / 2n);
      
      await expect(strategyVault.connect(user1).deposit(strategyId, await mockUSDC.getAddress(), depositAmount))
        .to.be.revertedWithCustomError(strategyVault, "NotEnoughAllowance");
    });

    it("Should fail to deposit with invalid asset", async function () {
      // 使用错误的资产地址
      await expect(strategyVault.connect(user1).deposit(strategyId, user2.address, depositAmount))
        .to.be.revertedWithCustomError(strategyVault, "InvalidAsset");
    });
  });

  describe("Withdraw", function () {
    const depositAmount = ethers.parseUnits("100", 6);
    const withdrawAmount = ethers.parseUnits("50", 6);

    beforeEach(async function () {
      // 为用户铸造代币并存款
      await mockUSDC.mint(user1.address, depositAmount);
      await mockUSDC.connect(user1).approve(await strategyVault.getAddress(), depositAmount);
      await strategyVault.connect(user1).deposit(strategyId, await mockUSDC.getAddress(), depositAmount);
    });

    it("Should fail to withdraw with zero amount", async function () {
      await expect(strategyVault.connect(user1).withdraw(strategyId, 0))
        .to.be.revertedWithCustomError(strategyVault, "ZeroAmount");
    });

    it("Should fail to withdraw with invalid strategy ID", async function () {
      await expect(strategyVault.connect(user1).withdraw(999, withdrawAmount))
        .to.be.revertedWithCustomError(strategyVault, "InvalidStrategyId");
    });

    it("Should fail to withdraw more than available", async function () {
      // 用户尝试提取超过其未锁定资产的数量
      const userAsset = await strategyVault.connect(user1).getUserAsset();
      const excessiveAmount = userAsset.totalAmount + 1n;
      
      await expect(strategyVault.connect(user1).withdraw(strategyId, excessiveAmount))
        .to.be.revertedWithCustomError(strategyVault, "NotEnoughWithdrawableAssets");
    });
  });

  describe("Admin Functions", function () {
    const depositAmount = ethers.parseUnits("100", 6);
    const adminWithdrawAmount = ethers.parseUnits("50", 6);

    beforeEach(async function () {
      // 为用户铸造代币并存款
      await mockUSDC.mint(user1.address, depositAmount);
      await mockUSDC.connect(user1).approve(await strategyVault.getAddress(), depositAmount);
      await strategyVault.connect(user1).deposit(strategyId, await mockUSDC.getAddress(), depositAmount);
    });

    it("Should allow manager to withdraw assets", async function () {
      const vaultAddress = await strategyVault.getAddress();
      
      // 检查提取前余额
      const managerBalanceBefore = await mockUSDC.balanceOf(manager.address);
      const vaultBalanceBefore = await mockUSDC.balanceOf(vaultAddress);

      // 管理员提取资产
      await expect(strategyVault.connect(manager).adminWithdraw(strategyId, await mockUSDC.getAddress(), adminWithdrawAmount))
        .to.not.be.reverted;

      // 检查提取后余额
      const managerBalanceAfter = await mockUSDC.balanceOf(manager.address);
      const vaultBalanceAfter = await mockUSDC.balanceOf(vaultAddress);

      expect(managerBalanceAfter).to.equal(managerBalanceBefore + adminWithdrawAmount);
      expect(vaultBalanceAfter).to.equal(vaultBalanceBefore - adminWithdrawAmount);
    });

    it("Should fail when non-manager tries to withdraw assets", async function () {
      await expect(strategyVault.connect(user1).adminWithdraw(strategyId, await mockUSDC.getAddress(), adminWithdrawAmount))
        .to.be.reverted;
    });

    it("Should fail to withdraw with zero amount", async function () {
      await expect(strategyVault.connect(manager).adminWithdraw(strategyId, await mockUSDC.getAddress(), 0))
        .to.be.revertedWithCustomError(strategyVault, "ZeroAmount");
    });

    it("Should fail to withdraw with invalid asset", async function () {
      await expect(strategyVault.connect(manager).adminWithdraw(strategyId, user2.address, adminWithdrawAmount))
        .to.be.revertedWithCustomError(strategyVault, "InvalidAsset");
    });
  });
});