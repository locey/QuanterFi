// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockToken
 * @dev 模拟代币合约，用于测试DeFi聚合器功能
 */
contract MockToken is ERC20, Ownable {
    uint8 private _decimals;
    
    /**
     * @dev 构造函数
     * @param name 代币名称
     * @param symbol 代币符号
     * @param decimalsParam 小数位数
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimalsParam
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = decimalsParam;
        
        // 铸造初始供应量（100万代币）
        uint256 initialSupply = 1000000 * (10 ** decimalsParam);
        _mint(msg.sender, initialSupply);
    }
    
    /**
     * @dev 返回代币的小数位数
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev 铸造代币（仅管理员）
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev 销毁代币（仅管理员）
     * @param amount 销毁数量
     */
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev 批量铸造代币（仅管理员）
     * @param recipients 接收地址数组
     * @param amounts 铸造数量数组
     */
    function batchMint(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(recipients.length == amounts.length, "Length mismatch");
        require(recipients.length > 0, "Empty arrays");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }
    
    /**
     * @dev 获取代币信息
     * @return name_ 代币名称
     * @return symbol_ 代币符号
     * @return decimals_ 小数位数
     * @return totalSupply_ 总供应量
     * @return balance_ 调用者余额
     */
    function getTokenInfo() external view returns (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 balance_
    ) {
        return (
            name(),
            symbol(),
            decimals(),
            totalSupply(),
            balanceOf(msg.sender)
        );
    }
}