const { ethers, network } = require("hardhat");
const fs = require("fs");
require("dotenv").config();

async function main() {
  console.log(`🔧 使用网络: ${network.name}`);

  const [user] = await ethers.getSigners();
  console.log("👤 测试地址:", user.address);

  // 读取部署信息
  const deploymentPath = `./deployments/${network.name}.json`;
  if (!fs.existsSync(deploymentPath)) {
    throw new Error(`未找到部署信息文件: ${deploymentPath}，请先运行: npx hardhat run scripts/deploy.js --network ${network.name}`);
  }
  const deployments = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));

  const aggregatorAddr = deployments.contracts.DeFiAggregator.address;
  const usdcAddr = deployments.contracts.MockTokens.USDC;
  const daiAddr = deployments.contracts.MockTokens.DAI;

  console.log("📄 读取合约:");
  console.log("DeFiAggregator:", aggregatorAddr);
  console.log("USDC:", usdcAddr);
  console.log("DAI:", daiAddr);

  // 获取合约实例
  const aggregator = await ethers.getContractAt("DeFiAggregator", aggregatorAddr);
  const erc20Abi = [
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function balanceOf(address account) external view returns (uint256)",
    "function decimals() external view returns (uint8)",
  ];
  const usdc = new ethers.Contract(usdcAddr, erc20Abi, user);

  // 准备金额：1000 个单位，按代币小数转换
  const usdcDecimals = await usdc.decimals();
  const amount = ethers.parseUnits("1000", usdcDecimals);

  // 1) 用户授权 aggregator 扣款（deposit 中会从用户转入到 aggregator）
  console.log("\n🪙 授权 Aggregator 扣款 USDC...");
  const approveTx = await usdc.approve(aggregatorAddr, amount);
  await approveTx.wait();
  console.log("✅ 授权完成:", approveTx.hash);

  // 2) 执行存款
  console.log("\n⬆️ 执行存款到协议 AAVE...");
  const depositTx = await aggregator.deposit(usdcAddr, amount, "AAVE");
  const depositRcpt = await depositTx.wait();
  console.log("✅ 存款交易完成:", depositRcpt.transactionHash);

  // 3) 查询余额与可提取金额
  const userBalance = await aggregator.getUserBalance(user.address, usdcAddr, "AAVE");
  const withdrawable = await aggregator.getWithdrawableAmount(user.address, usdcAddr, "AAVE");
  console.log("📊 用户协议余额:", ethers.formatUnits(userBalance, usdcDecimals));
  console.log("📊 可提取金额:", ethers.formatUnits(withdrawable, usdcDecimals));

  // 4) 提现 500
  const withdrawAmount = ethers.parseUnits("500", usdcDecimals);
  console.log("\n⬇️ 从协议 AAVE 提现 500 USDC...");
  const withdrawTx = await aggregator.withdraw(usdcAddr, withdrawAmount, "AAVE");
  const withdrawRcpt = await withdrawTx.wait();
  console.log("✅ 提现交易完成:", withdrawRcpt.transactionHash);

  // 5) 再次查询余额
  const userBalanceAfter = await aggregator.getUserBalance(user.address, usdcAddr, "AAVE");
  const totalAssets = await aggregator.getUserTotalAssets(user.address);
  console.log("📊 提现后用户协议余额:", ethers.formatUnits(userBalanceAfter, usdcDecimals));
  console.log("📊 用户总资产(估算):", totalAssets.toString());
}

main().catch((e) => {
  console.error("❌ 交互失败:", e);
  process.exit(1);
});

