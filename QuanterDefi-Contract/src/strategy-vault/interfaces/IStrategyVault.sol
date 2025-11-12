// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


type InvestmentId is bytes32;

/** trade type */ 
enum TradeType {
    INVEST,
    WITHDRAW
}
enum PositionDirection {
     LONG, // 多
     SHORT // 空
}


/** user asset */
struct UserAsset {
    uint256 totalAmount;
    uint256 lockedAmount;

    uint256 unlockedAmount;
    uint256 withdrawedAmount;
}

/** investment target */
struct InvestmentTarget {
    InvestmentId id;          // keccak256("HYPERLIQUID" + symbol)
    string symbol;       // e.g. "ETH-PERP"
    address token;       // optional, settlement token
}

/** user Position */
/// @dev one user more than one investment
/// @dev shares from StrategyVault minted to user
struct UserPosition{
    InvestmentId targetId;
    PositionDirection direction;
    uint256 totalAmount;
    uint256 entryPrice;// 平均价格
    uint256 lastTime;
    uint256 holdShares;
    uint256 requestUnholdShares;
    uint256 unholdShares;
}

/** user trade detail */
struct TradeDetail {
    uint256 unlockRequestId;
    address user;
    InvestmentId targetId;
    /// @dev INVEST or WITHDRAW
    TradeType tradeType;
    uint256 totalAmount;
    uint256 totalShares;
    uint256 tradePrice;
    uint256 tradeTime;
}

/** unlock investment shares */
struct UnlockInvestment{
    InvestmentId targetId;
    uint256 unlockShares;
}

/** shares unlock request  */
struct SharesUnlockRequest {
    InvestmentId targetId;
    address user;
    uint256 shares;
    uint256 requestTime; 
    bool processed; 
}

interface IStrategyVaultBase{
    /// @notice the BASE_FEE
    function FEE_BASE() external view returns (uint256);

    /// @notice the unlock lock period
    function UNLOCK_LOCK_PERIOD() external view returns (uint256);

    /// @notice the vault underlyingAsset
    function underlyingAsset() external view returns (address);

    /// @notice the STRATEGY_CODE
    function strategySymbol() external view returns (string memory);

    /// @notice the current feeRate 
    function feeRate() external view returns (uint256);
    
    /// @notice the feeReceiver
    function feeReceiver() external view returns (address);

    /// @notice strategy startTime
    function startTime() external view returns (uint256);

    /// @notice strategy endTime
    function endTime() external view returns (uint256);

    /// @notice the strategy TVL
    function tvl() external view returns (uint256);

    /// @notice set feeRate
    function setFeeRate(uint256 _feeRate) external;

    /// @notice set feeReceiver
    function setFeeReceiver(address _feeReceiver) external;

    /// @notice register investment target
    function registerInvestmentTarget(string memory _symbol,address _token) external;
}

interface IStrategyVault is IStrategyVaultBase {

    /// @notice user deposit amount
    function deposit(uint256 amount) external;

    /// @notice user deposit amount with permit
    function depositWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice get user assets
    function getUserAssets() external view returns (UserAsset memory);

    /// @notice get user Position
    function getUserPosition(string memory _strategySymbol) external view returns (UserPosition memory);
   
    /// @notice user request unlock shares
    /// @dev use request queue to unlock shares
    function unlockInvestmentShares(UnlockInvestment[] memory unlockInvestments) external;

    /// @notice user withdraw amount
    function withdraw(uint256 amount) external;

    /// @notice admin withdraw amount
    /// @dev admin use user asset to buy hyperliquid investment targets
    /// @dev admin can withdraw at any time based on the strategy
    function adminWithdraw(address user,uint256 amount) external;

    /// @notice admin update user positioin and assets after buy hyperliquid investment targets
    /// @dev update position and assets based on trade details batch.
    function updateUserPositionAndAssets(TradeDetail[] memory tradeDetails) external;

}