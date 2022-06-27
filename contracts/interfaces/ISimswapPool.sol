// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

import { ISimswapPoolActions } from './pool/ISimswapPoolActions.sol';
import { ISimswapPoolImmutables } from './pool/ISimswapPoolImmutables.sol';
import { ISimswapPoolEvents } from './pool/ISimswapPoolEvents.sol';
import { ISimswapPoolState } from './pool/ISimswapPoolState.sol';
import { ISimswapPoolErrors } from './pool/ISimswapPoolErrors.sol';

/// @title The interface for a Simswap Pool
/// @notice A Simswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface ISimswapPool is
    ISimswapPoolImmutables,
    ISimswapPoolState,
    ISimswapPoolActions,
    ISimswapPoolEvents,
    ISimswapPoolErrors
{

}