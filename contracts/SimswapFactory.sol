// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

import { ISimswapFactory } from './interfaces/ISimswapFactory.sol';

import { NoDelegateCall } from './modifiers/NoDelegateCall.sol';

import { SimswapPoolDeployer } from './SimswapPoolDeployer.sol';

contract SimswapFactory is ISimswapFactory, SimswapPoolDeployer, NoDelegateCall {
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) private _pools;
    address[] private _allPools;

    constructor(address _feeToSetter, address _feeTo) {
        feeToSetter = _feeToSetter;
        feeTo = _feeTo;
    }

    function getPool(address tokenA, address tokenB) public override view returns (address) {
        return _pools[tokenA][tokenB];
    }

    function allPools() public override view returns (address[] memory) {
        return _allPools;
    }

    function allPoolsLength() public override view returns (uint256) {
        return _allPools.length;
    }

    function createPool(address tokenA, address tokenB) public override noDelegateCall returns (address pool) {
        if (tokenA == tokenB)
            revert SimswapFactory_SAME_TOKENS(tokenA);

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        if (token0 == address(0))
            revert SimswapFactory_ZERO_ADDRESS();
        if (_pools[token0][token1] != address(0))
            revert SimswapFactory_POOL_EXISTS(token0, token1);

        pool = deploy(address(this), token0, token1);
        _pools[token0][token1] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        _pools[token1][token0] = pool;
        _allPools.push(pool);

        emit PoolCreated(token0, token1, pool, _allPools.length);
    }

    function setFeeTo(address _feeTo) public override {
        address msg_sender = msg.sender;
        if (msg_sender != feeToSetter)
            revert SimswapFactory_FORBIDDEN(msg_sender, feeToSetter);

        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) public override {
        address msg_sender = msg.sender;
        if (msg_sender != feeToSetter)
            revert SimswapFactory_FORBIDDEN(msg_sender, feeToSetter);

        feeToSetter = _feeToSetter;
    }
}