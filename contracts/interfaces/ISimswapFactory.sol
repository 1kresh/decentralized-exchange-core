// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface ISimswapFactory {
    event PoolCreated(address indexed token0, address indexed token1, address pool, uint256);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPool(address tokenA, address tokenB) external view returns (address pool);
    function allPools(uint256) external view returns (address pool);
    function allPoolsLength() external view returns (uint256);

    function createPool(address tokenA, address tokenB) external returns (address pool);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}