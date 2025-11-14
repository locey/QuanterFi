// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library ErrorsLib {

    error ZeroAddress();

    error NotWhiteList();

    error AssetsNotWhiteList();

    error ZeroAmount();

    error AlreadyWhiteList();

    error IERC20PermitError(string message);

    error NotEnoughAllowance();
    
    error NotEnoughAssets();

    error InvalidAsset();

    error NotEnoughRequestUnShares();

    error ZeroShares();

    error NotEnoughWithdrawableAssets();

    error InvalidStrategyId();

    error InvalidFeeRate();

    error FeeAlareadySet();

    error ZeroFeeReceiver();

    error FeeReceiverAlreadySet();

    error InvestmentTargetAlreadyRegistered();
    
    error InvalidUnlockLockPeriod();
    
    error InsufficientContractBalance();
    
    error InvalidTradeDetail();
    
    error UnlockRequestNotFound();
    
    error UnlockRequestAlreadyProcessed();
}
