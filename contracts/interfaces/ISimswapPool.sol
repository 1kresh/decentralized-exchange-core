// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import './pool/ISimswapPoolImmutables.sol';
import './pool/ISimswapPoolState.sol';
import './pool/ISimswapPoolActions.sol';
import './pool/ISimswapPoolEvents.sol';

/// @title The interface for a Simswap Pool
/// @notice A Simswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface ISimswapPool is
    ISimswapPoolImmutables,
    ISimswapPoolState,
    ISimswapPoolActions,
    ISimswapPoolEvents,
    ISimswapERC20
{

}