// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

/// @title Events emitted by a pool
/// @notice Contains all events emitted by the pool
interface ISimswapPoolEvents {
    /// @notice Emitted when liquidity is minted for a given position
    /// @param sender The address that minted the liquidity
    /// @param amount0 How much token0 was required for the minted liquidity
    /// @param amount1 How much token1 was required for the minted liquidity
    event Mint(
        address indexed sender,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when a position's liquidity is removed
    /// @dev Does not withdraw any fees earned by the liquidity position, which must be withdrawn via #collect
    /// @param sender The address that burned the liquidity
    /// @param amount0 The amount of token0 withdrawn
    /// @param amount1 The amount of token1 withdrawn
    /// @param sender The address that recieved tokens
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed recipient
    );

    /// @notice Emitted by the pool for any swaps between token0 and token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param amount0In Amount of token0 for input
    /// @param amount1In Amount of token1 for input
    /// @param amount0Out Amount of token0 for output
    /// @param amount1Out Amount of token1 for output
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed recipient
    );

    /// @notice Emitted by the pool for update reserves
    /// @param reserve0 Amount of token0
    /// @param reserve1 Amount of token1
    event Sync(
        uint112 reserve0,
        uint112 reserve1
    );
}