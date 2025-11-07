// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Counter is Initializable, OwnableUpgradeable {
    uint256 private _count;
    
    // 事件定义
    event CountIncremented(uint256 newCount, address indexed caller);
    event CountDecremented(uint256 newCount, address indexed caller);
    event CountReset(address indexed caller);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        _count = 0;
    }
    
    function increment() public returns (uint256) {
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
}