# Hardhat Deploy 使用指南

本项目使用 `hardhat-deploy` 插件进行合约部署和升级管理。

## 快速开始

```bash
# 安装依赖
npm install

# 本地部署
npm run deploy:localhost

# 测试网部署
npm run deploy:sepolia
```

## 部署命令

### 完整部署
```bash
npm run deploy              # 默认网络
npm run deploy:localhost    # 本地网络
npm run deploy:sepolia      # Sepolia测试网
npm run deploy:mainnet      # 主网
```

### 标签部署
```bash
# 只部署Mock合约
npx hardhat deploy --tags mocks --network localhost

# 部署实现合约和Factory
npx hardhat deploy --tags vault-impl,factory --network localhost

# 创建Vault实例
npx hardhat deploy --tags vaults --network localhost
```

### 升级合约
```bash
# 升级所有Vault到新实现
npx hardhat deploy --tags upgrade --network localhost
```

## 部署脚本

| 脚本 | 功能 | 标签 | 依赖 |
|------|------|------|------|
| 01-deploy-mocks.js | 部署MockUSDC | `mocks` | - |
| 02-deploy-vault-implementation.js | 部署StrategyVault实现 | `vault-impl` | mocks |
| 03-deploy-factory.js | 部署Factory | `factory` | vault-impl |
| 04-create-vaults.js | 创建3个策略实例 | `vaults` | factory |
| 99-upgrade-vaults.js | 批量升级Vault | `upgrade` | factory |

## 部署记录

部署信息自动保存在 `deployments/<network>/`：
- 合约地址
- 交易哈希
- ABI
- 构造参数
- 时间戳

## Named Accounts

- `deployer`: 部署者（索引0）
- `admin`: 管理员（索引1）
- `manager`: 管理者（索引2）
- `feeReceiver`: 手续费接收者（索引3）

## 常用操作

```bash
# 重置并重新部署
npx hardhat deploy --reset --network localhost

# 获取部署信息
npx hardhat deploy --export deployments.json

# 验证合约
npm run verify:sepolia
```

详细文档请参考各部署脚本中的注释。
