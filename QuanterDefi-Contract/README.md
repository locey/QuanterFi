# QuantDefi - 可升级计数器合约

这个项目演示了如何创建、测试和部署一个可升级的Solidity智能合约。

## 项目结构

```
.
├── src/                 # 合约源代码
│   ├── Counter.sol      # 基础计数器合约
│   └── CounterV2.sol    # 升级版计数器合约
├── test/                # 测试文件
│   └── Counter.test.js  # 计数器合约测试
├── deploy/              # 部署脚本
│   ├── 01_deploy_counter.js     # 部署脚本
│   └── 02_upgrade_counter.js    # 升级脚本
├── scripts/             # 交互脚本
│   ├── interact.js      # 合约交互示例
│   └── upgrade.js       # 合约升级示例
├── hardhat.config.js    # Hardhat配置文件
└── package.json         # 项目依赖
```

## 功能特性

1. **可升级合约**：使用OpenZeppelin的可升级合约模式
2. **完整测试**：包含所有功能的测试用例
3. **优化配置**：Solidity编译器优化设置
4. **Gas报告**：详细的Gas消耗报告
5. **部署脚本**：使用hardhat-deploy进行合约部署

## 合约功能

### Counter.sol (基础版本)
- `increment()`: 增加计数器（任何人都可以调用）
- `decrement()`: 减少计数器（仅所有者）
- `reset()`: 重置计数器（仅所有者）
- `count()`: 查看当前计数

### CounterV2.sol (升级版本)
- 继承了基础版本的所有功能
- 添加了最大计数限制
- `setMaxCount()`: 设置最大计数（仅所有者）
- `maxCount()`: 查看最大计数

## 安装依赖

```bash
npm install
```

## 编译合约

```bash
npx hardhat compile
```

## 运行测试

```bash
npx hardhat test
```

## 部署合约

### 部署到本地网络

```bash
npx hardhat deploy
```

### 部署到Sepolia测试网

1. 重命名 `.env.example` 文件为 `.env` 并填入你的配置信息：

```bash
mv .env.example .env
# 然后编辑 .env 文件，填入你的 Alchemy API Key、私钥等信息
```

2. 部署到Sepolia网络：

```bash
npx hardhat deploy --network sepolia
```

详细设置指南请查看 [Sepolia网络部署设置指南](scripts/setupGuide.md)

### 部署到其他网络

你也可以配置其他网络并在其上部署：

```bash
npx hardhat deploy --network <network-name>
```

## 升级合约

```bash
npx hardhat deploy --tags UpgradeCounter
```

## 交互示例

### 运行基础交互脚本

```bash
npx hardhat run scripts/interact.js
```

### 运行升级演示脚本

```bash
npx hardhat run scripts/upgrade.js
```

## 配置说明

### 环境变量配置

在 `.env` 文件中配置以下环境变量：

- `ALCHEMY_API_KEY`: Alchemy API密钥，用于连接到Sepolia网络
- `PRIVATE_KEY`: 部署者的私钥（不包含 0x 前缀）
- `ETHERSCAN_API_KEY`: Etherscan API密钥，用于验证已部署的合约
- `COINMARKETCAP_API_KEY`: Coinmarketcap API密钥，用于Gas报告（可选）

### hardhat.config.js

配置文件包含详细的中文注释，解释了每个配置项的作用：

- **Solidity编译器**: 0.8.28版本，启用优化器，runs=200
- **Gas报告**: 启用，货币单位为USD
- **路径配置**: 
  - 合约源码: ./src
  - 测试文件: ./test
  - 部署脚本: ./deploy
- **网络配置**: 包含Sepolia测试网配置
- **安全设置**: 不在字节码中包含元数据哈希，减小合约大小

## 测试覆盖

测试文件包含了以下测试用例：

1. 部署测试
2. 增加计数功能测试
3. 减少计数功能测试（包括权限控制）
4. 重置功能测试
5. 事件触发测试
6. 合约升级测试

## 安全特性

1. 使用OpenZeppelin的可升级合约模式
2. Ownable权限控制
3. 输入验证和边界检查
4. 事件日志记录

## 许可证

MIT