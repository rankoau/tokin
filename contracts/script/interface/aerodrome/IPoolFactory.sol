// SPDX-License-Identifier: BUSL-1.1
// https://basescan.org/address/0x420DD381b31aEf6683db6B902084cB0FFECe40Da#code
// Trimmed to only the function SeedPool.s.sol uses, along with potential errors.
pragma solidity ^0.8.19;

interface IPoolFactory {
    error FeeInvalid();
    error FeeTooHigh();
    error InvalidPool();
    error NotFeeManager();
    error NotPauser();
    error NotVoter();
    error PoolAlreadyExists();
    error SameAddress();
    error ZeroFee();
    error ZeroAddress();

    /// @notice Return address of pool created by this factory
    /// @param tokenA .
    /// @param tokenB .
    /// @param stable True if stable, false if volatile
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);
}
