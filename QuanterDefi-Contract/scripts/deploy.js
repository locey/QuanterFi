const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🚀 开始部署DeFi聚合器合约...");
  
  const [deployer] = await ethers.getSigners();
  console.log("📋 部署地址:", deployer.address);
  const bal = await deployer.provider.getBalance(deployer.address);
  console.log("💰 账户余额:", ethers.formatEther(bal));
  
  // 部署参数
  const FEE_COLLECTOR = deployer.address; // 手续费收集地址
  
  // 部署主聚合器合约
  console.log("\n📦 部署DeFiAggregator主合约...");
  const DeFiAggregator = await ethers.getContractFactory("DeFiAggregator");
  const aggregator = await DeFiAggregator.deploy(FEE_COLLECTOR);
  await aggregator.waitForDeployment();
  console.log("✅ DeFiAggregator部署完成:", aggregator.target);
  
  // 部署AAVE适配器（优先使用真实池；未提供则自动部署Mock池与aToken）
  console.log("\n📦 部署AaveAdapter...");
  const AaveAdapter = await ethers.getContractFactory("AaveAdapter");
  let aavePoolAddress = process.env.AAVE_POOL_ADDRESS || "";
  let usedMockAave = false;

  // 如果未提供真实 AAVE 池地址，则部署 Mock 组件
  if (!aavePoolAddress) {
    console.warn("⚠️ 未提供 AAVE_POOL_ADDRESS，将部署 MockAavePool 和 MockAToken 进行端到端测试。");
    const MockAavePool = await ethers.getContractFactory("MockAavePool");
    const MockAToken = await ethers.getContractFactory("MockAToken");

    // 先部署模拟代币，便于后续挂钩 aToken
    console.log("\n📦 部署模拟代币...");
    const MockToken = await ethers.getContractFactory("MockToken");
    const usdc = await MockToken.deploy("USD Coin", "USDC", 6);
    await usdc.waitForDeployment();
    console.log("✅ USDC模拟代币部署完成:", usdc.target);
    const dai = await MockToken.deploy("Dai Stablecoin", "DAI", 18);
    await dai.waitForDeployment();
    console.log("✅ DAI模拟代币部署完成:", dai.target);

    // 部署 aToken
    console.log("\n📦 部署 Mock aToken...");
    const aUSDC = await MockAToken.deploy("Aave Interest bearing USDC", "aUSDC");
    await aUSDC.waitForDeployment();
    const aDAI = await MockAToken.deploy("Aave Interest bearing DAI", "aDAI");
    await aDAI.waitForDeployment();
    console.log("✅ aUSDC:", aUSDC.target);
    console.log("✅ aDAI:", aDAI.target);

    // 部署 MockAavePool 并登记储备
    const mockPool = await MockAavePool.deploy();
    await mockPool.waitForDeployment();
    // 将 aToken 的所有权转移给池，使其能铸造/销毁
    await aUSDC.transferOwnership(mockPool.target);
    await aDAI.transferOwnership(mockPool.target);
    await mockPool.listReserve(usdc.target, aUSDC.target);
    await mockPool.listReserve(dai.target, aDAI.target);
    console.log("✅ MockAavePool 部署并配置完成:", mockPool.target);
    aavePoolAddress = mockPool.target;
    usedMockAave = true;

    // 部署主聚合器合约之后再配置适配器代币支持，因此将 usdc/dai 透传到后面
    // 为保持原有输出结构，临时挂到上下文
    global.__mockTokens = { usdc, dai, aUSDC, aDAI };
  }

  const aaveAdapter = await AaveAdapter.deploy(aavePoolAddress);
  await aaveAdapter.waitForDeployment();
  console.log("✅ AaveAdapter部署完成:", aaveAdapter.target);
  
  // 配置协议适配器
  console.log("\n⚙️ 配置协议适配器...");
  
  // 添加AAVE协议
  const addAaveTx = await aggregator.addProtocol(
    "AAVE",
    aaveAdapter.target,
    2 // 风险等级：2（中等偏低）
  );
  await addAaveTx.wait();
  console.log("✅ AAVE协议添加完成");
  
  // 更新AAVE协议APY（模拟值）
  const updateApyTx = await aggregator.updateProtocolAPY("AAVE", 350); // 3.5% APY
  await updateApyTx.wait();
  console.log("✅ AAVE协议APY更新完成");
  
  // 如果未用 MockAave，则部署模拟代币（仅用于交互脚本演示）
  let usdc, dai;
  if (!usedMockAave) {
    console.log("\n📦 部署模拟代币...");
    const MockToken = await ethers.getContractFactory("MockToken");
    usdc = await MockToken.deploy("USD Coin", "USDC", 6);
    await usdc.deployed();
    console.log("✅ USDC模拟代币部署完成:", usdc.address);
    dai = await MockToken.deploy("Dai Stablecoin", "DAI", 18);
    await dai.deployed();
    console.log("✅ DAI模拟代币部署完成:", dai.address);
  } else {
    // 使用上面部署的 mock 代币
    usdc = global.__mockTokens.usdc;
    dai = global.__mockTokens.dai;
  }
  
  // 为AAVE适配器添加支持的代币（需要管理员权限）
  console.log("\n⚙️ 配置AAVE适配器支持的代币...");
  
  // 配置 aToken：优先真实地址；若使用了 MockAave 自动使用 mock aToken
  if (usedMockAave) {
    await aaveAdapter.addSupportedToken(usdc.target, global.__mockTokens.aUSDC.target);
    console.log("✅ USDC添加到AAVE适配器:", global.__mockTokens.aUSDC.target);
    await aaveAdapter.addSupportedToken(dai.target, global.__mockTokens.aDAI.target);
    console.log("✅ DAI添加到AAVE适配器:", global.__mockTokens.aDAI.target);
  } else {
    const USDC_ATOKEN = process.env.USDC_ATOKEN || "";
    const DAI_ATOKEN = process.env.DAI_ATOKEN || "";
    if (USDC_ATOKEN && DAI_ATOKEN) {
      await aaveAdapter.addSupportedToken(usdc.target, USDC_ATOKEN);
      console.log("✅ USDC添加到AAVE适配器:", USDC_ATOKEN);
      await aaveAdapter.addSupportedToken(dai.target, DAI_ATOKEN);
      console.log("✅ DAI添加到AAVE适配器:", DAI_ATOKEN);
    } else {
      console.warn("⚠️ 未提供 USDC_ATOKEN / DAI_ATOKEN，已跳过在适配器中登记真实aToken。请在.env中设置以进行真实链上交互。");
    }
  }
  
  // 输出部署结果
  console.log("\n🎉 部署完成！");
  console.log("=".repeat(50));
  console.log("📋 合约地址:");
  console.log("DeFiAggregator:", aggregator.target);
  console.log("AaveAdapter:", aaveAdapter.target);
  console.log("USDC Token:", usdc.target);
  console.log("DAI Token:", dai.target);
  console.log("=".repeat(50));
  
  // 保存部署信息到文件
  const deploymentInfo = {
    network: network.name,
    chainId: network.config.chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      DeFiAggregator: {
        address: aggregator.target,
        feeCollector: FEE_COLLECTOR,
        performanceFee: "5%"
      },
      AaveAdapter: {
        address: aaveAdapter.target,
        aavePool: aavePoolAddress,
        supportedTokens: [usdc.target, dai.target]
      },
      MockTokens: {
        USDC: usdc.target,
        DAI: dai.target
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
        address: aggregator.target,
        constructorArguments: [FEE_COLLECTOR],
      });
      console.log("✅ DeFiAggregator验证完成");
      
      await hre.run("verify:verify", {
        address: aaveAdapter.target,
        constructorArguments: [aavePoolAddress],
      });
      console.log("✅ AaveAdapter验证完成");
      
      await hre.run("verify:verify", {
        address: usdc.target,
        constructorArguments: ["USD Coin", "USDC", 6],
      });
      console.log("✅ USDC验证完成");
      
      await hre.run("verify:verify", {
        address: dai.target,
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