// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

import { ReentrancyGuard } from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './interfaces/ISimswapPool.sol';
import { ISimswapCallee } from './interfaces/ISimswapCallee.sol';
import { ISimswapFactory } from './interfaces/ISimswapFactory.sol';
import { ISimswapPoolDeployer } from './interfaces/ISimswapPoolDeployer.sol';

import { FixedPoint112 } from './libraries/FixedPoint112.sol';
import { Math } from './libraries/Math.sol';

import { NoDelegateCall } from './modifiers/NoDelegateCall.sol';

import { SimswapERC20 } from './SimswapERC20.sol';

contract SimswapPool is
    ISimswapPool,
    SimswapERC20,
    NoDelegateCall,
    ReentrancyGuard
{
    using FixedPoint112 for uint224;

    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    bytes4 public constant SELECTOR =
        bytes4(keccak256(bytes('transfer(address,uint256)')));

    /// @inheritdoc ISimswapPoolImmutables
    address public immutable override factory;
    /// @inheritdoc ISimswapPoolImmutables
    address public immutable override token0;
    /// @inheritdoc ISimswapPoolImmutables
    address public immutable override token1;

    struct Slot0 {
        uint112 reserve0;
        uint112 reserve1;
        uint32 blockTimestampLast;
    }

    /// @inheritdoc ISimswapPoolState
    Slot0 public override slot0;

    /// @inheritdoc ISimswapPoolState
    uint256 public override price0CumulativeLast;
    /// @inheritdoc ISimswapPoolState
    uint256 public override price1CumulativeLast;

    /// @inheritdoc ISimswapPoolState
    uint256 public override kLast;

    constructor() {
        (factory, token0, token1) = ISimswapPoolDeployer(msg.sender)
            .parameters();
    }

    /// @dev Get the pool's balance of token0
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check
    function balance0() private view returns (uint256) {
        (bool success, bytes memory data) = token0.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        require(success == true && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev Get the pool's balance of token1
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check
    function balance1() private view returns (uint256) {
        (bool success, bytes memory data) = token1.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        require(success == true && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev Returns the block timestamp truncated to 32 bits, i.e. mod 2**32. This method is overridden in tests.
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    function _safeTransfer(
        address token,
        address recipient,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR, recipient, value)
        );
        if (
            success == false ||
            (data.length != 0 && abi.decode(data, (bool)) == false)
        ) revert SimswapPool_TRANFER_FAILED(token, recipient, value);
    }

    /// @dev Update reserves and, on the first call per block, price accumulators
    function _update(
        uint256 _balance0,
        uint256 _balance1,
        uint112 _reserve0,
        uint112 _reserve1
    ) private {
        uint256 max112up;
        unchecked {
            max112up = type(uint112).max + 1;
        }
        if (_balance0 >= max112up || _balance1 >= max112up)
            revert SimswapPool_OVERFLOW(_balance0, _balance1);

        uint32 blockTimestamp = _blockTimestamp();
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - slot0.blockTimestampLast; // overflow is desired
        }
        if (timeElapsed != 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            unchecked {
                price0CumulativeLast +=
                    uint256(FixedPoint112.encode(_reserve1).uqdiv(_reserve0)) *
                    timeElapsed;
                price1CumulativeLast +=
                    uint256(FixedPoint112.encode(_reserve0).uqdiv(_reserve1)) *
                    timeElapsed;
            }
        }
        _reserve0 = uint112(_balance0);
        _reserve1 = uint112(_balance1);

        slot0.reserve0 = _reserve0;
        slot0.reserve1 = _reserve1;
        slot0.blockTimestampLast = blockTimestamp;

        emit Sync(_reserve0, _reserve1);
    }

    /// @dev If fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1)
        private
        returns (bool feeOn)
    {
        address feeTo = ISimswapFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // gas savings
        if (feeOn == true) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity;
                    unchecked {
                        liquidity = numerator / denominator;
                    }

                    if (liquidity != 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /// @inheritdoc ISimswapPoolActions
    /// @dev This low-level function should be called from a contract which performs important safety checks
    function mint(address recipient)
        public
        override
        nonReentrant
        returns (uint256 liquidity)
    {
        uint112 _reserve0 = slot0.reserve0;
        uint112 _reserve1 = slot0.reserve1;
        uint256 _balance0 = balance0();
        uint256 _balance1 = balance1();
        uint256 amount0 = _balance0 - _reserve0;
        uint256 amount1 = _balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            uint256 mul0 = amount0 * _totalSupply;
            uint256 mul1 = amount1 * _totalSupply;
            unchecked {
                liquidity = Math.min(mul0 / _reserve0, mul1 / _reserve1);
            }
        }
        if (liquidity == 0)
            revert SimswapPool_INSUFFICIENT_LIQUIDITY_MINTED(
                amount0,
                amount1,
                _reserve0,
                _reserve1,
                _totalSupply
            );

        _mint(recipient, liquidity);

        _update(_balance0, _balance1, _reserve0, _reserve1);

        if (feeOn == true) kLast = uint256(slot0.reserve0) * slot0.reserve1; // reserve0 and reserve1 are up-to-date

        emit Mint(msg.sender, amount0, amount1);
    }

    /// @inheritdoc ISimswapPoolActions
    /// @dev This low-level function should be called from a contract which performs important safety checks
    function burn(address recipient)
        public
        override
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        uint112 _reserve0 = slot0.reserve0;
        uint112 _reserve1 = slot0.reserve1;
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint256 _balance0 = balance0();
        uint256 _balance1 = balance1();
        uint256 liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee

        uint256 mul_ = liquidity * _balance0;
        unchecked {
            amount0 = mul_ / _totalSupply; // using balances ensures pro-rata distribution
        }
        mul_ = liquidity * _balance1;
        unchecked {
            amount1 = mul_ / _totalSupply; // using balances ensures pro-rata distribution
        }

        if (amount0 == 0 || amount1 == 0)
            revert SimswapPool_INSUFFICIENT_LIQUIDITY_BURNED(
                amount0,
                amount1,
                _balance0,
                _balance1,
                _totalSupply
            );

        _burn(address(this), liquidity);
        _safeTransfer(_token0, recipient, amount0);
        _safeTransfer(_token1, recipient, amount1);
        _balance0 = balance0();
        _balance1 = balance1();

        _update(_balance0, _balance1, _reserve0, _reserve1);

        if (feeOn == true) kLast = uint256(slot0.reserve0) * slot0.reserve1; // reserve0 and reserve1 are up-to-date

        emit Burn(msg.sender, amount0, amount1, recipient);
    }

    /// @inheritdoc ISimswapPoolActions
    /// @dev This low-level function should be called from a contract which performs important safety checks
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address recipient,
        bytes calldata data
    ) public override nonReentrant noDelegateCall {
        if (amount0Out == 0 && amount1Out == 0)
            revert SimswapPool_INSUFFICIENT_OUTPUT_AMOUNT(
                amount0Out,
                amount1Out
            );

        uint112 _reserve0 = slot0.reserve0;
        uint112 _reserve1 = slot0.reserve1;

        if (amount0Out >= _reserve0 || amount1Out >= _reserve1)
            revert SimswapPool_INSUFFICIENT_LIQUIDITY(
                amount0Out,
                amount1Out,
                _reserve0,
                _reserve1
            );

        uint256 _balance0;
        uint256 _balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;

            if (recipient == _token0 || recipient == _token1)
                revert SimswapPool_INVALID_TO(_token0, _token1, recipient);

            if (amount0Out != 0) _safeTransfer(_token0, recipient, amount0Out); // optimistically transfer tokens
            if (amount1Out != 0) _safeTransfer(_token1, recipient, amount1Out); // optimistically transfer tokens
            if (data.length != 0)
                ISimswapCallee(recipient).simswapCall(
                    msg.sender,
                    amount0Out,
                    amount1Out,
                    data
                );

            _balance0 = balance0();
            _balance1 = balance1();
        }

        uint256 amount0In;
        uint256 amount1In;
        unchecked {
            uint256 temp = _reserve0 - amount0Out;
            amount0In = _balance0 > temp ? _balance0 - temp : 0;
            temp = _reserve1 - amount1Out;
            amount1In = _balance1 > temp ? _balance1 - temp : 0;
        }

        if (amount0In == 0 && amount1In == 0)
            revert SimswapPool_INSUFFICIENT_INPUT_AMOUNT(
                amount0Out,
                amount1Out,
                amount0In,
                amount1In,
                _balance0,
                _balance1
            );

        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint256 balance0Adjusted = _balance0 * 1000 - amount0In * 3;
            uint256 balance1Adjusted = _balance1 * 1000 - amount1In * 3;

            if (
                balance0Adjusted * balance1Adjusted <
                uint256(_reserve0) * _reserve1 * 1000000
            )
                revert SimswapPool_K(
                    balance0Adjusted,
                    balance1Adjusted,
                    _reserve0,
                    _reserve1
                );
        }

        _update(_balance0, _balance1, _reserve0, _reserve1);

        emit Swap(
            msg.sender,
            amount0In,
            amount1In,
            amount0Out,
            amount1Out,
            recipient
        );
    }

    /// @dev Force balances to match reserves
    function skim(address recipient) public override nonReentrant {
        _safeTransfer(token0, recipient, balance0() - slot0.reserve0);
        _safeTransfer(token1, recipient, balance1() - slot0.reserve1);
    }

    /// @dev Force reserves to match balances
    function sync() public override nonReentrant {
        _update(balance0(), balance1(), slot0.reserve0, slot0.reserve1);
    }
}
