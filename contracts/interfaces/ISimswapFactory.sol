// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import './factory/ISimswapFactoryErrors.sol';

interface ISimswapFactory is ISimswapFactoryErrors {
    event PoolCreated(address indexed token0, address indexed token1, address pool, uint256 poolsAmount);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPool(address tokenA, address tokenB) external view returns (address);
    function allPools() external view returns (address[] memory);
    function allPoolsLength() external view returns (uint256);

    function createPool(address tokenA, address tokenB) external returns (address);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}