// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title YieldCalculator
 * @dev 收益计算库，提供精确的复利计算功能
 */
library YieldCalculator {
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant APY_PRECISION = 10000; // APY精度，支持小数点后2位
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    
    /**
     * @dev 计算单利收益
     * @param principal 本金
     * @param apy 年化收益率（乘以APY_PRECISION）
     * @param timeElapsed 时间间隔（秒）
     * @return 收益金额
     */
    function calculateSimpleInterest(
        uint256 principal,
        uint256 apy,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        if (principal == 0 || apy == 0 || timeElapsed == 0) {
            return 0;
        }
        
        // 计算年化收益
        uint256 yearlyInterest = (principal * apy) / APY_PRECISION;
        
        // 按时间比例计算实际收益
        uint256 interest = (yearlyInterest * timeElapsed) / SECONDS_PER_YEAR;
        
        return interest;
    }
    
    /**
     * @dev 计算复利收益（按秒复利）
     * @param principal 本金
     * @param apy 年化收益率（乘以APY_PRECISION）
     * @param timeElapsed 时间间隔（秒）
     * @return 最终金额（本金+收益）
     */
    function calculateCompoundInterest(
        uint256 principal,
        uint256 apy,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        if (principal == 0 || apy == 0 || timeElapsed == 0) {
            return principal;
        }
        
        // 将APY转换为每秒的利率
        uint256 ratePerSecond = (apy * PRECISION) / (SECONDS_PER_YEAR * APY_PRECISION);
        
        // 使用复利公式：A = P * (1 + r)^t
        // 为了避免大数计算，使用近似算法
        uint256 compoundFactor = _calculateCompoundFactor(ratePerSecond, timeElapsed);
        
        return (principal * compoundFactor) / PRECISION;
    }
    
    /**
     * @dev 计算复利因子 (1 + r)^t
     * @param ratePerSecond 每秒利率（乘以PRECISION）
     * @param timeElapsed 时间间隔（秒）
     * @return 复利因子（乘以PRECISION）
     */
    function _calculateCompoundFactor(
        uint256 ratePerSecond,
        uint256 timeElapsed
    ) private pure returns (uint256) {
        // 对于长时间段，使用近似计算避免溢出
        if (timeElapsed > SECONDS_PER_YEAR) {
            // 分段计算：先计算整年部分，再计算剩余时间
            uint256 fullYears = timeElapsed / SECONDS_PER_YEAR;
            uint256 remainingTime = timeElapsed % SECONDS_PER_YEAR;
            
            // 计算整年部分的复利因子
            uint256 yearlyFactor = _calculateYearlyCompoundFactor(ratePerSecond);
            uint256 fullYearsFactor = _power(yearlyFactor, fullYears);
            
            // 计算剩余时间的复利因子
            uint256 remainingFactor = PRECISION + (ratePerSecond * remainingTime) / PRECISION;
            
            return (fullYearsFactor * remainingFactor) / PRECISION;
        } else {
            // 短时间使用线性近似
            return PRECISION + (ratePerSecond * timeElapsed) / PRECISION;
        }
    }
    
    /**
     * @dev 计算年复利因子
     * @param ratePerSecond 每秒利率（乘以PRECISION）
     * @return 年复利因子（乘以PRECISION）
     */
    function _calculateYearlyCompoundFactor(uint256 ratePerSecond) private pure returns (uint256) {
        // 使用泰勒展开近似计算 (1 + r)^n
        uint256 yearlyRate = ratePerSecond * SECONDS_PER_YEAR;
        
        // e^(yearlyRate) 的泰勒展开近似
        uint256 factor = PRECISION + yearlyRate;
        
        // 添加二阶项
        if (yearlyRate < PRECISION) {
            uint256 secondOrder = (yearlyRate * yearlyRate) / (2 * PRECISION);
            factor += secondOrder;
        }
        
        return factor;
    }
    
    /**
     * @dev 幂函数计算 x^n
     * @param base 基数（乘以PRECISION）
     * @param exponent 指数
     * @return 结果（乘以PRECISION）
     */
    function _power(uint256 base, uint256 exponent) private pure returns (uint256) {
        if (exponent == 0) return PRECISION;
        if (exponent == 1) return base;
        
        uint256 result = PRECISION;
        uint256 currentBase = base;
        uint256 currentExponent = exponent;
        
        while (currentExponent > 0) {
            if (currentExponent % 2 == 1) {
                result = (result * currentBase) / PRECISION;
            }
            currentBase = (currentBase * currentBase) / PRECISION;
            currentExponent = currentExponent / 2;
        }
        
        return result;
    }
    
    /**
     * @dev 计算APY转换
     * @param dailyRate 日利率（乘以PRECISION）
     * @return 年化收益率（乘以APY_PRECISION）
     */
    function dailyToAPY(uint256 dailyRate) internal pure returns (uint256) {
        // APY = (1 + dailyRate)^365 - 1
        uint256 compoundFactor = _power(PRECISION + dailyRate, 365);
        uint256 apy = ((compoundFactor - PRECISION) * APY_PRECISION) / PRECISION;
        
        return apy;
    }
    
    /**
     * @dev 计算当前收益（考虑时间加权）
     * @param principal 本金
     * @param apy 年化收益率（乘以APY_PRECISION）
     * @param lastUpdateTime 最后更新时间
     * @return 当前应得收益
     */
    function calculateCurrentYield(
        uint256 principal,
        uint256 apy,
        uint256 lastUpdateTime
    ) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        return calculateSimpleInterest(principal, apy, timeElapsed);
    }
    
    /**
     * @dev 计算平均年化收益率
     * @param totalYield 总收益
     * @param principal 本金
     * @param timeElapsed 时间间隔（秒）
     * @return 平均年化收益率（乘以APY_PRECISION）
     */
    function calculateAverageAPY(
        uint256 totalYield,
        uint256 principal,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        if (principal == 0 || timeElapsed == 0) {
            return 0;
        }
        
        // 年化收益率 = (总收益 / 本金) * (年数 / 时间间隔)
        uint256 yieldRatio = (totalYield * PRECISION) / principal;
        uint256 timeRatio = (SECONDS_PER_YEAR * PRECISION) / timeElapsed;
        
        uint256 apy = (yieldRatio * timeRatio * APY_PRECISION) / (PRECISION * PRECISION);
        
        return apy;
    }
    
    /**
     * @dev 计算滑点影响
     * @param expectedAmount 预期金额
     * @param actualAmount 实际金额
     * @return 滑点百分比（乘以APY_PRECISION）
     */
    function calculateSlippage(
        uint256 expectedAmount,
        uint256 actualAmount
    ) internal pure returns (uint256) {
        if (expectedAmount == 0) return 0;
        
        if (actualAmount >= expectedAmount) {
            return 0; // 正滑点不计算
        }
        
        uint256 slippage = ((expectedAmount - actualAmount) * APY_PRECISION) / expectedAmount;
        return slippage;
    }
    
    /**
     * @dev 计算复利和单利的差异
     * @param principal 本金
     * @param apy 年化收益率（乘以APY_PRECISION）
     * @param timeElapsed 时间间隔（秒）
     * @return 复利收益与单利收益的差值
     */
    function compoundVsSimpleDifference(
        uint256 principal,
        uint256 apy,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        uint256 compoundAmount = calculateCompoundInterest(principal, apy, timeElapsed);
        uint256 simpleAmount = principal + calculateSimpleInterest(principal, apy, timeElapsed);
        
        if (compoundAmount > simpleAmount) {
            return compoundAmount - simpleAmount;
        } else {
            return 0;
        }
    }
}