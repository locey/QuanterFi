// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title CollectVaultFactory
 * @dev 工厂合约，用于创建CollectVault合约实例
 */
contract CollectVaultFactory is Ownable {
    // CollectVault实现合约地址
    address public vaultImplementation;
    
    // 已创建的vault合约映射
    mapping(address => address) public userVaults;
    
    // 所有vault合约列表
    address[] public allVaults;
    
    // 事件定义
    event VaultCreated(address indexed vault, address indexed owner, address asset);
    
    /**
     * @dev 构造函数
     * @param _vaultImplementation CollectVault实现合约地址
     */
    constructor(address _vaultImplementation) Ownable(msg.sender) {
        vaultImplementation = _vaultImplementation;
    }
    
    /**
     * @dev 创建新的CollectVault合约
     * @param asset 底层资产合约地址
     * @param name Vault名称
     * @param symbol Vault代币符号
     * @return vaultAddress 新创建的vault合约地址
     */
    // function createVault(
    //     IERC20 asset,
    //     string memory name,
    //     string memory symbol
    // ) external returns (address vaultAddress) {
    //     // 部署新的代理合约
    //     ERC1967Proxy proxy = new ERC1967Proxy(
    //         vaultImplementation,
    //         abi.encodeWithSelector(
    //             CollectVault.initialize.selector,
    //             asset,
    //             name,
    //             symbol,
    //             msg.sender  // 将创建者设置为vault的所有者
    //         )
    //     );
        
    //     vaultAddress = address(proxy);
        
    //     // 记录用户vault
    //     userVaults[msg.sender] = vaultAddress;
        
    //     // 添加到所有vault列表
    //     allVaults.push(vaultAddress);
        
    //     emit VaultCreated(vaultAddress, msg.sender, address(asset));
    // }
    
    // /**
    //  * @dev 获取用户vault地址
    //  * @param user 用户地址
    //  * @return vaultAddress 用户的vault地址
    //  */
    // function getUserVault(address user) external view returns (address vaultAddress) {
    //     return userVaults[user];
    // }
    
    // /**
    //  * @dev 获取所有vault地址列表
    //  * @return vaults 所有vault地址数组
    //  */
    // function getAllVaults() external view returns (address[] memory vaults) {
    //     return allVaults;
    // }
    
    // /**
    //  * @dev 更新实现合约地址（仅所有者可调用）
    //  * @param _newImplementation 新的实现合约地址
    //  */
    // function updateImplementation(address _newImplementation) external onlyOwner {
    //     vaultImplementation = _newImplementation;
    // }
}