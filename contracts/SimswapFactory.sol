// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import './interfaces/ISimswapFactory.sol';

import './modifiers/NoDelegateCall.sol';

import './SimswapPoolDeployer.sol';

contract SimswapFactory is ISimswapFactory, SimswapPoolDeployer, NoDelegateCall {
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) private _pools;
    address[] private _allPools;

    constructor(address _feeToSetter, address _feeTo) {
        feeToSetter = _feeToSetter;
        feeTo = _feeTo;
    }

    function getPool(address tokenA, address tokenB) external override view returns (address) {
        return _pools[tokenA][tokenB];
    }

    function allPools() external override view returns (address[] memory) {
        return _allPools;
    }

    function allPoolsLength() external override view returns (uint256) {
        return _allPools.length;
    }

    function createPool(address tokenA, address tokenB) external override noDelegateCall returns (address pool) {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        require(_pools[token0][token1] == address(0), "Simswap: POOL EXISTS");
        pool = deploy(address(this), token0, token1);
        _pools[token0][token1] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        _pools[token1][token0] = pool;
        _allPools.push(pool);
        emit PoolCreated(token0, token1, pool, _allPools.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'Simswap: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'Simswap: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}