const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 开始部署DeFi聚合器合约...");
  
  const [deployer] = await ethers.getSigners();
  console.log("📋 部署地址:", deployer.address);
  console.log("💰 账户余额:", ethers.utils.formatEther(await deployer.getBalance()));
  
  // 部署参数
  const FEE_COLLECTOR = deployer.address; // 手续费收集地址
  
  // 部署主聚合器合约
  console.log("\n📦 部署DeFiAggregator主合约...");
  const DeFiAggregator = await ethers.getContractFactory("DeFiAggregator");
  const aggregator = await DeFiAggregator.deploy(FEE_COLLECTOR);
  await aggregator.deployed();
  console.log("✅ DeFiAggregator部署完成:", aggregator.address);
  
  // 部署AAVE适配器（使用模拟地址，实际部署时需要替换为真实的AAVE池地址）
  console.log("\n📦 部署AaveAdapter...");
  const AaveAdapter = await ethers.getContractFactory("AaveAdapter");
  
  // 注意：这里使用模拟地址，实际部署时需要替换为真实的AAVE池地址
  const AAVE_POOL_ADDRESS = "0x0000000000000000000000000000000000000000"; // 需要替换
  const aaveAdapter = await AaveAdapter.deploy(AAVE_POOL_ADDRESS);
  await aaveAdapter.deployed();
  console.log("✅ AaveAdapter部署完成:", aaveAdapter.address);
  
  // 配置协议适配器
  console.log("\n⚙️ 配置协议适配器...");
  
  // 添加AAVE协议
  const addAaveTx = await aggregator.addProtocol(
    "AAVE",
    aaveAdapter.address,
    2 // 风险等级：2（中等偏低）
  );
  await addAaveTx.wait();
  console.log("✅ AAVE协议添加完成");
  
  // 更新AAVE协议APY（模拟值）
  const updateApyTx = await aggregator.updateProtocolAPY("AAVE", 350); // 3.5% APY
  await updateApyTx.wait();
  console.log("✅ AAVE协议APY更新完成");
  
  // 部署模拟代币（用于测试）
  console.log("\n📦 部署模拟代币...");
  const MockToken = await ethers.getContractFactory("MockToken");
  const usdc = await MockToken.deploy("USD Coin", "USDC", 6); // 6位小数
  await usdc.deployed();
  console.log("✅ USDC模拟代币部署完成:", usdc.address);
  
  const dai = await MockToken.deploy("Dai Stablecoin", "DAI", 18); // 18位小数
  await dai.deployed();
  console.log("✅ DAI模拟代币部署完成:", dai.address);
  
  // 为AAVE适配器添加支持的代币（需要管理员权限）
  console.log("\n⚙️ 配置AAVE适配器支持的代币...");
  
  // 注意：这里需要模拟aToken地址，实际部署时需要真实的aToken地址
  const USDC_ATOKEN = "0x0000000000000000000000000000000000000001"; // 需要替换
  const DAI_ATOKEN = "0x0000000000000000000000000000000000000002"; // 需要替换
  
  await aaveAdapter.addSupportedToken(usdc.address, USDC_ATOKEN);
  console.log("✅ USDC添加到AAVE适配器");
  
  await aaveAdapter.addSupportedToken(dai.address, DAI_ATOKEN);
  console.log("✅ DAI添加到AAVE适配器");
  
  // 输出部署结果
  console.log("\n🎉 部署完成！");
  console.log("=".repeat(50));
  console.log("📋 合约地址:");
  console.log("DeFiAggregator:", aggregator.address);
  console.log("AaveAdapter:", aaveAdapter.address);
  console.log("USDC Token:", usdc.address);
  console.log("DAI Token:", dai.address);
  console.log("=".repeat(50));
  
  // 保存部署信息到文件
  const deploymentInfo = {
    network: network.name,
    chainId: network.config.chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      DeFiAggregator: {
        address: aggregator.address,
        feeCollector: FEE_COLLECTOR,
        performanceFee: "5%"
      },
      AaveAdapter: {
        address: aaveAdapter.address,
        aavePool: AAVE_POOL_ADDRESS,
        supportedTokens: [usdc.address, dai.address]
      },
      MockTokens: {
        USDC: usdc.address,
        DAI: dai.address
      }
    }
  };
  
  // 写入部署信息文件
  const fs = require('fs');
  const deploymentPath = `./deployments/${network.name}.json`;
  
  // 确保目录存在
  const dir = './deployments';
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  console.log(`\n📄 部署信息已保存到: ${deploymentPath}`);
  
  // 验证合约（如果配置了Etherscan API）
  if (process.env.ETHERSCAN_API_KEY) {
    console.log("\n🔍 开始验证合约...");
    
    try {
      await hre.run("verify:verify", {
        address: aggregator.address,
        constructorArguments: [FEE_COLLECTOR],
      });
      console.log("✅ DeFiAggregator验证完成");
      
      await hre.run("verify:verify", {
        address: aaveAdapter.address,
        constructorArguments: [AAVE_POOL_ADDRESS],
      });
      console.log("✅ AaveAdapter验证完成");
      
      await hre.run("verify:verify", {
        address: usdc.address,
        constructorArguments: ["USD Coin", "USDC", 6],
      });
      console.log("✅ USDC验证完成");
      
      await hre.run("verify:verify", {
        address: dai.address,
        constructorArguments: ["Dai Stablecoin", "DAI", 18],
      });
      console.log("✅ DAI验证完成");
      
    } catch (error) {
      console.log("⚠️ 合约验证失败:", error.message);
    }
  }
}

// 错误处理
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ 部署失败:", error);
    process.exit(1);
  });