// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library ConstantsLib {
    /// @dev max fee rate is 50%
    uint256 constant MAX_FEE_RATE = 5000;

    uint256 constant FEE_BASE = 10000;

    uint256 constant MAX_REQUEST_LOCK_TIME = 15 days;

    uint256 constant MIN_REQUEST_LOCK_TIME = 7 days;

}