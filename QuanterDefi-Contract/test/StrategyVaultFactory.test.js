const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("StrategyVaultFactory 完整测试", function () {
    let factory;
    let implementation;
    let mockUSDC, mockUSDT;
    let owner, admin, manager, user1;
    let unlockLockPeriod = 7 * 24 * 60 * 60; // 7天

    beforeEach(async function () {
        [owner, admin, manager, user1] = await ethers.getSigners();

        // 部署 Mock 代币
        const MockUSDC = await ethers.getContractFactory("MockUSDC");
        mockUSDC = await MockUSDC.deploy();
        await mockUSDC.waitForDeployment();

        mockUSDT = await MockUSDC.deploy();
        await mockUSDT.waitForDeployment();

        // 部署 StrategyVault 实现合约
        const StrategyVault = await ethers.getContractFactory("StrategyVault");
        implementation = await StrategyVault.deploy(unlockLockPeriod);
        await implementation.waitForDeployment();

        // 部署 Factory 合约
        const StrategyVaultFactory = await ethers.getContractFactory("StrategyVaultFactory");
        factory = await StrategyVaultFactory.deploy(
            await implementation.getAddress(),
            unlockLockPeriod
        );
        await factory.waitForDeployment();
    });

    describe("Factory 初始化测试", function () {
        it("应该正确初始化 Factory", async function () {
            expect(await factory.vaultImplementation()).to.equal(await implementation.getAddress());
            expect(await factory.unlockLockPeriod()).to.equal(unlockLockPeriod);
            expect(await factory.owner()).to.equal(owner.address);
        });

        it("应该拒绝零地址的实现合约", async function () {
            const StrategyVaultFactory = await ethers.getContractFactory("StrategyVaultFactory");
            await expect(
                StrategyVaultFactory.deploy(ethers.ZeroAddress, unlockLockPeriod)
            ).to.be.revertedWith("Invalid implementation address");
        });
    });

    describe("创建 Vault 测试", function () {
        it("应该成功创建第一个 Vault", async function () {
            const endTime = (await time.latest()) + 365 * 24 * 60 * 60;

            const tx = await factory.createVault(
                admin.address,
                manager.address,
                await mockUSDC.getAddress(),
                "Quanter ETH Strategy",
                "QES",
                "ETH-PERP-V1",
                endTime
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => {
                try {
                    return factory.interface.parseLog(log).name === "VaultCreated";
                } catch (e) {
                    return false;
                }
            });

            expect(event).to.not.be.undefined;
            
            const vaultAddress = await factory.symbolVault("ETH-PERP-V1");
            expect(vaultAddress).to.not.equal(ethers.ZeroAddress);

            const allVaults = await factory.getAllVaults();
            expect(allVaults.length).to.equal(1);
            expect(await factory.getVaultCount()).to.equal(1);
        });

        it("应该成功创建多个不同策略的 Vault", async function () {
            const endTime = (await time.latest()) + 365 * 24 * 60 * 60;

            // 创建第一个策略
            await factory.createVault(
                admin.address,
                manager.address,
                await mockUSDC.getAddress(),
                "Quanter ETH Strategy",
                "QES",
                "ETH-PERP-V1",
                endTime
            );

            // 创建第二个策略
            await factory.createVault(
                admin.address,
                manager.address,
                await mockUSDC.getAddress(),
                "Quanter BTC Strategy",
                "QBS",
                "BTC-PERP-V1",
                endTime
            );

            // 创建第三个策略（使用不同的代币）
            await factory.createVault(
                admin.address,
                manager.address,
                await mockUSDT.getAddress(),
                "Quanter SOL Strategy",
                "QSS",
                "SOL-PERP-V1",
                endTime
            );

            expect(await factory.getVaultCount()).to.equal(3);

            const vault1 = await factory.symbolVault("ETH-PERP-V1");
            const vault2 = await factory.symbolVault("BTC-PERP-V1");
            const vault3 = await factory.symbolVault("SOL-PERP-V1");

            expect(vault1).to.not.equal(ethers.ZeroAddress);
            expect(vault2).to.not.equal(ethers.ZeroAddress);
            expect(vault3).to.not.equal(ethers.ZeroAddress);
            expect(vault1).to.not.equal(vault2);
            expect(vault2).to.not.equal(vault3);
        });

        it("应该拒绝创建同名策略的 Vault", async function () {
            const endTime = (await time.latest()) + 365 * 24 * 60 * 60;

            await factory.createVault(
                admin.address,
                manager.address,
                await mockUSDC.getAddress(),
                "Quanter ETH Strategy",
                "QES",
                "ETH-PERP-V1",
                endTime
            );

            await expect(
                factory.createVault(
                    admin.address,
                    manager.address,
                    await mockUSDC.getAddress(),
                    "Another ETH Strategy",
                    "AES",
                    "ETH-PERP-V1", // 同名
                    endTime
                )
            ).to.be.revertedWith("Strategy symbol already exists");
        });

        it("应该拒绝无效的参数", async function () {
            const endTime = (await time.latest()) + 365 * 24 * 60 * 60;

            // 零地址 admin
            await expect(
                factory.createVault(
                    ethers.ZeroAddress,
                    manager.address,
                    await mockUSDC.getAddress(),
                    "Test",
                    "TST",
                    "TEST-V1",
                    endTime
                )
            ).to.be.revertedWith("Invalid admin address");

            // 零地址 manager
            await expect(
                factory.createVault(
                    admin.address,
                    ethers.ZeroAddress,
                    await mockUSDC.getAddress(),
                    "Test",
                    "TST",
                    "TEST-V1",
                    endTime
                )
            ).to.be.revertedWith("Invalid manager address");

            // 零地址 asset
            await expect(
                factory.createVault(
                    admin.address,
                    manager.address,
                    ethers.ZeroAddress,
                    "Test",
                    "TST",
                    "TEST-V1",
                    endTime
                )
            ).to.be.revertedWith("Invalid asset address");
        });
    });

    describe("创建的 Vault 功能验证", function () {
        let vaultAddress;
        let vault;

        beforeEach(async function () {
            const endTime = (await time.latest()) + 365 * 24 * 60 * 60;

            await factory.createVault(
                admin.address,
                manager.address,
                await mockUSDC.getAddress(),
                "Quanter ETH Strategy",
                "QES",
                "ETH-PERP-V1",
                endTime
            );

            vaultAddress = await factory.symbolVault("ETH-PERP-V1");
            vault = await ethers.getContractAt("StrategyVault", vaultAddress);
        });

        it("创建的 Vault 应该有正确的配置", async function () {
            expect(await vault.underlyingAsset()).to.equal(await mockUSDC.getAddress());
            expect(await vault.strategySymbol()).to.equal("ETH-PERP-V1");
            expect(await vault.name()).to.equal("Quanter ETH Strategy");
            expect(await vault.symbol()).to.equal("QES");
        });

        it("创建的 Vault 应该有正确的角色设置", async function () {
            const DEFAULT_ADMIN_ROLE = await vault.DEFAULT_ADMIN_ROLE();
            const MANAGER = await vault.MANAGER();

            expect(await vault.hasRole(DEFAULT_ADMIN_ROLE, admin.address)).to.be.true;
            expect(await vault.hasRole(MANAGER, manager.address)).to.be.true;
        });

        it("创建的 Vault 应该能正常使用", async function () {
            // 给用户铸造代币
            await mockUSDC.mint(user1.address, ethers.parseUnits("1000", 6));

            // 用户存款
            await mockUSDC.connect(user1).approve(vaultAddress, ethers.parseUnits("1000", 6));
            await vault.connect(user1).deposit(ethers.parseUnits("1000", 6));

            const userAsset = await vault.userAssets(user1.address);
            expect(userAsset.totalAmount).to.equal(ethers.parseUnits("1000", 6));
        });
    });

    describe("更新实现合约测试", function () {
        it("Owner 应该能更新实现合约", async function () {
            const StrategyVault = await ethers.getContractFactory("StrategyVault");
            const newImplementation = await StrategyVault.deploy(unlockLockPeriod);
            await newImplementation.waitForDeployment();

            await factory.updateImplementation(await newImplementation.getAddress());

            expect(await factory.vaultImplementation()).to.equal(await newImplementation.getAddress());
        });

        it("非 Owner 不应该能更新实现合约", async function () {
            const StrategyVault = await ethers.getContractFactory("StrategyVault");
            const newImplementation = await StrategyVault.deploy(unlockLockPeriod);
            await newImplementation.waitForDeployment();

            await expect(
                factory.connect(user1).updateImplementation(await newImplementation.getAddress())
            ).to.be.reverted;
        });

        it("应该拒绝零地址的新实现合约", async function () {
            await expect(
                factory.updateImplementation(ethers.ZeroAddress)
            ).to.be.revertedWith("Invalid implementation address");
        });
    });

    describe("批量创建 Vault 测试", function () {
        it("应该能够批量创建多个 Vault", async function () {
            const endTime = (await time.latest()) + 365 * 24 * 60 * 60;
            const strategies = [
                { name: "ETH Long", symbol: "ETH-LONG", strategySymbol: "ETH-PERP-LONG" },
                { name: "BTC Long", symbol: "BTC-LONG", strategySymbol: "BTC-PERP-LONG" },
                { name: "SOL Long", symbol: "SOL-LONG", strategySymbol: "SOL-PERP-LONG" },
                { name: "AVAX Long", symbol: "AVAX-LONG", strategySymbol: "AVAX-PERP-LONG" },
                { name: "MATIC Long", symbol: "MATIC-LONG", strategySymbol: "MATIC-PERP-LONG" },
            ];

            for (const strategy of strategies) {
                await factory.createVault(
                    admin.address,
                    manager.address,
                    await mockUSDC.getAddress(),
                    strategy.name,
                    strategy.symbol,
                    strategy.strategySymbol,
                    endTime
                );
            }

            expect(await factory.getVaultCount()).to.equal(5);

            const allVaults = await factory.getAllVaults();
            expect(allVaults.length).to.equal(5);

            // 验证每个 vault 都不同
            const uniqueAddresses = new Set(allVaults);
            expect(uniqueAddresses.size).to.equal(5);
        });
    });
});
