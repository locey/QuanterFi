// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "./interfaces/IInvestmentTargetOracle.sol";

contract InvestmentTargetOracle is IInvestmentTargetOracle {
    function getInvestmentTarget() external view override returns (uint256) {
        return 100;
    }
}