const { ethers, upgrades } = require("hardhat");

async function main() {
  // 首先部署原始合约
  console.log("Deploying Counter contract...");
  const Counter = await ethers.getContractFactory("Counter");
  const counter = await upgrades.deployProxy(Counter, { initializer: 'initialize' });
  await counter.waitForDeployment();
  
  console.log("Counter deployed to:", await counter.getAddress());
  
  // 获取当前计数
  let count = await counter.count();
  console.log("Current count:", count.toString());
  
  // 增加计数
  console.log("Incrementing counter...");
  const incrementTx = await counter.increment();
  await incrementTx.wait();
  
  count = await counter.count();
  console.log("Count after increment:", count.toString());
  
  // 升级到V2版本
  console.log("Upgrading to CounterV2...");
  const CounterV2 = await ethers.getContractFactory("CounterV2");
  const upgradedCounter = await upgrades.upgradeProxy(await counter.getAddress(), CounterV2);
  
  console.log("Counter upgraded successfully!");
  
  // 验证状态保持不变
  count = await upgradedCounter.count();
  console.log("Count after upgrade (should be same as before):", count.toString());
  
  // 测试新功能
  const maxCount = await upgradedCounter.maxCount();
  console.log("Default max count:", maxCount.toString());
  
  // 设置新的最大计数
  console.log("Setting max count to 5...");
  const setMaxTx = await upgradedCounter.setMaxCount(5);
  await setMaxTx.wait();
  
  const newMaxCount = await upgradedCounter.maxCount();
  console.log("New max count:", newMaxCount.toString());
  
  // 测试计数直到达到最大值
  console.log("Incrementing until max count...");
  for (let i = 0; i < 5; i++) {
    const currentCount = await upgradedCounter.count();
    console.log("Current count:", currentCount.toString());
    
    if (currentCount < await upgradedCounter.maxCount()) {
      const incrementTx = await upgradedCounter.increment();
      await incrementTx.wait();
      console.log("Incremented successfully");
    } else {
      console.log("Reached maximum count, cannot increment further");
      break;
    }
  }
  
  // 尝试超过最大计数
  try {
    console.log("Trying to increment beyond max count...");
    const incrementTx = await upgradedCounter.increment();
    await incrementTx.wait();
  } catch (error) {
    console.log("Failed to increment beyond max count (as expected):", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });