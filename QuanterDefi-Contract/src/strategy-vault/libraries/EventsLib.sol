// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library EventsLib { 

    event Deposit(
        address indexed sender,
        uint256 indexed strategyId,
        address indexed asset,
        uint256 amount
    );

    event Withdraw(
        address indexed sender,
        uint256 indexed strategyId,
        address indexed asset,
        uint256 amount
    );

    event Unstack(
        address indexed sender,
        uint256 indexed strategyId,
        address indexed asset,
        uint256 amount
    );

    event UnlockSharesRequest(
        address indexed sender,
        uint256 indexed strategyId,
        uint256 shares,
        uint256 timestamp
    );

}