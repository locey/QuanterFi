// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {InvestmentId} from "../interfaces/IStrategyVault.sol";


library EventsLib { 

    event Deposit(
        address indexed sender,
        address indexed asset,
        uint256 amount
    );

    event Withdraw(
        address indexed sender,
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
        InvestmentId indexed InvestmentTargetId,
        uint256 shares,
        uint256 timestamp
    );

    event FeeRateSet(
        address indexed sender,
        uint256 feeRate
    );

    event InvestmentTargetRegistered(
        address indexed sender,
        InvestmentId indexed investmentTargetId
    );
    
    event AdminWithdraw(
        address indexed sender,
        address indexed asset,
        uint256 amount
    );
    
    event NotEnoughSharesToUnlock(
        address indexed user,
        InvestmentId indexed targetId,
        uint256 holdShares,
        uint256 timestamp
    );
    
    event FeeReceiverSet(
        address indexed sender,
        address indexed feeReceiver
    );
    
    event UserPositionUpdated(
        address indexed user,
        InvestmentId indexed targetId,
        uint256 totalShares,
        uint256 entryPrice,
        uint256 timestamp
    );
    
    event TradeProcessed(
        address indexed user,
        InvestmentId indexed targetId,
        uint256 unlockRequestId,
        int256 profit,
        uint256 fee,
        uint256 timestamp
    );
    
    event UnlockRequestProcessed(
        uint256 indexed requestId,
        address indexed user,
        InvestmentId indexed targetId,
        uint256 shares,
        uint256 timestamp
    );
}