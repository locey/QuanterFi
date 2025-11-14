module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await getChainId();

    // 只在本地网络和测试网络部署 Mock 合约
    if (chainId === "31337" || chainId === "11155111") {
        log("========================================");
        log("部署 Mock 合约...");
        
        // 部署 MockUSDC
        const mockUSDC = await deploy("MockUSDC", {
            from: deployer,
            args: [],
            log: true,
            waitConfirmations: 1,
        });
        log(`MockUSDC 已部署到: ${mockUSDC.address}`);
        
        log("Mock 合约部署完成!");
        log("========================================");
    } else {
        log("跳过 Mock 合约部署（仅在本地/测试网络部署）");
    }
};

module.exports.tags = ["all", "mocks"];
