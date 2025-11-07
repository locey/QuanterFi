const { ethers, upgrades } = require("hardhat");

async function main() {
  // 首先部署合约
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
  
  // 增加计数
  console.log("Incrementing counter again...");
  const incrementTx2 = await counter.increment();
  await incrementTx2.wait();
  
  count = await counter.count();
  console.log("Count after second increment:", count.toString());
  
  // 减少计数
  console.log("Decrementing counter...");
  const decrementTx = await counter.decrement();
  await decrementTx.wait();
  
  count = await counter.count();
  console.log("Count after decrement:", count.toString());
  
  // 重置计数
  console.log("Resetting counter...");
  const resetTx = await counter.reset();
  await resetTx.wait();
  
  count = await counter.count();
  console.log("Count after reset:", count.toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });