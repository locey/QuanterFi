// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ConstantsLib} from "./libraries/ConstantsLib.sol";
import {StrategyLib} from "./libraries/StrategyLib.sol";
import {InvestmentId,PositionDirection,TradeType,TradeDetail,IStrategyVault,UserAsset, UserPosition,InvestmentTarget,UnlockInvestment,SharesUnlockRequest} from "./interfaces/IStrategyVault.sol";

contract StrategyVault is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IStrategyVault {

    using SafeERC20 for IERC20;

    /** immutable */
    uint256 public immutable FEE_BASE = ConstantsLib.FEE_BASE;
    uint256 public immutable UNLOCK_LOCK_PERIOD;

    /** storage */
    string public strategySymbol;
    address public underlyingAsset;
    address public feeReceiver;
    uint256 public feeRate;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public tvl;

    /// @dev InvestmentTargets
    mapping(InvestmentId => InvestmentTarget) public investmentTargets;

    // User Assets
    mapping(address => UserAsset) public userAssets;
    
    /// @dev userPosition 聚合头寸，每次投资做更新
    mapping(address=>mapping(InvestmentId=>UserPosition)) public userPositions;
    
    // mapping(address => TradeDetail) public tradeDetails;
    
    // user unlock requests
    mapping(uint256 => SharesUnlockRequest) public unlockRequests;
    /// @dev shares unlock requestId
    uint256 public nextUnlockRequestId = 1;
    uint256 public firstRequestId = 1;

    /// Roles
    bytes32 public constant MANAGER = keccak256("MANAGER"); // 管理员
    bytes32 public constant CURATOR = keccak256("CURATOR"); // 策展人
    bytes32 public constant ALLOCATOR = keccak256("ALLOCATOR"); // 分配者
    bytes32 public constant BOT = keccak256("BOT"); // 机器人

    /** constructor */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(uint256 _unlockLockPeriod) {
        if(_unlockLockPeriod>ConstantsLib.MAX_REQUEST_LOCK_TIME || _unlockLockPeriod<ConstantsLib.MIN_REQUEST_LOCK_TIME)
            revert ErrorsLib.InvalidUnlockLockPeriod();
        _disableInitializers();
        UNLOCK_LOCK_PERIOD = _unlockLockPeriod;
    }

    function initialize(
        address admin,
        address manager,
        string memory _name,
        string memory _symbol,
        string memory _strategySymbol,
        address _underlyingAsset,
        uint256 _endTime
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __AccessControlEnumerable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER, manager);

        _strategy_init(
            _strategySymbol,
            _underlyingAsset,
            _endTime
        );
    }

    function _strategy_init(
        string memory _strategySymbol,
        address _underlyingAsset,
        uint256 _endTime
    ) private {
        underlyingAsset = _underlyingAsset;
        endTime = _endTime;
        strategySymbol = _strategySymbol;
    }

    /** user operations */
    /// @inheritdoc IStrategyVault
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ErrorsLib.ZeroAmount();
        if (_underlyingToken().allowance(msg.sender, address(this)) < amount) revert ErrorsLib.NotEnoughAllowance();

        userAssets[msg.sender].totalAmount += amount;
        tvl += amount;

        emit EventsLib.Deposit(msg.sender, underlyingAsset, amount);

        _underlyingToken().safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IStrategyVault
    function depositWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant {
        if (amount == 0) revert ErrorsLib.ZeroAmount();

        // 尝试使用permit功能
        try IERC20Permit(underlyingAsset).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        ) {
            // Permit成功执行
        } catch {
            revert ErrorsLib.IERC20PermitError("IERC20PermitFailed");
        }

        userAssets[msg.sender].totalAmount += amount;
        tvl += amount;

        emit EventsLib.Deposit(msg.sender, underlyingAsset, amount);

        _underlyingToken().safeTransferFrom(msg.sender, address(this), amount);
    }

    function getUserAssets() external view returns (UserAsset memory){
        return userAssets[msg.sender];
    }

    function getUserPosition(string memory _strategySymbol) external view returns (UserPosition memory){
        InvestmentId investmentTargetId = InvestmentId.wrap(StrategyLib.hashInvestment("HyperLiquid", _strategySymbol));
        return userPositions[msg.sender][investmentTargetId];
    }

    function unlockInvestmentShares(UnlockInvestment[] memory unlockInvestments) external nonReentrant {
        // 遍历unlockInvestments
        for (uint256 i = 0; i < unlockInvestments.length; i++) {
            UnlockInvestment memory unlockInvestment = unlockInvestments[i];
            InvestmentId targetId = unlockInvestment.targetId;
            uint256 unlockShares = unlockInvestment.unlockShares;
            if (unlockShares == 0) continue;

            // UserAsset storage userAsset = userAssets[msg.sender];
            UserPosition storage userPosition = userPositions[msg.sender][targetId];
            if (userPosition.holdShares < userPosition.requestUnholdShares+unlockShares) {
                emit EventsLib.NotEnoughSharesToUnlock(msg.sender, targetId, userPosition.holdShares, block.timestamp);
                continue;
            }
            // 创建解锁请求
            unlockRequests[nextUnlockRequestId] = SharesUnlockRequest({
                targetId: targetId,
                user: msg.sender,
                shares: unlockShares,
                requestTime: block.timestamp,
                processed: false
            });

            emit EventsLib.UnlockSharesRequest(msg.sender, targetId , unlockShares, block.timestamp);
            
            nextUnlockRequestId++;
            userPosition.requestUnholdShares+=unlockShares;
        }
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ErrorsLib.ZeroAmount();
        UserAsset storage userAsset = userAssets[msg.sender];
        if (userAsset.unlockedAmount < amount + userAsset.withdrawedAmount) revert ErrorsLib.NotEnoughWithdrawableAssets();

        // update withdrawedAmount
        userAsset.withdrawedAmount += amount;

        emit EventsLib.Withdraw(msg.sender, underlyingAsset, amount);
        
        // transfer asset to user
        _underlyingToken().safeTransfer(msg.sender, amount);
    }

    /** admin functions */
    function adminWithdraw(address user,uint256 amount) external nonReentrant onlyRole(MANAGER) {
        if (amount == 0) revert ErrorsLib.ZeroAmount();
        if (_underlyingToken().balanceOf(address(this)) < amount) revert ErrorsLib.InsufficientContractBalance();
        UserAsset storage userAsset = userAssets[user];
        if(userAsset.totalAmount < amount+userAsset.lockedAmount) revert ErrorsLib.NotEnoughWithdrawableAssets();
        
        userAsset.lockedAmount+=amount;

        emit EventsLib.AdminWithdraw(msg.sender, underlyingAsset, amount);
        // transfer asset to admin
        _underlyingToken().safeTransfer(msg.sender, amount);
    }

    ///@inheritdoc IStrategyVault
    /// @dev 交易后，计算是否盈利，手续费，更新用户头寸，更新用户总资产，更新策略tvl，更新用户请求
    function updateUserPositionAndAssets(TradeDetail[] memory tradeDetails) external nonReentrant onlyRole(MANAGER) {
        // 遍历tradeDetails
        for (uint256 i = 0; i < tradeDetails.length; i++) { 
            TradeDetail memory tradeDetail = tradeDetails[i];
            UserPosition storage userPosition = userPositions[tradeDetail.user][tradeDetail.targetId];
            UserAsset storage userAsset = userAssets[tradeDetail.user];
            // 计算利润
            (int256 profit, uint256 fee,) = calcProfit(userPosition, tradeDetail);
            if (profit > 0) {
                // 更新用户资产
                userAsset.totalAmount += uint256(profit);
                userAsset.unlockedAmount += uint256(profit);
            }
            userPosition.entryPrice = (
                userPosition.entryPrice * userPosition.holdShares + tradeDetail.tradePrice * tradeDetail.totalShares
            ) / (userPosition.holdShares + tradeDetail.totalShares);
            userPosition.holdShares += tradeDetail.totalShares;
            userAsset.totalAmount += fee;
            userAsset.unlockedAmount += fee;


        }
    }
    
    function calcProfit(
        UserPosition memory position,
        TradeDetail memory trade
    ) internal view returns (int256 profit, uint256 fee, int256 netProfit) {
        // 做多或做空判断
        if (position.direction == PositionDirection.LONG) {
            if (trade.tradeType == TradeType.WITHDRAW) {
                // 卖出时计算盈利
                profit = int256(trade.tradePrice) - int256(position.entryPrice);
                profit = profit * int256(trade.totalShares) / 1e18;
            } else {
                profit = 0; // 买入不计算
            }
        } else if (position.direction == PositionDirection.SHORT) {
            if (trade.tradeType == TradeType.WITHDRAW) {
                // 买入平仓时计算盈利
                profit = int256(position.entryPrice) - int256(trade.tradePrice);
                profit = profit * int256(trade.totalShares) / 1e18;
            } else {
                profit = 0; // 开仓时不计算
            }
        }
        // 如果盈利，计算手续费
        if (profit > 0) {
            fee = uint256(profit) * feeRate / FEE_BASE;
            netProfit = profit - int256(fee);
        } else {
            fee = 0;
            netProfit = profit;
        }
    }


    /** admin only */
    function setFeeRate(uint256 newFee) external onlyRole(MANAGER){
        if (feeRate == newFee) revert ErrorsLib.FeeAlareadySet();
        if (newFee > ConstantsLib.MAX_FEE_RATE) revert ErrorsLib.InvalidFeeRate();
        if (newFee != 0 && feeReceiver == address(0)) revert ErrorsLib.ZeroFeeReceiver();

        feeRate = newFee;

        emit EventsLib.FeeRateSet(msg.sender,newFee);
    }

    function setFeeReceiver(address newReceiver) external onlyRole(MANAGER){
        if (feeReceiver == newReceiver) revert ErrorsLib.FeeReceiverAlreadySet();
        if (newReceiver == address(0) && feeRate != 0) revert ErrorsLib.ZeroFeeReceiver();

        feeReceiver = newReceiver;

        emit EventsLib.FeeReceiverSet(msg.sender,newReceiver);
    }
    /// @dev admin register investment target
    function registerInvestmentTarget(string memory _symbol,address _token) external onlyRole(MANAGER) { 
        InvestmentId investmentTargetId = InvestmentId.wrap(StrategyLib.hashInvestment("HyperLiquid", _symbol));
        if (InvestmentId.unwrap(investmentTargets[investmentTargetId].id) != 0) revert ErrorsLib.InvestmentTargetAlreadyRegistered();
        
        investmentTargets[investmentTargetId] = InvestmentTarget({
            id: investmentTargetId,
            token: _token,
            symbol: _symbol
        });

        emit EventsLib.InvestmentTargetRegistered(msg.sender, investmentTargetId);
    }

    /// @dev underlying token 
    function _underlyingToken() internal view returns (IERC20) {
        return IERC20(underlyingAsset);
    }

    function _sender() internal view returns (address) {
        return msg.sender;
    }

    /// @dev upgrade authorization uups
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}