// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

import { ISimswapPoolDeployer } from './interfaces/ISimswapPoolDeployer.sol';

import { SimswapPool } from './SimswapPool.sol';

contract SimswapPoolDeployer is ISimswapPoolDeployer {
    struct Parameters {
        address factory;
        address token0;
        address token1;
    }

    /// @inheritdoc ISimswapPoolDeployer
    Parameters public override parameters;

    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the Simswap factory
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    function deploy(
        address factory,
        address token0,
        address token1
    ) internal returns (address pool) {
        parameters = Parameters({factory: factory, token0: token0, token1: token1});
        pool = address(new SimswapPool{salt: keccak256(abi.encode(token0, token1))}());
        delete parameters;
    }
}