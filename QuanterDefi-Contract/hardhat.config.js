// 导入Hardhat工具箱，包含常用的插件和工具
require("@nomicfoundation/hardhat-toolbox");
// 导入hardhat-deploy插件，用于管理部署脚本
require("hardhat-deploy");
// 导入hardhat-gas-reporter插件，用于生成Gas消耗报告
require("hardhat-gas-reporter");
// 导入@openzeppelin/hardhat-upgrades插件，用于可升级合约
require("@openzeppelin/hardhat-upgrades");
// 导入dotenv/config，用于加载环境变量
require("dotenv/config");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  // Solidity编译器配置
  solidity: {
    // 指定Solidity版本
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
    // 元数据配置
    metadata: {
      // 不在字节码中包含元数据哈希，减小合约大小
      bytecodeHash: "none",
    },
  },
  
  // Gas报告配置
  gasReporter: {
    // 启用Gas报告
    enabled: true,
    // 报告使用的货币单位
    currency: "USD",
    // Gas价格(单位：Gwei)
    gasPrice: 21,
    // Coinmarketcap API密钥，用于获取实时价格
    //coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  
  // 命名账户配置
  namedAccounts: {
    // 部署者账户
    deployer: {
      // 默认使用第一个账户作为部署者
      default: 0,
    },
  },
  
  // 路径配置
  paths: {
    // 合约源代码路径
    sources: "./src",
    // 测试文件路径
    tests: "./test",
    // 缓存文件路径
    cache: "./cache",
    // 编译产物路径
    artifacts: "./artifacts",
    // 部署脚本路径
    deploy: "./deploy",
  },
  
  // 网络配置
  networks: {
    // Sepolia测试网配置
    sepolia: {
      // 网络URL，使用Infura API
      url: `https://eth-sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      // 账户配置，从环境变量获取私钥
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  
  // Etherscan配置，用于合约验证
  etherscan: {
    // Etherscan API密钥
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
