const { ethers, upgrades } = require("hardhat");

module.exports = async function ({ deployments, getNamedAccounts, network }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("Deploying Counter contract with account:", deployer);
  console.log("Network:", network.name);

  const Counter = await ethers.getContractFactory("Counter");
  
  // 部署可升级合约
  const counter = await upgrades.deployProxy(Counter, [], {
    initializer: 'initialize'
  });

  await counter.waitForDeployment();
  
  const counterAddress = await counter.getAddress();
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(counterAddress);
  const adminAddress = await upgrades.erc1967.getAdminAddress(counterAddress);

  console.log("Counter deployed to:", counterAddress);
  console.log("Implementation deployed to:", implementationAddress);
  console.log("Admin proxy deployed to:", adminAddress);

  // 保存部署信息
  await deploy("Counter", {
    contract: "Counter",
    from: deployer,
    log: true,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      viaAdminContract: "DefaultProxyAdmin",
      execute: {
        init: {
          methodName: "initialize",
          args: [],
        },
      },
    },
  });

  // 如果在测试网或主网上，等待几个区块确认
  if (network.name === "sepolia" || network.name === "mainnet") {
    console.log("Waiting for 5 block confirmations...");
    await counter.deploymentTransaction().wait(5);
  }
};

module.exports.tags = ["Counter"];