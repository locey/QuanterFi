// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {StrategyVault} from "./StrategyVault.sol";

/**
 * @title StrategyVaultFactory
 * @dev 工厂合约，用于创建StrategyVault合约实例
 */
contract StrategyVaultFactory is Ownable {
    // StrategyVault实现合约地址
    address public vaultImplementation;
    
    // unlock lock period (7 days)
    uint256 public immutable unlockLockPeriod;
    
    // 已创建的vault合约映射
    mapping(string => address) public symbolVault;
    
    // 所有vault合约列表
    address[] public allVaults;
    
    // 策略计数器
    uint256 public nextStrategyCount = 1;
    
    // 事件定义
    event VaultCreated(
        address indexed vault, 
        address indexed owner, 
        address indexed asset,
        string strategySymbol,
        uint256 strategyCount
    );
    event ImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);
    
    /**
     * @dev 构造函数
     * @param _vaultImplementation StrategyVault实现合约地址
     * @param _unlockLockPeriod 解锁锁定期（秒）
     */
    constructor(address _vaultImplementation, uint256 _unlockLockPeriod) Ownable(msg.sender) {
        require(_vaultImplementation != address(0), "Invalid implementation address");
        vaultImplementation = _vaultImplementation;
        unlockLockPeriod = _unlockLockPeriod;
    }
    
    /**
     * @dev 创建新的StrategyVault合约
     * @param admin 管理员地址
     * @param manager 管理者地址
     * @param asset 底层资产合约地址
     * @param name Vault名称
     * @param symbol Vault代币符号
     * @param strategySymbol 策略符号
     * @param endTime 策略结束时间
     * @return vaultAddress 新创建的vault合约地址
     */
    function createVault(
        address admin,
        address manager,
        address asset,
        string memory name,
        string memory symbol,
        string memory strategySymbol,
        uint256 endTime
    ) external returns (address vaultAddress) {
        require(admin != address(0), "Invalid admin address");
        require(manager != address(0), "Invalid manager address");
        require(asset != address(0), "Invalid asset address");
        require(symbolVault[strategySymbol] == address(0), "Strategy symbol already exists");
        
        // 部署新的代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(
            vaultImplementation,
            abi.encodeWithSelector(
                StrategyVault.initialize.selector,
                admin,
                manager,
                name,
                symbol,
                strategySymbol,
                asset,
                endTime
            )
        );
        
        vaultAddress = address(proxy);
        
        // 记录用户vault
        symbolVault[strategySymbol] = vaultAddress;
        
        // 添加到所有vault列表
        allVaults.push(vaultAddress);
        
        uint256 strategyCount = nextStrategyCount;
        nextStrategyCount++;
        
        emit VaultCreated(vaultAddress, msg.sender, asset, strategySymbol, strategyCount);
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
        require(_newImplementation != address(0), "Invalid implementation address");
        address oldImplementation = vaultImplementation;
        vaultImplementation = _newImplementation;
        emit ImplementationUpdated(oldImplementation, _newImplementation);
    }
    
    /**
     * @dev 获取vault总数
     * @return count vault总数
     */
    function getVaultCount() external view returns (uint256 count) {
        return allVaults.length;
    }
}