// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IProtocolAdapter.sol";

// AAVE池合约接口（简化版本，顶层声明）
interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function getReserveData(address asset) external view returns (ReserveData memory);
}

// AAVE aToken接口（顶层声明）
interface IAToken {
    function balanceOf(address user) external view returns (uint256);
    function scaledBalanceOf(address user) external view returns (uint256);
}

// AAVE储备数据结构（顶层声明）
struct ReserveData {
    uint256 liquidityIndex;
    uint256 currentLiquidityRate;
    uint40 lastUpdateTimestamp;
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
}

/**
 * @title AaveAdapter
 * @dev AAVE协议适配器，实现IProtocolAdapter接口
 */
contract AaveAdapter is IProtocolAdapter, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // 状态变量
    IPool public aavePool;
    mapping(address => address) public tokenToAToken; // 原始代币到aToken的映射
    mapping(address => bool) public supportedTokens;
    address[] public supportedTokensList;
    
    uint256 public constant RISK_LEVEL = 2; // AAVE风险等级为2（中等偏低）
    uint256 public constant LOCK_PERIOD = 0; // AAVE通常没有强制锁定期
    uint256 public constant APY_PRECISION = 1e18;
    uint256 public constant RAY = 1e27; // AAVE使用的精度
    
    bool public isAdapterActive = true;
    
    // 事件
    event Deposit(address indexed user, address indexed token, uint256 amount, address indexed aToken);
    event Withdraw(address indexed user, address indexed token, uint256 amount, uint256 actualAmount);
    event TokenSupported(address indexed token, address indexed aToken);
    event TokenUnsupported(address indexed token);
    
    /**
     * @dev 构造函数
     * @param _aavePool AAVE池合约地址
     */
    constructor(address _aavePool) Ownable(msg.sender) {
        require(_aavePool != address(0), "Invalid AAVE pool address");
        aavePool = IPool(_aavePool);
    }
    
    /**
     * @dev 存入资金到AAVE
     */
    function deposit(address token, uint256 amount) external override nonReentrant returns (uint256) {
        require(isAdapterActive, "Adapter is not active");
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be greater than 0");
        require(tokenToAToken[token] != address(0), "aToken not configured");
        
        // 从用户转账代币到本合约
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // 授权AAVE池使用代币（OpenZeppelin v5 使用 forceApprove 以避免非零到非零的 approve 限制）
        IERC20(token).forceApprove(address(aavePool), amount);
        
        // 存入到AAVE
        uint256 balanceBefore = IAToken(tokenToAToken[token]).balanceOf(address(this));
        aavePool.supply(token, amount, address(this), 0);
        uint256 balanceAfter = IAToken(tokenToAToken[token]).balanceOf(address(this));
        
        uint256 actualAmount = balanceAfter - balanceBefore;
        
        emit Deposit(msg.sender, token, amount, tokenToAToken[token]);
        
        return actualAmount;
    }
    
    /**
     * @dev 从AAVE提取资金
     */
    function withdraw(address token, uint256 amount) external override nonReentrant returns (uint256) {
        require(isAdapterActive, "Adapter is not active");
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be greater than 0");
        require(tokenToAToken[token] != address(0), "aToken not configured");
        
        address aToken = tokenToAToken[token];
        uint256 currentBalance = IAToken(aToken).balanceOf(address(this));
        require(currentBalance >= amount, "Insufficient balance in adapter");
        
        // 从AAVE提取
        uint256 withdrawnAmount = aavePool.withdraw(token, amount, msg.sender);
        
        emit Withdraw(msg.sender, token, amount, withdrawnAmount);
        
        return withdrawnAmount;
    }
    
    /**
     * @dev 查询用户余额
     */
    function getBalance(address user, address token) external view override returns (uint256) {
        if (!supportedTokens[token] || tokenToAToken[token] == address(0)) {
            return 0;
        }
        
        address aToken = tokenToAToken[token];
        return IAToken(aToken).balanceOf(user);
    }
    
    /**
     * @dev 获取当前APY
     */
    function getAPY() external view override returns (uint256) {
        // 这里简化处理，实际应该从AAVE获取实时数据
        // AAVE的流动性利率是按区块计算的
        return 350; // 3.5% APY，乘以100
    }
    
    /**
     * @dev 获取锁定期
     */
    function getLockPeriod() external pure override returns (uint256) {
        return LOCK_PERIOD;
    }
    
    /**
     * @dev 获取协议名称
     */
    function getProtocolName() external pure override returns (string memory) {
        return "AAVE";
    }
    
    /**
     * @dev 获取风险等级
     */
    function getRiskLevel() external pure override returns (uint8) {
        return uint8(RISK_LEVEL);
    }
    
    /**
     * @dev 检查是否活跃
     */
    function isActive() external view override returns (bool) {
        return isAdapterActive;
    }
    
    /**
     * @dev 获取TVL
     */
    function getTVL(address token) external view override returns (uint256) {
        if (!supportedTokens[token] || tokenToAToken[token] == address(0)) {
            return 0;
        }
        
        address aToken = tokenToAToken[token];
        return IAToken(aToken).balanceOf(address(this));
    }
    
    /**
     * @dev 获取累计收益（简化版本）
     */
    function getAccruedYield(address user, address token) external view override returns (uint256) {
        // 这里简化处理，实际应该计算复利收益
        return 0;
    }
    
    /**
     * @dev 获取支持的代币列表
     */
    function getSupportedTokens() external view override returns (address[] memory) {
        return supportedTokensList;
    }
    
    /**
     * @dev 检查是否支持代币
     */
    function supportsToken(address token) external view override returns (bool) {
        return supportedTokens[token];
    }
    
    /**
     * @dev 添加支持的代币
     */
    function addSupportedToken(address token, address aToken) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(aToken != address(0), "Invalid aToken address");
        
        supportedTokens[token] = true;
        tokenToAToken[token] = aToken;
        supportedTokensList.push(token);
        
        emit TokenSupported(token, aToken);
    }
    
    /**
     * @dev 移除支持的代币
     */
    function removeSupportedToken(address token) external onlyOwner {
        require(supportedTokens[token], "Token not supported");
        
        supportedTokens[token] = false;
        delete tokenToAToken[token];
        
        // 从列表中移除
        for (uint256 i = 0; i < supportedTokensList.length; i++) {
            if (supportedTokensList[i] == token) {
                supportedTokensList[i] = supportedTokensList[supportedTokensList.length - 1];
                supportedTokensList.pop();
                break;
            }
        }
        
        emit TokenUnsupported(token);
    }
    
    /**
     * @dev 设置适配器状态
     */
    function setAdapterActive(bool active) external onlyOwner {
        isAdapterActive = active;
    }
    
    /**
     * @dev 紧急提取所有资金
     */
    function emergencyWithdraw(address token, address recipient) external override onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        
        if (tokenToAToken[token] != address(0)) {
            address aToken = tokenToAToken[token];
            uint256 balance = IAToken(aToken).balanceOf(address(this));
            if (balance > 0) {
                aavePool.withdraw(token, balance, recipient);
            }
        }
    }
}