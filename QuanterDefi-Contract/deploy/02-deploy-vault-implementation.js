module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();

    log("========================================");
    log("部署 StrategyVault 实现合约...");

    // 配置参数
    const unlockLockPeriod = 7 * 24 * 60 * 60; // 7天

    // 部署 StrategyVault 实现合约
    const strategyVaultImpl = await deploy("StrategyVault", {
        from: deployer,
        args: [unlockLockPeriod],
        log: true,
        waitConfirmations: 1,
    });

    log(`StrategyVault 实现合约已部署到: ${strategyVaultImpl.address}`);
    log("========================================");
};

module.exports.tags = ["all", "vault-impl"];
module.exports.dependencies = ["mocks"]; // 依赖 mocks，确保顺序
