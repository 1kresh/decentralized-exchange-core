// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

/// @title Errors reverted by a pool
/// @notice Contains all errors reverted by the pool
interface ISimswapPoolErrors {
    error SimswapPool_INSUFFICIENT_INPUT_AMOUNT(
        uint256 amount0Out,
        uint256 amount1Out,
        uint256 amount0In,
        uint256 amount1In,
        uint256 balance0,
        uint256 balance1
    );
    error SimswapPool_INSUFFICIENT_LIQUIDITY(
        uint256 amount0Out,
        uint256 amount1Out,
        uint112 reserve0,
        uint112 reserve1
    );
    error SimswapPool_INSUFFICIENT_LIQUIDITY_BURNED(
        uint256 amount0,
        uint256 amount1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply
    );
    error SimswapPool_INSUFFICIENT_LIQUIDITY_MINTED(
        uint256 amount0,
        uint256 amount1,
        uint112 reserve0,
        uint112 reserve1,
        uint256 totalSupply
    );
    error SimswapPool_INSUFFICIENT_OUTPUT_AMOUNT(
        uint256 amount0Out,
        uint256 amount1Out
    );
    error SimswapPool_INVALID_TO(
        address token0,
        address token1,
        address recipient
    );
    error SimswapPool_K(
        uint256 balance0Adjusted,
        uint256 balance1Adjusted,
        uint112 reserve0,
        uint112 reserve1
    );
    error SimswapPool_OVERFLOW(uint256 balance0, uint256 balance1);
    error SimswapPool_TRANFER_FAILED(
        address token,
        address recipient,
        uint256 value
    );
}
