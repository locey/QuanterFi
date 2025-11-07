const { ethers, upgrades } = require("hardhat");

module.exports = async function ({ deployments, getNamedAccounts, network }) {
  const { deployer } = await getNamedAccounts();
  
  console.log("Upgrading Counter contract with account:", deployer);
  console.log("Network:", network.name);

  // 获取现有代理合约地址
  const proxyAddress = (await deployments.get("Counter")).address;
  console.log("Proxy address:", proxyAddress);

  // 获取新的实现合约
  const CounterV2 = await ethers.getContractFactory("CounterV2");
  
  // 升级合约
  const upgradedCounter = await upgrades.upgradeProxy(proxyAddress, CounterV2);
  
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  console.log("Upgraded implementation address:", implementationAddress);
  
  console.log("Counter contract upgraded successfully!");
  
  // 验证升级后的功能
  const maxCount = await upgradedCounter.maxCount();
  console.log("Default max count:", maxCount.toString());
  
  // 如果在测试网或主网上，等待几个区块确认
  if (network.name === "sepolia" || network.name === "mainnet") {
    console.log("Waiting for 5 block confirmations...");
    await upgradedCounter.deploymentTransaction().wait(5);
  }
};

module.exports.tags = ["UpgradeCounter"];
module.exports.dependencies = ["Counter"];