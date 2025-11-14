module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, get, log } = deployments;
    const { deployer } = await getNamedAccounts();

    log("========================================");
    log("部署 StrategyVaultFactory 合约...");

    // 获取已部署的 StrategyVault 实现合约
    const strategyVaultImpl = await get("StrategyVault");
    const unlockLockPeriod = 7 * 24 * 60 * 60; // 7天

    // 部署 Factory 合约
    const factory = await deploy("StrategyVaultFactory", {
        from: deployer,
        args: [strategyVaultImpl.address, unlockLockPeriod],
        log: true,
        waitConfirmations: 1,
    });

    log(`StrategyVaultFactory 已部署到: ${factory.address}`);
    log(`使用的 Vault 实现合约: ${strategyVaultImpl.address}`);
    log("========================================");
};

module.exports.tags = ["all", "factory"];
module.exports.dependencies = ["vault-impl"]; // 依赖 vault-impl
