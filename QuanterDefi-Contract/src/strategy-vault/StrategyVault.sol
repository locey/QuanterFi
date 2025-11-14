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
        startTime = block.timestamp;
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

    /// @notice 获取待处理的解锁请求（已过锁定期且未处理）
    /// @param maxCount 最大返回数量，0表示返回所有
    /// @return requests 待处理的解锁请求数组
    /// @return requestIds 对应的请求ID数组
    function getPendingUnlockRequests(uint256 maxCount) 
        external 
        view 
        returns (SharesUnlockRequest[] memory requests, uint256[] memory requestIds) 
    {
        // 第一次遍历：统计符合条件的请求数量
        uint256 count = 0;
        uint256 currentTime = block.timestamp;
        
        for (uint256 i = firstRequestId; i < nextUnlockRequestId; i++) {
            SharesUnlockRequest memory request = unlockRequests[i];
            // 检查：未处理 && 已过锁定期
            if (!request.processed && (currentTime >= request.requestTime + UNLOCK_LOCK_PERIOD)) {
                count++;
                if (maxCount > 0 && count >= maxCount) break;
            }
        }
        
        // 初始化返回数组
        requests = new SharesUnlockRequest[](count);
        requestIds = new uint256[](count);
        
        // 第二次遍历：填充数组
        uint256 index = 0;
        for (uint256 i = firstRequestId; i < nextUnlockRequestId && index < count; i++) {
            SharesUnlockRequest memory request = unlockRequests[i];
            if (!request.processed && (currentTime >= request.requestTime + UNLOCK_LOCK_PERIOD)) {
                requests[index] = request;
                requestIds[index] = i;
                index++;
            }
        }
    }

    /// @notice 获取用户的解锁请求（包括待处理和已处理）
    /// @param user 用户地址
    /// @return requests 用户的解锁请求数组
    /// @return requestIds 对应的请求ID数组
    /// @return statuses 请求状态数组（0:锁定中, 1:可处理, 2:已处理）
    function getUserUnlockRequests(address user) 
        external 
        view 
        returns (
            SharesUnlockRequest[] memory requests, 
            uint256[] memory requestIds,
            uint8[] memory statuses
        ) 
    {
        // 第一次遍历：统计用户的请求数量
        uint256 count = 0;
        for (uint256 i = firstRequestId; i < nextUnlockRequestId; i++) {
            if (unlockRequests[i].user == user) {
                count++;
            }
        }
        
        // 初始化返回数组
        requests = new SharesUnlockRequest[](count);
        requestIds = new uint256[](count);
        statuses = new uint8[](count);
        
        // 第二次遍历：填充数组
        uint256 index = 0;
        uint256 currentTime = block.timestamp;
        for (uint256 i = firstRequestId; i < nextUnlockRequestId && index < count; i++) {
            SharesUnlockRequest memory request = unlockRequests[i];
            if (request.user == user) {
                requests[index] = request;
                requestIds[index] = i;
                
                // 判断状态：0=锁定中, 1=可处理, 2=已处理
                if (request.processed) {
                    statuses[index] = 2;
                } else if (currentTime >= request.requestTime + UNLOCK_LOCK_PERIOD) {
                    statuses[index] = 1;
                } else {
                    statuses[index] = 0;
                }
                index++;
            }
        }
    }

    /// @notice 获取单个解锁请求的详细信息
    /// @param requestId 请求ID
    /// @return request 解锁请求详情
    /// @return canProcess 是否可以处理（已过锁定期且未处理）
    /// @return remainingTime 剩余锁定时间（秒），如果已过期则为0
    function getUnlockRequestDetail(uint256 requestId) 
        external 
        view 
        returns (
            SharesUnlockRequest memory request,
            bool canProcess,
            uint256 remainingTime
        ) 
    {
        require(requestId >= firstRequestId && requestId < nextUnlockRequestId, "Invalid request ID");
        
        request = unlockRequests[requestId];
        uint256 currentTime = block.timestamp;
        uint256 unlockTime = request.requestTime + UNLOCK_LOCK_PERIOD;
        
        canProcess = !request.processed && (currentTime >= unlockTime);
        
        if (currentTime < unlockTime) {
            remainingTime = unlockTime - currentTime;
        } else {
            remainingTime = 0;
        }
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
        if (tradeDetails.length == 0) revert ErrorsLib.InvalidTradeDetail();
        
        // 遍历tradeDetails
        for (uint256 i = 0; i < tradeDetails.length; i++) { 
            TradeDetail memory tradeDetail = tradeDetails[i];
            
            // 验证交易详情
            if (tradeDetail.user == address(0)) revert ErrorsLib.ZeroAddress();
            if (tradeDetail.totalShares == 0) revert ErrorsLib.ZeroShares();
            if (tradeDetail.tradePrice == 0) revert ErrorsLib.InvalidTradeDetail();
            
            UserPosition storage userPosition = userPositions[tradeDetail.user][tradeDetail.targetId];
            UserAsset storage userAsset = userAssets[tradeDetail.user];
            
            int256 profit = 0;
            uint256 fee = 0;
            int256 netProfit = 0;
            
            // 处理不同类型的交易
            if (tradeDetail.tradeType == TradeType.INVEST) {
                // 投资（买入）交易
                _processInvestTrade(userPosition, userAsset, tradeDetail);
            } else if (tradeDetail.tradeType == TradeType.WITHDRAW) {
                // 提取（卖出）交易 - 计算盈亏
                (profit, fee, netProfit) = calcProfit(userPosition, tradeDetail);
                _processWithdrawTrade(userPosition, userAsset, tradeDetail, profit, fee, netProfit);
            }
            
            // 如果有关联的解锁请求，处理请求
            if (tradeDetail.unlockRequestId > 0) {
                _processUnlockRequest(tradeDetail.unlockRequestId, tradeDetail.user, tradeDetail.targetId, tradeDetail.totalShares);
            }
            
            // 发出交易处理事件
            emit EventsLib.TradeProcessed(
                tradeDetail.user,
                tradeDetail.targetId,
                tradeDetail.unlockRequestId,
                profit,
                fee,
                block.timestamp
            );
            
            // 发出头寸更新事件
            emit EventsLib.UserPositionUpdated(
                tradeDetail.user,
                tradeDetail.targetId,
                userPosition.holdShares,
                userPosition.entryPrice,
                block.timestamp
            );
        }
    }
    
    /// @dev 处理投资交易（买入）
    function _processInvestTrade(
        UserPosition storage userPosition,
        UserAsset storage userAsset,
        TradeDetail memory tradeDetail
    ) private {
        // 更新用户头寸 - 计算新的平均价格
        if (userPosition.holdShares == 0) {
            // 首次建仓
            userPosition.targetId = tradeDetail.targetId;
            userPosition.direction = PositionDirection.LONG; // 默认做多
            userPosition.entryPrice = tradeDetail.tradePrice;
            userPosition.totalAmount = tradeDetail.totalAmount;
        } else {
            // 加仓 - 计算加权平均价格
            userPosition.entryPrice = (
                userPosition.entryPrice * userPosition.holdShares + 
                tradeDetail.tradePrice * tradeDetail.totalShares
            ) / (userPosition.holdShares + tradeDetail.totalShares);
            userPosition.totalAmount += tradeDetail.totalAmount;
        }
        
        userPosition.holdShares += tradeDetail.totalShares;
        userPosition.lastTime = block.timestamp;
        
        // 验证用户资产足够（已通过adminWithdraw锁定）
        if (userAsset.lockedAmount < tradeDetail.totalAmount) {
            revert ErrorsLib.NotEnoughAssets();
        }
        
        // 减少锁定资产（因为已经用于投资）
        userAsset.lockedAmount -= tradeDetail.totalAmount;
    }
    
    /// @dev 处理提取交易（卖出）
    function _processWithdrawTrade(
        UserPosition storage userPosition,
        UserAsset storage userAsset,
        TradeDetail memory tradeDetail,
        int256 profit,
        uint256 fee,
        int256 netProfit
    ) private {
        // 验证用户持有足够的份额
        if (userPosition.holdShares < tradeDetail.totalShares) {
            revert ErrorsLib.NotEnoughRequestUnShares();
        }
        
        // 减少持仓份额
        userPosition.holdShares -= tradeDetail.totalShares;
        
        // 如果有关联请求，减少请求未持有份额
        if (tradeDetail.unlockRequestId > 0 && userPosition.requestUnholdShares >= tradeDetail.totalShares) {
            userPosition.requestUnholdShares -= tradeDetail.totalShares;
        }
        
        // 增加已解锁份额
        userPosition.unholdShares += tradeDetail.totalShares;
        userPosition.lastTime = block.timestamp;
        
        // 更新用户资产 - 添加卖出收益
        userAsset.unlockedAmount += tradeDetail.totalAmount;
        
        // 处理盈利和手续费
        if (profit > 0) {
            // 盈利情况：净利润归用户，手续费归协议
            userAsset.totalAmount += uint256(netProfit);
            userAsset.unlockedAmount += uint256(netProfit);
            
            // 手续费处理
            if (fee > 0 && feeReceiver != address(0)) {
                // 手续费从总资产中转移到费用接收者
                // 注意：实际转账由管理员在链下完成后再充值到feeReceiver
                userAsset.totalAmount -= fee;
            }
            
            // 更新TVL - 减去手续费
            if (tvl >= fee) {
                tvl -= fee;
            }
        } else if (profit < 0) {
            // 亏损情况：减少用户总资产
            uint256 loss = uint256(-profit);
            if (userAsset.totalAmount >= loss) {
                userAsset.totalAmount -= loss;
            } else {
                userAsset.totalAmount = 0;
            }
            
            // 更新TVL - 减去亏损
            if (tvl >= loss) {
                tvl -= loss;
            }
        }
    }
    
    /// @dev 处理解锁请求
    function _processUnlockRequest(
        uint256 requestId,
        address user,
        InvestmentId targetId,
        uint256 shares
    ) private {
        // 验证请求存在
        if (requestId >= nextUnlockRequestId || requestId < firstRequestId) {
            revert ErrorsLib.UnlockRequestNotFound();
        }
        
        SharesUnlockRequest storage request = unlockRequests[requestId];
        
        // 验证请求未被处理
        if (request.processed) {
            revert ErrorsLib.UnlockRequestAlreadyProcessed();
        }
        
        // 验证请求信息匹配
        if (request.user != user || InvestmentId.unwrap(request.targetId) != InvestmentId.unwrap(targetId)) {
            revert ErrorsLib.InvalidTradeDetail();
        }
        
        // 验证份额匹配
        if (request.shares != shares) {
            revert ErrorsLib.InvalidTradeDetail();
        }
        
        // 标记请求为已处理
        request.processed = true;
        
        // 如果这是队列中的第一个请求，移动firstRequestId指针
        if (requestId == firstRequestId) {
            // 向前移动指针，跳过所有已处理的请求
            while (firstRequestId < nextUnlockRequestId && unlockRequests[firstRequestId].processed) {
                firstRequestId++;
            }
        }
        
        emit EventsLib.UnlockRequestProcessed(
            requestId,
            user,
            targetId,
            shares,
            block.timestamp
        );
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