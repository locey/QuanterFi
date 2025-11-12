// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library StrategyLib { 

    bytes32 public constant INVESTMENT_TYPEHASH = 
        keccak256("Investment(string platform,string symbol)");

    function hashInvestment(
        string memory _platform,
        string memory _symbol
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(INVESTMENT_TYPEHASH, _platform, _symbol));
    }
}