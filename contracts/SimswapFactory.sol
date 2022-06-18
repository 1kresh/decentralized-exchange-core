// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import './interfaces/ISimswapFactory.sol';

import './SimswapPoolDeployer.sol';
import './libraries/NoDelegateCall.sol';

contract SimswapFactory is ISimswapFactory, SimswapPoolDeployer, NoDelegateCall {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) private _pools;
    address[] private _allPools;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
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
        require(_pools[token0][token1] == address(0));
        pool = deploy(address(this), token0, token1);
        _pools[token0][token1] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        _pools[token1][token0] = pool;
        emit PoolCreated(token0, token1, pool, _allPools.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'Simswap: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'Simswap: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}