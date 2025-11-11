// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IDeFiAggregator.sol";
import "./interfaces/IProtocolAdapter.sol";

/**
 * @title DeFiAggregator
 * @dev DeFi聚合器主合约，管理用户资金和各协议适配器
 */
contract DeFiAggregator is IDeFiAggregator, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // 状态变量
    mapping(string => ProtocolInfo) public protocolInfos; // 协议信息映射
    mapping(address => UserInvestment[]) public userInvestments; // 用户投资记录
    mapping(address => mapping(string => uint256)) public userProtocolDeposits; // 用户在特定协议的存款总额
    
    string[] public supportedProtocols; // 支持的协议列表
    mapping(address => uint256) public userTotalDeposits; // 用户总存款
    mapping(address => uint256) public userTotalYield; // 用户总收益
    
    uint256 public constant MIN_DEPOSIT_AMOUNT = 1000; // 最小存款金额（考虑小数点）
    uint256 public constant FEE_PRECISION = 10000; // 手续费精度
    uint256 public performanceFee = 500; // 绩效费 5% (500/10000)
    address public feeCollector; // 手续费收集地址
    
    // 事件（已在接口中定义，这里不需要重复）
    
    /**
     * @dev 构造函数
     * @param _feeCollector 手续费收集地址
     */
    constructor(address _feeCollector) Ownable(msg.sender) {
        require(_feeCollector != address(0), "Invalid fee collector");
        feeCollector = _feeCollector;
    }
    
    /**
     * @dev 存入资金到指定协议
     */
    function deposit(address token, uint256 amount, string memory protocol) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
    {
        require(amount >= MIN_DEPOSIT_AMOUNT, "Amount too small");
        require(protocolInfos[protocol].isActive, "Protocol not active");
        require(protocolInfos[protocol].adapter != address(0), "Protocol adapter not set");
        
        IProtocolAdapter adapter = IProtocolAdapter(protocolInfos[protocol].adapter);
        require(adapter.supportsToken(token), "Token not supported by protocol");
        require(adapter.isActive(), "Protocol adapter not active");
        
        // 从用户转账代币到本合约
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // 授权适配器使用代币
        IERC20(token).forceApprove(protocolInfos[protocol].adapter, amount);
        
        // 通过适配器存入协议
        uint256 actualAmount = adapter.deposit(token, amount);
        require(actualAmount > 0, "Deposit failed");
        
        // 更新用户投资记录
        UserInvestment memory newInvestment = UserInvestment({
            user: msg.sender,
            token: token,
            protocol: protocol,
            amount: actualAmount,
            depositTime: block.timestamp,
            lastUpdateTime: block.timestamp,
            accruedYield: 0,
            isActive: true
        });
        
        userInvestments[msg.sender].push(newInvestment);
        userProtocolDeposits[msg.sender][protocol] += actualAmount;
        userTotalDeposits[msg.sender] += actualAmount;
        protocolInfos[protocol].totalDeposits += actualAmount;
        
        emit Deposit(msg.sender, token, protocol, actualAmount, block.timestamp);
    }
    
    /**
     * @dev 从指定协议提取资金
     */
    function withdraw(address token, uint256 amount, string memory protocol) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
    {
        require(amount > 0, "Amount must be greater than 0");
        require(protocolInfos[protocol].isActive, "Protocol not active");
        require(protocolInfos[protocol].adapter != address(0), "Protocol adapter not set");
        
        // 检查用户是否有足够的可提取余额
        uint256 withdrawableAmount = getWithdrawableAmount(msg.sender, token, protocol);
        require(withdrawableAmount >= amount, "Insufficient withdrawable amount");
        
        IProtocolAdapter adapter = IProtocolAdapter(protocolInfos[protocol].adapter);
        
        // 计算累计收益
        uint256 currentYield = adapter.getAccruedYield(address(this), token);
        uint256 performanceFeeAmount = (currentYield * performanceFee) / FEE_PRECISION;
        uint256 netYield = currentYield - performanceFeeAmount;
        
        // 通过适配器提取资金
        uint256 withdrawnAmount = adapter.withdraw(token, amount);
        require(withdrawnAmount > 0, "Withdraw failed");
        
        // 扣除手续费
        if (performanceFeeAmount > 0) {
            IERC20(token).safeTransfer(feeCollector, performanceFeeAmount);
        }
        
        // 返还用户资金
        IERC20(token).safeTransfer(msg.sender, withdrawnAmount - performanceFeeAmount);
        
        // 更新用户记录
        _updateUserInvestment(msg.sender, token, protocol, withdrawnAmount, netYield);
        
        userProtocolDeposits[msg.sender][protocol] -= withdrawnAmount;
        userTotalDeposits[msg.sender] -= withdrawnAmount;
        userTotalYield[msg.sender] += netYield;
        protocolInfos[protocol].totalDeposits -= withdrawnAmount;
        
        emit Withdraw(msg.sender, token, protocol, withdrawnAmount, netYield, block.timestamp);
    }
    
    /**
     * @dev 查询用户余额
     */
    function getUserBalance(address user, address token, string memory protocol) 
        external 
        view 
        override 
        returns (uint256) 
    {
        uint256 totalBalance = 0;
        UserInvestment[] memory investments = userInvestments[user];
        
        for (uint256 i = 0; i < investments.length; i++) {
            if (investments[i].isActive && 
                investments[i].token == token && 
                keccak256(bytes(investments[i].protocol)) == keccak256(bytes(protocol))) {
                totalBalance += investments[i].amount;
            }
        }
        
        return totalBalance;
    }
    
    /**
     * @dev 查询当前APY
     */
    function getCurrentAPY(string memory protocol) external view override returns (uint256) {
        require(protocolInfos[protocol].adapter != address(0), "Protocol adapter not set");
        
        IProtocolAdapter adapter = IProtocolAdapter(protocolInfos[protocol].adapter);
        return adapter.getAPY();
    }
    
    /**
     * @dev 查询可提取金额
     */
    function getWithdrawableAmount(address user, address token, string memory protocol) 
        public 
        view 
        override 
        returns (uint256) 
    {
        require(protocolInfos[protocol].adapter != address(0), "Protocol adapter not set");
        
        IProtocolAdapter adapter = IProtocolAdapter(protocolInfos[protocol].adapter);
        uint256 lockPeriod = adapter.getLockPeriod();
        
        uint256 withdrawableAmount = 0;
        UserInvestment[] memory investments = userInvestments[user];
        
        for (uint256 i = 0; i < investments.length; i++) {
            if (investments[i].isActive && 
                investments[i].token == token && 
                keccak256(bytes(investments[i].protocol)) == keccak256(bytes(protocol))) {
                
                // 检查锁定期
                if (block.timestamp >= investments[i].depositTime + lockPeriod) {
                    withdrawableAmount += investments[i].amount;
                }
            }
        }
        
        return withdrawableAmount;
    }
    
    /**
     * @dev 获取用户所有投资记录
     */
    function getUserInvestments(address user) 
        external 
        view 
        override 
        returns (UserInvestment[] memory) 
    {
        return userInvestments[user];
    }
    
    /**
     * @dev 获取用户累计收益
     */
    function getUserYield(address user, address token, string memory protocol) 
        external 
        view 
        override 
        returns (uint256) 
    {
        uint256 totalYield = 0;
        UserInvestment[] memory investments = userInvestments[user];
        
        for (uint256 i = 0; i < investments.length; i++) {
            if (investments[i].token == token && 
                keccak256(bytes(investments[i].protocol)) == keccak256(bytes(protocol))) {
                totalYield += investments[i].accruedYield;
            }
        }
        
        return totalYield;
    }
    
    /**
     * @dev 获取支持的协议列表
     */
    function getSupportedProtocols() external view override returns (string[] memory) {
        return supportedProtocols;
    }
    
    /**
     * @dev 获取协议信息
     */
    function getProtocolInfo(string memory protocol) 
        external 
        view 
        override 
        returns (ProtocolInfo memory) 
    {
        return protocolInfos[protocol];
    }
    
    /**
     * @dev 获取用户总资产价值（简化版本）
     */
    function getUserTotalAssets(address user) external view override returns (uint256) {
        return userTotalDeposits[user] + userTotalYield[user];
    }
    
    /**
     * @dev 更新协议APY
     */
    function updateProtocolAPY(string memory protocol, uint256 newAPY) external override onlyOwner {
        require(protocolInfos[protocol].adapter != address(0), "Protocol not found");
        
        uint256 oldAPY = protocolInfos[protocol].lastAPY;
        protocolInfos[protocol].lastAPY = newAPY;
        protocolInfos[protocol].updateTime = block.timestamp;
        
        emit ProtocolAPYUpdated(protocol, oldAPY, newAPY, block.timestamp);
    }
    
    /**
     * @dev 添加新协议
     */
    function addProtocol(string memory protocol, address adapter, uint256 riskLevel) 
        external 
        override 
        onlyOwner 
    {
        require(adapter != address(0), "Invalid adapter address");
        require(riskLevel > 0 && riskLevel <= 5, "Invalid risk level");
        require(protocolInfos[protocol].adapter == address(0), "Protocol already exists");
        
        protocolInfos[protocol] = ProtocolInfo({
            adapter: adapter,
            isActive: true,
            riskLevel: riskLevel,
            totalDeposits: 0,
            lastAPY: 0,
            updateTime: block.timestamp
        });
        
        supportedProtocols.push(protocol);
        
        emit ProtocolAdded(protocol, adapter, riskLevel, block.timestamp);
    }
    
    /**
     * @dev 设置协议激活状态
     */
    function setProtocolActive(string memory protocol, bool isActive) external override onlyOwner {
        require(protocolInfos[protocol].adapter != address(0), "Protocol not found");
        
        protocolInfos[protocol].isActive = isActive;
    }
    
    /**
     * @dev 设置紧急暂停
     */
    function setEmergencyPause(bool paused) external override onlyOwner {
        if (paused) {
            _pause();
        } else {
            _unpause();
        }
    }
    
    /**
     * @dev 更新用户投资记录（内部函数）
     */
    function _updateUserInvestment(
        address user,
        address token,
        string memory protocol,
        uint256 withdrawnAmount,
        uint256 yield
    ) internal {
        UserInvestment[] storage investments = userInvestments[user];
        
        for (uint256 i = 0; i < investments.length; i++) {
            if (investments[i].isActive && 
                investments[i].token == token && 
                keccak256(bytes(investments[i].protocol)) == keccak256(bytes(protocol))) {
                
                if (investments[i].amount <= withdrawnAmount) {
                    investments[i].isActive = false;
                    investments[i].accruedYield += yield;
                    withdrawnAmount -= investments[i].amount;
                    investments[i].amount = 0;
                } else {
                    investments[i].amount -= withdrawnAmount;
                    investments[i].accruedYield += yield;
                    break;
                }
            }
        }
    }
    
    /**
     * @dev 设置绩效费
     */
    function setPerformanceFee(uint256 newFee) external onlyOwner {
        require(newFee <= 2000, "Fee too high"); // 最大20%
        performanceFee = newFee;
    }
    
    /**
     * @dev 设置手续费收集地址
     */
    function setFeeCollector(address newFeeCollector) external onlyOwner {
        require(newFeeCollector != address(0), "Invalid address");
        feeCollector = newFeeCollector;
    }
}