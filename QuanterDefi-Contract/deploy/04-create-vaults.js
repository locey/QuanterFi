const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
    const { get, log, execute } = deployments;
    const { deployer, admin, manager } = await getNamedAccounts();
    const chainId = await getChainId();

    // 只在本地网络和测试网创建策略实例
    if (chainId === "31337" || chainId === "11155111") {
        log("========================================");
        log("通过 Factory 创建策略 Vault 实例...");

        const factory = await get("StrategyVaultFactory");
        const mockUSDC = await get("MockUSDC");

        // 策略配置
        const strategies = [
            {
                name: "Quanter ETH Long Strategy",
                symbol: "QES-ETH-LONG",
                strategySymbol: "ETH-PERP-LONG",
            },
            {
                name: "Quanter BTC Long Strategy",
                symbol: "QES-BTC-LONG",
                strategySymbol: "BTC-PERP-LONG",
            },
            {
                name: "Quanter SOL Long Strategy",
                symbol: "QES-SOL-LONG",
                strategySymbol: "SOL-PERP-LONG",
            },
        ];

        const endTime = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60; // 1年后

        // 创建策略实例
        for (const strategy of strategies) {
            log(`\n创建策略: ${strategy.name}`);
            
            try {
                // 使用 hardhat-deploy 的 execute 方法
                const tx = await execute(
                    "StrategyVaultFactory",
                    { from: deployer, log: true },
                    "createVault",
                    admin || deployer,  // admin
                    manager || deployer, // manager
                    mockUSDC.address,   // asset
                    strategy.name,      // name
                    strategy.symbol,    // symbol
                    strategy.strategySymbol, // strategySymbol
                    endTime            // endTime
                );

                // 获取 factory 合约实例来读取地址
                const factoryContract = await ethers.getContractAt(
                    "StrategyVaultFactory",
                    factory.address
                );
                const vaultAddress = await factoryContract.symbolVault(strategy.strategySymbol);
                
                log(`✅ ${strategy.name} 已创建: ${vaultAddress}`);
            } catch (error) {
                log(`❌ 创建 ${strategy.name} 失败: ${error.message}`);
            }
        }

        log("\n所有策略 Vault 创建完成!");
        log("========================================");
    } else {
        log("跳过策略实例创建（仅在本地/测试网络创建）");
    }
};

module.exports.tags = ["all", "vaults"];
module.exports.dependencies = ["factory"]; // 依赖 factory
