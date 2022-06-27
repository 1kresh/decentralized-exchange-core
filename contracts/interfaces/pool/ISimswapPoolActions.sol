// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

/// @title Permissionless pool actions
/// @notice Contains pool methods that can be called by anyone
interface ISimswapPoolActions {
    /// @notice Adds liquidity for the given recipient
    /// @dev Mint liquidity
    /// @param recipient The address for which the liquidity will be created
    /// @return liquidity The amount of liquidity tokens was minted
    function mint(
        address recipient
    ) external returns (uint256 liquidity);

    /// @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
    /// @dev Burn liquidity
    /// @param recipient The address that recieved tokens
    /// @return amount0 The amount of token0 sent to the recipient
    /// @return amount1 The amount of token1 sent to the recipient
    function burn(
        address recipient
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swap token0 for token1, or token1 for token0
    /// @dev Swap tokens
    /// @param amount0Out The amount of token0 output
    /// @param amount1Out The amount of token1 output
    /// @param recipient The address to receive the output of the swap
    /// @param data Any data to be passed through to the callback
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address recipient,
        bytes calldata data
    ) external;

    function skim(
        address recipient
    ) external;

    function sync(
    ) external;

}