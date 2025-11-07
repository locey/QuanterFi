// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CounterV2 is Initializable, OwnableUpgradeable {
    uint256 private _count;
    uint256 private _maxCount; // 新增功能：最大计数限制
    
    // 事件定义
    event CountIncremented(uint256 newCount, address indexed caller);
    event CountDecremented(uint256 newCount, address indexed caller);
    event CountReset(address indexed caller);
    event MaxCountUpdated(uint256 newMaxCount, address indexed caller); // 新增事件
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        _count = 0;
        _maxCount = 100; // 默认最大计数为100
    }
    
    // 新增函数：设置最大计数
    function setMaxCount(uint256 maxCount) public onlyOwner {
        _maxCount = maxCount;
        emit MaxCountUpdated(maxCount, msg.sender);
    }
    
    function increment() public returns (uint256) {
        require(_count < _maxCount, "Counter: maximum count reached");
        _count++;
        emit CountIncremented(_count, msg.sender);
        return _count;
    }
    
    function decrement() public onlyOwner returns (uint256) {
        require(_count > 0, "Counter: cannot decrement below zero");
        _count--;
        emit CountDecremented(_count, msg.sender);
        return _count;
    }
    
    function reset() public onlyOwner {
        _count = 0;
        emit CountReset(msg.sender);
    }
    
    function count() public view returns (uint256) {
        return _count;
    }
    
    // 新增函数：获取最大计数
    function getMaxCount() public view returns (uint256) {
        return _maxCount;
    }
}