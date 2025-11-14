const { ethers } = require("hardhat");

async function main() {
    console.log("开始部署 StrategyVault 系统...\n");

    const [deployer] = await ethers.getSigners();
    console.log("部署账户:", deployer.address);
    console.log("账户余额:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH\n");

    // 配置参数
    const unlockLockPeriod = 7 * 24 * 60 * 60; // 7天
    const strategyConfigs = [
        {
            name: "Quanter ETH Long Strategy",
            symbol: "QES-ETH-LONG",
            strategySymbol: "ETH-PERP-LONG",
            description: "以太坊永续合约做多策略"
        },
        {
            name: "Quanter BTC Long Strategy",
            symbol: "QES-BTC-LONG",
            strategySymbol: "BTC-PERP-LONG",
            description: "比特币永续合约做多策略"
        },
        {
            name: "Quanter SOL Long Strategy",
            symbol: "QES-SOL-LONG",
            strategySymbol: "SOL-PERP-LONG",
            description: "Solana永续合约做多策略"
        }
    ];

    // 1. 部署 MockUSDC（仅测试网）
    console.log("1. 部署 MockUSDC...");
    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    const mockUSDC = await MockUSDC.deploy();
    await mockUSDC.waitForDeployment();
    const mockUSDCAddress = await mockUSDC.getAddress();
    console.log("MockUSDC 部署地址:", mockUSDCAddress);
    console.log("✓ MockUSDC 部署成功\n");

    // 2. 部署 StrategyVault 实现合约
    console.log("2. 部署 StrategyVault 实现合约...");
    const StrategyVault = await ethers.getContractFactory("StrategyVault");
    const implementation = await StrategyVault.deploy(unlockLockPeriod);
    await implementation.waitForDeployment();
    const implementationAddress = await implementation.getAddress();
    console.log("StrategyVault 实现合约地址:", implementationAddress);
    console.log("解锁锁定期:", unlockLockPeriod / (24 * 60 * 60), "天");
    console.log("✓ StrategyVault 实现合约部署成功\n");

    // 3. 部署 StrategyVaultFactory
    console.log("3. 部署 StrategyVaultFactory...");
    const StrategyVaultFactory = await ethers.getContractFactory("StrategyVaultFactory");
    const factory = await StrategyVaultFactory.deploy(
        implementationAddress,
        unlockLockPeriod
    );
    await factory.waitForDeployment();
    const factoryAddress = await factory.getAddress();
    console.log("StrategyVaultFactory 地址:", factoryAddress);
    console.log("✓ StrategyVaultFactory 部署成功\n");

    // 4. 通过 Factory 创建多个策略 Vault
    console.log("4. 创建策略 Vault...");
    const endTime = Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60); // 1年后
    const admin = deployer.address;
    const manager = deployer.address; // 在生产环境中应该是不同的地址

    const vaultAddresses = [];

    for (let i = 0; i < strategyConfigs.length; i++) {
        const config = strategyConfigs[i];
        console.log(`\n创建策略 ${i + 1}/${strategyConfigs.length}: ${config.description}`);
        console.log(`- 名称: ${config.name}`);
        console.log(`- 符号: ${config.symbol}`);
        console.log(`- 策略符号: ${config.strategySymbol}`);

        const tx = await factory.createVault(
            admin,
            manager,
            mockUSDCAddress,
            config.name,
            config.symbol,
            config.strategySymbol,
            endTime
        );

        await tx.wait();

        const vaultAddress = await factory.symbolVault(config.strategySymbol);
        vaultAddresses.push({
            ...config,
            address: vaultAddress
        });

        console.log(`✓ Vault 地址: ${vaultAddress}`);
    }

    console.log("\n\n" + "=".repeat(80));
    console.log("部署总结");
    console.log("=".repeat(80));
    console.log("\n核心合约:");
    console.log("- MockUSDC:", mockUSDCAddress);
    console.log("- StrategyVault 实现合约:", implementationAddress);
    console.log("- StrategyVaultFactory:", factoryAddress);

    console.log("\n创建的策略 Vault:");
    vaultAddresses.forEach((vault, index) => {
        console.log(`\n${index + 1}. ${vault.name}`);
        console.log(`   策略符号: ${vault.strategySymbol}`);
        console.log(`   地址: ${vault.address}`);
    });

    console.log("\n管理员配置:");
    console.log("- Admin:", admin);
    console.log("- Manager:", manager);

    console.log("\n参数配置:");
    console.log("- 解锁锁定期:", unlockLockPeriod / (24 * 60 * 60), "天");
    console.log("- 策略结束时间:", new Date(endTime * 1000).toLocaleString());

    console.log("\n" + "=".repeat(80));
    console.log("部署完成!");
    console.log("=".repeat(80));

    // 保存部署信息到文件
    const fs = require('fs');
    const deploymentInfo = {
        network: (await ethers.provider.getNetwork()).name,
        chainId: (await ethers.provider.getNetwork()).chainId.toString(),
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        contracts: {
            mockUSDC: mockUSDCAddress,
            strategyVaultImplementation: implementationAddress,
            strategyVaultFactory: factoryAddress
        },
        vaults: vaultAddresses,
        config: {
            unlockLockPeriod,
            endTime,
            admin,
            manager
        }
    };

    const outputPath = `./deployments/deployment-${Date.now()}.json`;
    if (!fs.existsSync('./deployments')) {
        fs.mkdirSync('./deployments');
    }
    fs.writeFileSync(outputPath, JSON.stringify(deploymentInfo, null, 2));
    console.log(`\n部署信息已保存到: ${outputPath}`);

    // 返回部署地址供验证使用
    return {
        mockUSDC: mockUSDCAddress,
        implementation: implementationAddress,
        factory: factoryAddress,
        vaults: vaultAddresses
    };
}

// 执行部署
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = main;
