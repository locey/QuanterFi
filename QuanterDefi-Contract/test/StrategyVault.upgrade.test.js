const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("StrategyVault 升级测试", function () {
    let strategyVault;
    let mockUSDC;
    let owner, admin, manager, user1;
    let unlockLockPeriod = 7 * 24 * 60 * 60; // 7天
    let proxyAddress;

    beforeEach(async function () {
        [owner, admin, manager, user1] = await ethers.getSigners();

        // 部署 MockUSDC
        const MockUSDC = await ethers.getContractFactory("MockUSDC");
        mockUSDC = await MockUSDC.deploy();
        await mockUSDC.waitForDeployment();

        // 部署初始版本的 StrategyVault
        const StrategyVault = await ethers.getContractFactory("StrategyVault");
        const implementation = await StrategyVault.deploy(unlockLockPeriod);
        await implementation.waitForDeployment();

        // 部署代理合约
        const ERC1967Proxy = await ethers.getContractFactory("ERC1967Proxy");
        const endTime = (await time.latest()) + 365 * 24 * 60 * 60;
        
        const initData = implementation.interface.encodeFunctionData("initialize", [
            admin.address,
            manager.address,
            "Quanter Strategy Vault",
            "QSV",
            "ETH-PERP",
            await mockUSDC.getAddress(),
            endTime
        ]);

        const proxy = await ERC1967Proxy.deploy(await implementation.getAddress(), initData);
        await proxy.waitForDeployment();

        proxyAddress = await proxy.getAddress();
        strategyVault = await ethers.getContractAt("StrategyVault", proxyAddress);

        // 给用户铸造代币并存款
        await mockUSDC.mint(user1.address, ethers.parseUnits("10000", 6));
        await mockUSDC.connect(user1).approve(proxyAddress, ethers.parseUnits("1000", 6));
        await strategyVault.connect(user1).deposit(ethers.parseUnits("1000", 6));
    });

    describe("UUPS 升级功能测试", function () {
        it("应该能够获取当前实现合约地址", async function () {
            const implementationSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
            const implementationAddress = await ethers.provider.getStorage(proxyAddress, implementationSlot);
            
            expect(ethers.getAddress("0x" + implementationAddress.slice(-40))).to.not.equal(ethers.ZeroAddress);
        });

        it("只有 DEFAULT_ADMIN_ROLE 才能升级合约", async function () {
            // 部署新版本实现
            const StrategyVaultV2 = await ethers.getContractFactory("StrategyVault");
            const newImplementation = await StrategyVaultV2.deploy(unlockLockPeriod);
            await newImplementation.waitForDeployment();

            // 非管理员尝试升级应该失败
            await expect(
                strategyVault.connect(manager).upgradeToAndCall(await newImplementation.getAddress(), "0x")
            ).to.be.reverted;

            // 管理员升级应该成功
            await strategyVault.connect(admin).upgradeToAndCall(await newImplementation.getAddress(), "0x");
        });

        it("升级后应该保持原有数据", async function () {
            // 记录升级前的数据
            const userAssetBefore = await strategyVault.userAssets(user1.address);
            const tvlBefore = await strategyVault.tvl();
            const strategySymbolBefore = await strategyVault.strategySymbol();

            // 部署新版本
            const StrategyVaultV2 = await ethers.getContractFactory("StrategyVault");
            const newImplementation = await StrategyVaultV2.deploy(unlockLockPeriod);
            await newImplementation.waitForDeployment();

            // 升级
            await strategyVault.connect(admin).upgradeToAndCall(await newImplementation.getAddress(), "0x");

            // 重新获取合约实例
            const upgradedVault = await ethers.getContractAt("StrategyVault", proxyAddress);

            // 验证数据保持不变
            const userAssetAfter = await upgradedVault.userAssets(user1.address);
            const tvlAfter = await upgradedVault.tvl();
            const strategySymbolAfter = await upgradedVault.strategySymbol();

            expect(userAssetAfter.totalAmount).to.equal(userAssetBefore.totalAmount);
            expect(tvlAfter).to.equal(tvlBefore);
            expect(strategySymbolAfter).to.equal(strategySymbolBefore);
        });

        it("升级后原有功能应该继续工作", async function () {
            // 部署新版本并升级
            const StrategyVaultV2 = await ethers.getContractFactory("StrategyVault");
            const newImplementation = await StrategyVaultV2.deploy(unlockLockPeriod);
            await newImplementation.waitForDeployment();

            await strategyVault.connect(admin).upgradeToAndCall(await newImplementation.getAddress(), "0x");

            const upgradedVault = await ethers.getContractAt("StrategyVault", proxyAddress);

            // 测试存款功能
            await mockUSDC.connect(user1).approve(proxyAddress, ethers.parseUnits("500", 6));
            await upgradedVault.connect(user1).deposit(ethers.parseUnits("500", 6));

            const userAsset = await upgradedVault.userAssets(user1.address);
            expect(userAsset.totalAmount).to.equal(ethers.parseUnits("1500", 6));
        });

        it("升级后角色权限应该保持", async function () {
            const StrategyVaultV2 = await ethers.getContractFactory("StrategyVault");
            const newImplementation = await StrategyVaultV2.deploy(unlockLockPeriod);
            await newImplementation.waitForDeployment();

            await strategyVault.connect(admin).upgradeToAndCall(await newImplementation.getAddress(), "0x");

            const upgradedVault = await ethers.getContractAt("StrategyVault", proxyAddress);

            const DEFAULT_ADMIN_ROLE = await upgradedVault.DEFAULT_ADMIN_ROLE();
            const MANAGER = await upgradedVault.MANAGER();

            expect(await upgradedVault.hasRole(DEFAULT_ADMIN_ROLE, admin.address)).to.be.true;
            expect(await upgradedVault.hasRole(MANAGER, manager.address)).to.be.true;
        });
    });

    describe("多次升级测试", function () {
        it("应该支持连续多次升级", async function () {
            const StrategyVaultV2 = await ethers.getContractFactory("StrategyVault");
            
            // 第一次升级
            const implementation2 = await StrategyVaultV2.deploy(unlockLockPeriod);
            await implementation2.waitForDeployment();
            await strategyVault.connect(admin).upgradeToAndCall(await implementation2.getAddress(), "0x");

            // 第二次升级
            const implementation3 = await StrategyVaultV2.deploy(unlockLockPeriod);
            await implementation3.waitForDeployment();
            
            const vault2 = await ethers.getContractAt("StrategyVault", proxyAddress);
            await vault2.connect(admin).upgradeToAndCall(await implementation3.getAddress(), "0x");

            // 第三次升级
            const implementation4 = await StrategyVaultV2.deploy(unlockLockPeriod);
            await implementation4.waitForDeployment();
            
            const vault3 = await ethers.getContractAt("StrategyVault", proxyAddress);
            await vault3.connect(admin).upgradeToAndCall(await implementation4.getAddress(), "0x");

            // 验证数据仍然保持
            const finalVault = await ethers.getContractAt("StrategyVault", proxyAddress);
            const userAsset = await finalVault.userAssets(user1.address);
            expect(userAsset.totalAmount).to.equal(ethers.parseUnits("1000", 6));
        });
    });

    describe("Factory 创建的 Vault 升级测试", function () {
        let factory;
        let vaultAddress;

        beforeEach(async function () {
            // 部署新的实现合约
            const StrategyVault = await ethers.getContractFactory("StrategyVault");
            const implementation = await StrategyVault.deploy(unlockLockPeriod);
            await implementation.waitForDeployment();

            // 部署 Factory
            const StrategyVaultFactory = await ethers.getContractFactory("StrategyVaultFactory");
            factory = await StrategyVaultFactory.deploy(
                await implementation.getAddress(),
                unlockLockPeriod
            );
            await factory.waitForDeployment();

            // 通过 Factory 创建 Vault
            const endTime = (await time.latest()) + 365 * 24 * 60 * 60;
            await factory.createVault(
                admin.address,
                manager.address,
                await mockUSDC.getAddress(),
                "Quanter Strategy",
                "QS",
                "TEST-PERP",
                endTime
            );

            vaultAddress = await factory.symbolVault("TEST-PERP");
        });

        it("Factory 创建的 Vault 应该可以升级", async function () {
            const vault = await ethers.getContractAt("StrategyVault", vaultAddress);

            // 用户存款
            await mockUSDC.connect(user1).approve(vaultAddress, ethers.parseUnits("1000", 6));
            await vault.connect(user1).deposit(ethers.parseUnits("1000", 6));

            // 部署新实现
            const StrategyVaultV2 = await ethers.getContractFactory("StrategyVault");
            const newImplementation = await StrategyVaultV2.deploy(unlockLockPeriod);
            await newImplementation.waitForDeployment();

            // 升级
            await vault.connect(admin).upgradeToAndCall(await newImplementation.getAddress(), "0x");

            // 验证升级后数据保持
            const upgradedVault = await ethers.getContractAt("StrategyVault", vaultAddress);
            const userAsset = await upgradedVault.userAssets(user1.address);
            expect(userAsset.totalAmount).to.equal(ethers.parseUnits("1000", 6));
        });

        it("Factory 更新实现后，新创建的 Vault 应该使用新实现", async function () {
            // 部署新实现
            const StrategyVaultV2 = await ethers.getContractFactory("StrategyVault");
            const newImplementation = await StrategyVaultV2.deploy(unlockLockPeriod);
            await newImplementation.waitForDeployment();

            // 更新 Factory 的实现合约
            await factory.updateImplementation(await newImplementation.getAddress());

            // 创建新的 Vault
            const endTime = (await time.latest()) + 365 * 24 * 60 * 60;
            await factory.createVault(
                admin.address,
                manager.address,
                await mockUSDC.getAddress(),
                "New Strategy",
                "NS",
                "NEW-PERP",
                endTime
            );

            const newVaultAddress = await factory.symbolVault("NEW-PERP");
            const newVault = await ethers.getContractAt("StrategyVault", newVaultAddress);

            // 验证新 Vault 可以正常工作
            await mockUSDC.connect(user1).approve(newVaultAddress, ethers.parseUnits("500", 6));
            await newVault.connect(user1).deposit(ethers.parseUnits("500", 6));

            const userAsset = await newVault.userAssets(user1.address);
            expect(userAsset.totalAmount).to.equal(ethers.parseUnits("500", 6));
        });
    });
});
