// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IInvestmentTargetOracle {
    function getInvestmentTarget() external view returns (uint256);
}