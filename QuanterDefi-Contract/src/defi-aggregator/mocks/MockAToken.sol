// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// 简化的 aToken，用于本地/测试网集成测试
contract MockAToken is ERC20, Ownable {
	constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable(msg.sender) {}

	function mint(address to, uint256 amount) external onlyOwner {
		_mint(to, amount);
	}

	function burn(address from, uint256 amount) external onlyOwner {
		_burn(from, amount);
	}
}


