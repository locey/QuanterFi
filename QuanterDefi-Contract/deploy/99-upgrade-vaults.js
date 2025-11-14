const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, get, log } = deployments;
    const { deployer, admin } = await getNamedAccounts();

    log("========================================");
    log("升级 StrategyVault 实现合约...");

    // 获取旧的实现合约
    const oldImpl = await get("StrategyVault");
    log(`当前实现合约: ${oldImpl.address}`);

    // 部署新的实现合约（这里演示升级到同一版本，实际应该是 V2）
    const unlockLockPeriod = 7 * 24 * 60 * 60; // 7天
    const newImpl = await deploy("StrategyVault", {
        from: deployer,
        args: [unlockLockPeriod],
        log: true,
        waitConfirmations: 1,
    });

    log(`新实现合约已部署: ${newImpl.address}`);

    // 获取 Factory 合约
    const factory = await get("StrategyVaultFactory");
    const factoryContract = await ethers.getContractAt("StrategyVaultFactory", factory.address);

    // 获取所有 vault 地址
    const allVaults = await factoryContract.getAllVaults();
    log(`\n找到 ${allVaults.length} 个 Vault 需要升级`);

    // 批量升级所有 Vault
    for (let i = 0; i < allVaults.length; i++) {
        const vaultAddress = allVaults[i];
        log(`\n[${i + 1}/${allVaults.length}] 升级 Vault: ${vaultAddress}`);

        try {
            const vault = await ethers.getContractAt("StrategyVault", vaultAddress);
            
            // 检查调用者是否有权限
            const DEFAULT_ADMIN_ROLE = await vault.DEFAULT_ADMIN_ROLE();
            const hasRole = await vault.hasRole(DEFAULT_ADMIN_ROLE, admin || deployer);
            
            if (!hasRole) {
                log(`⚠️  账户 ${admin || deployer} 没有 ADMIN 权限，跳过此 Vault`);
                continue;
            }

            // 执行升级
            const tx = await vault.upgradeToAndCall(newImpl.address, "0x");
            await tx.wait();
            
            log(`✅ 升级成功，交易哈希: ${tx.hash}`);
        } catch (error) {
            log(`❌ 升级失败: ${error.message}`);
        }
    }

    // 可选：更新 Factory 中的实现地址（影响新创建的 Vault）
    log("\n更新 Factory 的实现合约地址...");
    try {
        const tx = await factoryContract.updateImplementation(newImpl.address);
        await tx.wait();
        log(`✅ Factory 实现地址已更新`);
    } catch (error) {
        log(`❌ 更新 Factory 失败: ${error.message}`);
    }

    log("\n所有 Vault 升级完成!");
    log("========================================");
};

// 这个脚本不会自动运行，需要手动执行
// 运行方式: npx hardhat deploy --tags upgrade --network <network>
module.exports.tags = ["upgrade"];
module.exports.dependencies = ["factory"]; // 确保 factory 已部署
