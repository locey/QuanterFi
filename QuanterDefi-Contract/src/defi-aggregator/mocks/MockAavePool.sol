// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MockAToken.sol";

// 简化的 Aave Pool，仅用于本地/测试网集成测试
contract MockAavePool is Ownable {
	struct Reserve {
		address aToken;
		bool isEnabled;
	}

	mapping(address => Reserve) public reserves; // underlying => aToken

	event ReserveListed(address indexed asset, address indexed aToken);
	event Supplied(address indexed asset, uint256 amount, address indexed onBehalfOf);
	event Withdrawn(address indexed asset, uint256 amount, address indexed to);

	constructor() Ownable(msg.sender) {}

	function listReserve(address asset, address aToken) external onlyOwner {
		require(asset != address(0) && aToken != address(0), "invalid addr");
		reserves[asset] = Reserve({ aToken: aToken, isEnabled: true });
		emit ReserveListed(asset, aToken);
	}

	// 与 Aave V3 Pool 接口对齐（简化）
	function supply(address asset, uint256 amount, address onBehalfOf, uint16 /*referralCode*/ ) external {
		Reserve memory r = reserves[asset];
		require(r.isEnabled, "reserve not enabled");
		require(amount > 0, "amount=0");

		// 从调用者（通常为适配器）转入底层资产到池
		IERC20(asset).transferFrom(msg.sender, address(this), amount);

		// 铸造 aToken 给 onBehalfOf
		MockAToken(r.aToken).mint(onBehalfOf, amount);
		emit Supplied(asset, amount, onBehalfOf);
	}

	function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
		Reserve memory r = reserves[asset];
		require(r.isEnabled, "reserve not enabled");
		require(amount > 0, "amount=0");

		// 从调用者（通常为适配器）燃烧 aToken
		MockAToken(r.aToken).burn(msg.sender, amount);

		// 将底层资产从池转给目标地址
		IERC20(asset).transfer(to, amount);
		emit Withdrawn(asset, amount, to);
		return amount;
	}
}


