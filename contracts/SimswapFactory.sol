// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import './interfaces/ISimswapFactory.sol';

import './SimswapPoolDeployer.sol';
import './libraries/NoDelegateCall.sol';

contract SimswapFactory is ISimswapFactory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPool;
    address[] public allPools;

    event PoolCreated(address indexed token0, address indexed token1, address pool, uint256);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPoolsLength() external view returns (uint256) {
        return allPools.length;
    }

    function createPool(address tokenA, address tokenB) external override noDelegateCall returns (address pool) {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        require(getPool[token0][token1] == address(0));
        pool = deploy(address(this), token0, token1);
        getPool[token0][token1] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0] = pool;
        emit PoolCreated(token0, token1, pool);
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