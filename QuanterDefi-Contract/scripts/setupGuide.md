# Sepolia网络部署设置指南

要在Sepolia测试网上部署合约，你需要完成以下设置：

## 1. 获取Infura API密钥

1. 访问 [Infura](https://infura.io/) 并创建一个免费账户
2. 创建一个新的应用：
   - 选择网络：Ethereum
   - 选择环境：Testnet
   - 选择网络：Sepolia
3. 创建完成后，点击"View Key"获取你的API密钥

## 2. 获取Sepolia ETH

1. 访问 [Sepolia Faucet](https://infura.io/) 获取测试ETH
2. 或者访问 [Infura Sepolia Faucet](https://infura.io/faucet/ethereum-sepolia) 获取测试ETH
3. 你需要提供你的钱包地址来接收测试ETH

## 3. 导出私钥

1. 在MetaMask中，选择你的部署账户
2. 点击账户头像 -> "账户详情"
3. 点击"导出私钥"
4. 复制私钥（不包含 0x 前缀）

## 4. 获取Etherscan API密钥（用于合约验证）

1. 访问 [Etherscan](https://etherscan.io/) 并创建账户
2. 进入 "My Profile" -> "API-KEYs"
3. 点击"Add"创建新的API密钥

## 5. 配置.env文件

将获取到的信息填入 `.env` 文件：

```
ALCHEMY_API_KEY=your_alchemy_api_key_here
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key_here
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key_here
```

## 6. 部署到Sepolia

完成配置后，运行以下命令部署合约：

```bash
npx hardhat deploy --network sepolia
```

## 7. 验证合约

部署完成后，你可以验证合约：

```bash
npx hardhat verify --network sepolia <contract-address>
```

## 注意事项

1. 永远不要将私钥提交到版本控制系统中
2. 确保 `.env` 文件在 `.gitignore` 中
3. 在主网上部署前，先在测试网上充分测试