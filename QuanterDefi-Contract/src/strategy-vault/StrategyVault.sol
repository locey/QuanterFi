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
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {IStrategyVault,UserAsset, UserInvestment,InvestmentTarget, TradeDetail, Strategy,UnlockRequest} from "./interfaces/IStrategyVault.sol";

contract StrategyVault is
    Initializable,
    ERC20PermitUpgradeable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IStrategyVault {

    using SafeERC20 for IERC20;
    // 手续费分母
    uint256 public constant FEE_BASE = 10000;
    // 解锁资产锁定期
    uint256 public UNLOCK_LOCK_PERIOD = 7 days;
    // 解锁份额requstId ， 从1开    始，避免零值开始，节省gas
    uint256 public nextUnlockRequestId = 1;

    uint256 public firstRequestId = 1;


    //底层资产
    IERC20 public underlyingAsset;
    // 策略
    Strategy public strategy;

    // User Assets
    mapping(address => UserAsset) public totalAssets; // 用户存入总资产
    
    //User Trade Details
    mapping (address => TradeDetail) public tradeDetails;
    
    // user strategy invenstment
    mapping(address => mapping(uint256 => UserInvestment)) public userInvestments;

    // user unlock requests
    mapping(uint256 => UnlockRequest) public unlockRequests;

    /// Roles
    bytes32 public constant MANAGER = keccak256("MANAGER"); // 管理员
    bytes32 public constant CURATOR = keccak256("CURATOR"); // 策展人
    bytes32 public constant ALLOCATOR = keccak256("ALLOCATOR"); // 分配者
    bytes32 public constant BOT = keccak256("BOT"); // 机器人

    /* Constructor */
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address manager,
        address _asset,
        string memory _name,
        string memory _symbol,
        uint256 _strategyId,
        string memory _strategyName,
        InvestmentTarget[] memory _targets,
        uint256 _endTime,
        uint256 _performanceFeeRate
    ) public initializer {
        if (admin == address(0)) revert ErrorsLib.ZeroAddress();
        if (manager == address(0)) revert ErrorsLib.ZeroAddress();

        __ERC20Permit_init(_name);
        __AccessControlEnumerable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER, manager);

        _strategy_init(
            _asset,
            _strategyId,
            _strategyName,
            _targets,
            _endTime,
            _performanceFeeRate
        );
    }

    function _strategy_init(
        address _asset,
        uint256 _strategyId,
        string memory _strategyName,
        InvestmentTarget[] memory _targets,
        uint256 _endTime,
        uint256 _performanceFeeRate
    ) private {
        underlyingAsset = IERC20(_asset);
        strategy = Strategy ({
            Id: _strategyId,
            StrategyVaultAddress: address(this),
            name: _strategyName,
            targets: _targets,
            apy: 0,
            tvl: 0,
            startTime: block.timestamp,
            endTime: _endTime,
            underlyingAsset: IERC20(_asset),
            performanceFeeRate: _performanceFeeRate
        });
        
    }
    /**
     * @dev 用户资产存入
     * @param asset 存入资产类型
     * @param amount 存入资产数量
     */
    function deposit(uint256 strategyId, IERC20 asset, uint256 amount) public nonReentrant {
        if (address(asset) != address(underlyingAsset)) revert ErrorsLib.InvalidAsset();
        if (amount == 0) revert ErrorsLib.ZeroAmount();
        if (asset.allowance(msg.sender, address(this)) < amount) revert ErrorsLib.NotEnoughAllowance();

        // 更新用户资产和策略总锁仓金额
        totalAssets[msg.sender].strategyId = strategyId;
        totalAssets[msg.sender].totalAmount += amount;
        strategy.tvl += amount;

        emit EventsLib.Deposit(msg.sender,strategyId, address(asset), amount);

        // 资产转入本合约
        asset.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev 支持Permit的存款函数
     * @param asset 存入资产类型
     * @param amount 存入资产数量
     * @param deadline 签名有效期
     * @param v 签名参数
     * @param r 签名参数
     * @param s 签名参数
     */
    function depositWithPermit(
        uint256 strategyId,
        IERC20 asset,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant {
        if (address(asset) != address(underlyingAsset)) revert ErrorsLib.InvalidAsset();
        if (amount == 0) revert ErrorsLib.ZeroAmount();

        // 尝试使用permit功能
        try IERC20Permit(address(asset)).permit(
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

        // 更新用户资产和策略总锁仓金额
        totalAssets[msg.sender].strategyId = strategyId;
        totalAssets[msg.sender].totalAmount += amount;
        strategy.tvl += amount;

        emit EventsLib.Deposit(msg.sender, strategyId, address(asset), amount);

        // 资产转入本合约
        asset.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev 用户申请解锁策略份额
     * @param strategyId 申请解锁的策略ID
     * @param shares 申请解锁的策略份额
     */
    function requestUnlock(uint256 strategyId,uint256 shares) public nonReentrant {
        if (shares == 0) revert ErrorsLib.ZeroShares();
        UserInvestment storage userInvestment = userInvestments[msg.sender][strategyId];
        uint256 avaibleRequestShares = userInvestment.holdShares - userInvestment.requestUnholdShares;
        if (avaibleRequestShares < shares) revert ErrorsLib.NotEnoughRequestUnShares();

        userInvestment.requestUnholdShares += shares;
        // 创建解锁请求
        unlockRequests[nextUnlockRequestId] = UnlockRequest({
            Id: nextUnlockRequestId,
            user: msg.sender,
            shares: shares,
            strategyId: strategyId,
            requestTime: block.timestamp,
            processed: false
        });

        emit EventsLib.UnlockSharesRequest(msg.sender, strategyId , shares, block.timestamp);
        
        nextUnlockRequestId++;
    }

    /**
     * @dev 查询用户资产基本信息
     */
    function getUserAsset() external view returns (UserAsset memory) {
        return totalAssets[msg.sender];
    }

    /**
     * @dev 用户提取已解锁资产
     * @param amount 提取的资产数量
     */
    function withdraw(uint256 strategyId,uint256 amount) public nonReentrant {
        if (amount == 0) revert ErrorsLib.ZeroAmount();
        UserAsset storage userAsset = totalAssets[msg.sender];
        if (userAsset.strategyId != strategyId) revert ErrorsLib.InvalidStrategyId();
        if (userAsset.unlockedAmount - userAsset.withdrawedAmount < amount) revert ErrorsLib.NotEnoughWithdrawableAssets();

        // 更新用户已提取的资产
        userAsset.withdrawedAmount += amount;

        emit EventsLib.Withdraw(msg.sender, strategyId, address(underlyingAsset), amount);
        
        // 转移资产给用户
        underlyingAsset.safeTransfer(msg.sender, amount);
    }

    /**
     * @dev 管理员提取策略中资产（用于链下交易）
     * @param asset 资产类型
     * @param amount 提取数量
     */
    function adminWithdraw(uint256 strategyId,IERC20 asset, uint256 amount) public nonReentrant onlyRole(MANAGER) {
        if (address(asset) != address(underlyingAsset)) revert ErrorsLib.InvalidAsset();
        if (amount == 0) revert ErrorsLib.ZeroAmount();
        // if (asset.balanceOf(address(this)) < amount) revert ErrorsLib.InsufficientContractBalance();
        // TODO: 计算策略中提取资产比例，
        // 更新用户锁定资产 计算用户未锁定资产占比，和总资产中提取比例相同。

        // emit EventsLib.AdminWithdraw(msg.sender, strategyId,address(asset), amount);
        
        // 转移资产给管理员
        asset.safeTransfer(msg.sender, amount);
    }

    /**
     * @dev 设置交易详情
     * @param tradeDetails_ 交易详情数组
     */
    function setTradeDetails(TradeDetail[] memory tradeDetails_) public onlyRole(MANAGER) {
        // for (uint256 i = 0; i < tradeDetails_.length; i++) {
        //     TradeDetail storage detail = tradeDetails_[i];
        //     if (detail.Id == 0) revert ErrorsLib.InvalidTradeId();
            
        //     // 更新交易详情
        //     tradeDetails[detail.user] = detail;
        // }

        // emit EventsLib.TradeDetailsSet(tradeDetails_);
    }

    /**
     * @dev 处理用户发起的解锁请求
     * @param requestId 解锁请求ID
     * @param asset 资产类型
     * @param amount 资产数量
     */
    function processUnlockRequest(uint256 requestId, IERC20 asset, uint256 amount) public nonReentrant onlyRole(MANAGER) {
        // UnlockRequest storage request = unlockRequests[requestId];
        
        // if (requestId == 0 || requestId >= unlockRequestId) revert ErrorsLib.InvalidRequestId();
        // if (request.processed) revert ErrorsLib.RequestAlreadyProcessed();
        // if (block.timestamp < request.requestTime + UNLOCK_LOCK_PERIOD) revert ErrorsLib.LockPeriodNotExpired();
        
        // // 更新请求状态
        // request.processed = true;
        
        // // 更新用户资产
        // totalAssets[request.user].lockedAmount -= request.amount;
        // totalAssets[request.user].unlockedAmount += amount;

        // emit EventsLib.UnlockProcessed(request.user, requestId, amount);
    }

    /**
     * @dev 查询策略信息
     */
    function getStrategyInfo() external view returns (Strategy memory) {
        return strategy;
    }

    /**
     * @dev 授权升级函数，只有管理员角色可以调用
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @dev Modifier to check if caller has specific role
     */
    // modifier onlyRole(bytes32 role) {
    //     if (!hasRole(role, msg.sender)) revert ErrorsLib.Unauthorized();
    //     _;
    // }
}