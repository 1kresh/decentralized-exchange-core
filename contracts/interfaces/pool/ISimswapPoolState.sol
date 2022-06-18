// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

/// @title Pool state that can change
/// @notice These methods compose the pool's state, and can change with any frequency including multiple times
/// per transaction
interface ISimswapPoolState {
    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return reserve0 Last updated amount of token0.
    /// reserve1 Last updated amount of token1.
    /// blockTimestampLast Last block of the most recent liquidity event.
    function slot0()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    /// @notice Sum of relative prives of token0.
    /// @dev This value can overflow the uint256.
    function price0CumulativeLast() external view returns (uint256);

    /// @notice Sum of relative prives of token1.
    /// @dev This value can overflow the uint256.
    function price1CumulativeLast() external view returns (uint256);

    /// @notice Last updated k, where k = reserve0 * reserve1.
    /// @dev reserve0 * reserve1, as of immediately after the most recent liquidity event.
    function kLast() external view returns (uint256);
}