// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {InvestmentTarget} from "./interfaces/IStrategyVault.sol";
import {StrategyVault} from "./StrategyVault.sol";

/**
 * @title StrategyVaultFactory
 * @dev 工厂合约，用于创建StrategyVault合约实例
 */
contract StrategyVaultFactory is Ownable {
    // StrategyVault实现合约地址
    address public vaultImplementation;
    
    // 已创建的vault合约映射
    mapping(address => address) public userVaults;
    
    // 所有vault合约列表
    address[] public allVaults;
    
    // 策略ID计数器
    uint256 public nextStrategyId = 1;
    
    // 事件定义
    event VaultCreated(address indexed vault, address indexed owner, address asset, uint256 strategyId);
    
    /**
     * @dev 构造函数
     * @param _vaultImplementation StrategyVault实现合约地址
     */
    constructor(address _vaultImplementation) Ownable(msg.sender) {
        vaultImplementation = _vaultImplementation;
    }
    
    /**
     * @dev 创建新的StrategyVault合约
     * @param admin 管理员地址
     * @param manager 管理者地址
     * @param asset 底层资产合约地址
     * @param name Vault名称
     * @param symbol Vault代币符号
     * @param strategyName 策略名称
     * @param targets 投资标的数组
     * @param endTime 策略结束时间
     * @param performanceFeeRate 性能费率
     * @return vaultAddress 新创建的vault合约地址
     */
    function createVault(
        address admin,
        address manager,
        IERC20 asset,
        string memory name,
        string memory symbol,
        string memory strategyName,
        InvestmentTarget[] memory targets,
        uint256 endTime,
        uint256 performanceFeeRate
    ) external returns (address vaultAddress) {
        // 生成策略ID
        uint256 strategyId = nextStrategyId;
        nextStrategyId++;
        
        // 部署新的代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(
            vaultImplementation,
            abi.encodeWithSelector(
                StrategyVault.initialize.selector,
                admin,
                manager,
                address(asset),
                name,
                symbol,
                strategyId,
                strategyName,
                targets,
                endTime,
                performanceFeeRate
            )
        );
        
        vaultAddress = address(proxy);
        
        // 记录用户vault
        userVaults[msg.sender] = vaultAddress;
        
        // 添加到所有vault列表
        allVaults.push(vaultAddress);
        
        emit VaultCreated(vaultAddress, msg.sender, address(asset), strategyId);
    }
    
    /**
     * @dev 获取用户vault地址
     * @param user 用户地址
     * @return vaultAddress 用户的vault地址
     */
    function getUserVault(address user) external view returns (address vaultAddress) {
        return userVaults[user];
    }
    
    /**
     * @dev 获取所有vault地址列表
     * @return vaults 所有vault地址数组
     */
    function getAllVaults() external view returns (address[] memory vaults) {
        return allVaults;
    }
    
    /**
     * @dev 更新实现合约地址（仅所有者可调用）
     * @param _newImplementation 新的实现合约地址
     */
    function updateImplementation(address _newImplementation) external onlyOwner {
        vaultImplementation = _newImplementation;
    }
}