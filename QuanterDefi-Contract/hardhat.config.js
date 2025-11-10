require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

// 获取环境变量
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000";
const MAINNET_URL = process.env.MAINNET_URL || "";
const POLYGON_URL = process.env.POLYGON_URL || "";
const ARBITRUM_URL = process.env.ARBITRUM_URL || "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY || "";
const ARBISCAN_API_KEY = process.env.ARBISCAN_API_KEY || "";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    // 指定Solidity版本
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true, // 启用IR优化器，减少gas消耗
    },
  },
  
  networks: {
    // 本地网络
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
    
    // Ethereum主网
    mainnet: {
      url: MAINNET_URL,
      accounts: PRIVATE_KEY !== "0x0000000000000000000000000000000000000000000000000000000000000000" ? [PRIVATE_KEY] : [],
      chainId: 1,
      gasPrice: "auto",
    },
    
    // Ethereum测试网
    sepolia: {
      url: "https://rpc.sepolia.org",
      accounts: PRIVATE_KEY !== "0x0000000000000000000000000000000000000000000000000000000000000000" ? [PRIVATE_KEY] : [],
      chainId: 11155111,
      gasPrice: "auto",
    },
    
    // Polygon主网
    polygon: {
      url: POLYGON_URL,
      accounts: PRIVATE_KEY !== "0x0000000000000000000000000000000000000000000000000000000000000000" ? [PRIVATE_KEY] : [],
      chainId: 137,
      gasPrice: "auto",
    },
    
    // Polygon测试网
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: PRIVATE_KEY !== "0x0000000000000000000000000000000000000000000000000000000000000000" ? [PRIVATE_KEY] : [],
      chainId: 80001,
      gasPrice: "auto",
    },
    
    // Arbitrum主网
    arbitrum: {
      url: ARBITRUM_URL,
      accounts: PRIVATE_KEY !== "0x0000000000000000000000000000000000000000000000000000000000000000" ? [PRIVATE_KEY] : [],
      chainId: 42161,
      gasPrice: "auto",
    },
    
    // Arbitrum测试网
    arbitrumGoerli: {
      url: "https://goerli-rollup.arbitrum.io/rpc",
      accounts: PRIVATE_KEY !== "0x0000000000000000000000000000000000000000000000000000000000000000" ? [PRIVATE_KEY] : [],
      chainId: 421613,
      gasPrice: "auto",
    },
    
    // BSC主网（可选）
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      accounts: PRIVATE_KEY !== "0x0000000000000000000000000000000000000000000000000000000000000000" ? [PRIVATE_KEY] : [],
      chainId: 56,
      gasPrice: "auto",
    },
    
    // BSC测试网（可选）
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      accounts: PRIVATE_KEY !== "0x0000000000000000000000000000000000000000000000000000000000000000" ? [PRIVATE_KEY] : [],
      chainId: 97,
      gasPrice: "auto",
    },
  },
  
  // Etherscan验证配置
  etherscan: {
    apiKey: {
      mainnet: ETHERSCAN_API_KEY,
      sepolia: ETHERSCAN_API_KEY,
      polygon: POLYGONSCAN_API_KEY,
      polygonMumbai: POLYGONSCAN_API_KEY,
      arbitrumOne: ARBISCAN_API_KEY,
      arbitrumGoerli: ARBISCAN_API_KEY,
      bsc: "", // BSC不需要API key验证
      bscTestnet: "", // BSC测试网不需要API key验证
    },
  },
  
  // Gas报告配置
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    gasPrice: 21,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY || "",
  },
  
  // 合约大小优化
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
  
  // 测试配置
  mocha: {
    timeout: 100000,
  },
  
  // 路径配置
  paths: {
    sources: "./src",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};