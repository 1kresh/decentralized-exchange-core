// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

/// @title Pool state that never changes
/// @notice These parameters are fixed for a pool forever, i.e., the methods will always return the same values
interface ISimswapPoolImmutables {
    /// @notice The contract that deployed the pool, which must adhere to the ISimswapFactory interface
    /// @return The contract address
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);
}
