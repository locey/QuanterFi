// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IProtocolAdapter
 * @dev DeFi协议适配器接口，定义所有协议适配器必须实现的标准方法
 */
interface IProtocolAdapter {
    /**
     * @dev 存入资金到协议
     * @param token 代币地址
     * @param amount 存入数量
     * @return 实际存入的数量
     */
    function deposit(address token, uint256 amount) external returns (uint256);
    
    /**
     * @dev 从协议提取资金
     * @param token 代币地址
     * @param amount 提取数量
     * @return 实际提取的数量
     */
    function withdraw(address token, uint256 amount) external returns (uint256);
    
    /**
     * @dev 查询用户在协议中的余额
     * @param user 用户地址
     * @param token 代币地址
     * @return 用户余额
     */
    function getBalance(address user, address token) external view returns (uint256);
    
    /**
     * @dev 获取协议的当前APY（年化收益率）
     * @return 当前APY（乘以10000的整数，如500表示5%）
     */
    function getAPY() external view returns (uint256);
    
    /**
     * @dev 获取协议的锁定期（秒）
     * @return 锁定期秒数
     */
    function getLockPeriod() external view returns (uint256);
    
    /**
     * @dev 获取协议名称
     * @return 协议名称
     */
    function getProtocolName() external pure returns (string memory);
    
    /**
     * @dev 获取协议的风险等级
     * @return 风险等级（1-5，1最低，5最高）
     */
    function getRiskLevel() external view returns (uint8);
    
    /**
     * @dev 检查协议是否处于活跃状态
     * @return 是否活跃
     */
    function isActive() external view returns (bool);
    
    /**
     * @dev 获取协议的总锁仓量（TVL）
     * @param token 代币地址
     * @return TVL数量
     */
    function getTVL(address token) external view returns (uint256);
    
    /**
     * @dev 计算用户的累计收益
     * @param user 用户地址
     * @param token 代币地址
     * @return 累计收益
     */
    function getAccruedYield(address user, address token) external view returns (uint256);
    
    /**
     * @dev 获取协议支持的所有代币
     * @return 支持的代币地址数组
     */
    function getSupportedTokens() external view returns (address[] memory);
    
    /**
     * @dev 检查代币是否被协议支持
     * @param token 代币地址
     * @return 是否支持
     */
    function supportsToken(address token) external view returns (bool);
    
    /**
     * @dev 紧急提取所有资金（仅管理员）
     * @param token 代币地址
     * @param recipient 接收地址
     */
    function emergencyWithdraw(address token, address recipient) external;
}