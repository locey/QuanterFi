// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDeFiAggregator
 * @dev DeFi聚合器主合约接口
 */
interface IDeFiAggregator {
    
    // 用户投资记录结构
    struct UserInvestment {
        address user;           // 用户地址
        address token;          // 代币地址
        string protocol;        // 协议名称
        uint256 amount;         // 投资金额
        uint256 depositTime;    // 存入时间
        uint256 lastUpdateTime; // 最后更新时间
        uint256 accruedYield;   // 累计收益
        bool isActive;         // 是否激活
    }
    
    // 协议信息结构
    struct ProtocolInfo {
        address adapter;        // 适配器合约地址
        bool isActive;         // 是否激活
        uint256 riskLevel;     // 风险等级 (1-5)
        uint256 totalDeposits; // 总存款量
        uint256 lastAPY;       // 最新APY
        uint256 updateTime;    // 更新时间
    }
    
    /**
     * @dev 存入资金到指定协议
     * @param token 代币地址
     * @param amount 存入数量
     * @param protocol 协议名称
     */
    function deposit(address token, uint256 amount, string memory protocol) external;
    
    /**
     * @dev 从指定协议提取资金
     * @param token 代币地址
     * @param amount 提取数量
     * @param protocol 协议名称
     */
    function withdraw(address token, uint256 amount, string memory protocol) external;
    
    /**
     * @dev 查询用户在指定协议中的余额
     * @param user 用户地址
     * @param token 代币地址
     * @param protocol 协议名称
     * @return 用户余额
     */
    function getUserBalance(address user, address token, string memory protocol) external view returns (uint256);
    
    /**
     * @dev 查询指定协议的当前APY
     * @param protocol 协议名称
     * @return 当前APY
     */
    function getCurrentAPY(string memory protocol) external view returns (uint256);
    
    /**
     * @dev 查询用户可提取金额（考虑锁定期）
     * @param user 用户地址
     * @param token 代币地址
     * @param protocol 协议名称
     * @return 可提取金额
     */
    function getWithdrawableAmount(address user, address token, string memory protocol) external view returns (uint256);
    
    /**
     * @dev 获取用户所有投资记录
     * @param user 用户地址
     * @return 投资记录数组
     */
    function getUserInvestments(address user) external view returns (UserInvestment[] memory);
    
    /**
     * @dev 获取用户累计收益
     * @param user 用户地址
     * @param token 代币地址
     * @param protocol 协议名称
     * @return 累计收益
     */
    function getUserYield(address user, address token, string memory protocol) external view returns (uint256);
    
    /**
     * @dev 获取所有支持的协议
     * @return 协议名称数组
     */
    function getSupportedProtocols() external view returns (string[] memory);
    
    /**
     * @dev 获取协议信息
     * @param protocol 协议名称
     * @return 协议信息
     */
    function getProtocolInfo(string memory protocol) external view returns (ProtocolInfo memory);
    
    /**
     * @dev 获取用户总资产价值（USD计价）
     * @param user 用户地址
     * @return 总资产价值（乘以1e18）
     */
    function getUserTotalAssets(address user) external view returns (uint256);
    
    /**
     * @dev 更新协议APY（仅管理员）
     * @param protocol 协议名称
     * @param newAPY 新的APY
     */
    function updateProtocolAPY(string memory protocol, uint256 newAPY) external;
    
    /**
     * @dev 添加新协议（仅管理员）
     * @param protocol 协议名称
     * @param adapter 适配器地址
     * @param riskLevel 风险等级
     */
    function addProtocol(string memory protocol, address adapter, uint256 riskLevel) external;
    
    /**
     * @dev 暂停/激活协议（仅管理员）
     * @param protocol 协议名称
     * @param isActive 是否激活
     */
    function setProtocolActive(string memory protocol, bool isActive) external;
    
    /**
     * @dev 紧急暂停整个系统（仅管理员）
     * @param paused 是否暂停
     */
    function setEmergencyPause(bool paused) external;
    
    /**
     * @dev 事件：用户存入资金
     */
    event Deposit(
        address indexed user,
        address indexed token,
        string indexed protocol,
        uint256 amount,
        uint256 timestamp
    );
    
    /**
     * @dev 事件：用户提取资金
     */
    event Withdraw(
        address indexed user,
        address indexed token,
        string indexed protocol,
        uint256 amount,
        uint256 yield,
        uint256 timestamp
    );
    
    /**
     * @dev 事件：协议APY更新
     */
    event ProtocolAPYUpdated(
        string indexed protocol,
        uint256 oldAPY,
        uint256 newAPY,
        uint256 timestamp
    );
    
    /**
     * @dev 事件：新协议添加
     */
    event ProtocolAdded(
        string indexed protocol,
        address indexed adapter,
        uint256 riskLevel,
        uint256 timestamp
    );
}