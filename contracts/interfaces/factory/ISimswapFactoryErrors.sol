// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

/// @title Errors reverted by a factory
/// @notice Contains all errors reverted by the factory
interface ISimswapFactoryErrors {
    error SimswapFactory_FORBIDDEN(address msg_sender, address feeToSetter);
    error SimswapFactory_POOL_EXISTS(address token0, address token1);
    error SimswapFactory_SAME_TOKENS(address token);    
    error SimswapFactory_ZERO_ADDRESS();
}