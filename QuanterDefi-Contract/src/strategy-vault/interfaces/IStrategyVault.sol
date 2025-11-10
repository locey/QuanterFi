// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// define interface and struct
// 投资标的枚举
enum InvestmentTarget {
    BTC,
    ETH,
    SOL,
    OTHER
}
// 交易类型枚举
enum TradeType {
    INVEST,
    WITHDRAW
}

// strategy struct
struct Strategy {
    uint256 Id; // 策略ID
    address StrategyVaultAddress; // 策略地址
    string name; // 策略名称
    InvestmentTarget[] targets; // 投资标的
    uint256 apy; // 年化收益率
    uint256 tvl; // 总投资金额
    uint256 startTime;
    uint256 endTime;
    IERC20 underlyingAsset; // 策略中的基础资产
    uint256 performanceFeeRate; // 性能提成比例（1000 表示 10%）
}

// 用户资产struct
struct UserAsset {
    address user;
    uint256 strategyId;
    uint256 totalAmount;// 用户存入总资产
    uint256 lockedAmount; // 用户锁定资产数量(已经真实购买了标的)
    uint256 unlockedAmount; // 用户解锁资产总量（卖出标的价值+总资产-锁定资产）
    uint256 withdrawedAmount; // 用户已提走资产数量（卖出标的价值+总资产-锁定资产）
}

struct UserInvestment{
    address user;
    InvestmentTarget target;
    uint256 holdShares;
    uint256 requestUnholdShares;
    uint256 unholdShares;
}

// 交易详情struct
struct TradeDetail {
    uint256 Id;// 交易ID
    // 策略ID
    uint256 strategyId;
    // 交易标的
    InvestmentTarget investmentTarget;
    // 交易类型
    TradeType tradeType;
    // 交易总金额
    uint256 totalAmount;
    // 交易总份额
    uint256 totalShares;
    //交易时间
    uint256 tradeTime;
    // 交易用户
    address user;
}

// 份额解锁请求struct
struct UnlockRequest {
    uint256 Id; // 请求ID
    uint256 strategyId; // 策略ID
    uint256 shares; // 解锁份额
    uint256 requestTime; // 请求解锁时间
    address user; // 用户
    bool processed; // 是否处理完成
}


interface IStrategyVault {
    // 策略方法
    function getStrategyInfo() external view returns (Strategy memory);

    // 用户方法
    function deposit(uint256 strategyId, IERC20 underlyingAsset, uint256 amount) external;

    // 支持Permit的存款函数
    function depositWithPermit(
        uint256 strategyId,
        IERC20 underlyingAsset,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function requestUnlock(uint256 strategyId,uint256 shares) external;
    // 查询用户资产基本信息
    function getUserAsset() external view returns (UserAsset memory);
    
    function withdraw(uint256 strategyId, uint256 amount) external;
    // 管理员方法
        // 要记录到用户维度。 策略自动调用
    function adminWithdraw(uint256 strategyId,IERC20 underlyingAsset, uint256 amount) external;

    function setTradeDetails(TradeDetail[] memory tradeDetails) external;
        // 处理用户发起的解锁请求。（链下卖出后调用，更新用户解锁请求，和解锁资产，转入资产）
    function processUnlockRequest(uint256 requestId, IERC20 asset,uint256 amount) external;
    
}