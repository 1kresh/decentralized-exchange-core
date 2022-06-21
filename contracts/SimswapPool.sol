// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import './SimswapERC20.sol';
import './interfaces/ISimswapPool.sol';
import './interfaces/ISimswapPoolDeployer.sol';
import './libraries/Math.sol';
import './libraries/LowGasSafeMath.sol';
import './libraries/FixedPoint112.sol';
import './interfaces/IERC20Minimal.sol';
import './interfaces/ISimswapFactory.sol';
import './interfaces/ISimswapCallee.sol';
import './libraries/NoDelegateCall.sol';
import './libraries/ReentrancyGuard.sol';

contract SimswapPool is ISimswapPool, SimswapERC20, NoDelegateCall, ReentrancyGuard {
    using LowGasSafeMath for uint256;
    using FixedPoint112 for uint224;

    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

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

    /// @dev Get the pool's balance of token0
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check
    function balance0() private view returns (uint256) {
        (bool success, bytes memory data) =
            token0.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev Get the pool's balance of token1
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check
    function balance1() private view returns (uint256) {
        (bool success, bytes memory data) =
            token1.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev Returns the block timestamp truncated to 32 bits, i.e. mod 2**32. This method is overridden in tests.
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }


    constructor() {
        (factory, token0, token1) = ISimswapPoolDeployer(msg.sender).parameters();
    }

    function _safeTransfer(address token, address recipient, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, recipient, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Simswap: TRANSFER_FAILED');
    }

    /// @dev Update reserves and, on the first call per block, price accumulators
    function _update(uint256 _balance0, uint256 _balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(_balance0 <= type(uint112).max && _balance1 <= type(uint112).max, 'Simswap: OVERFLOW');
        uint32 blockTimestamp = _blockTimestamp();
        uint32 timeElapsed = blockTimestamp - slot0.blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += LowGasSafeMath.mul(FixedPoint112.encode(_reserve1).uqdiv(_reserve0), timeElapsed);
            price1CumulativeLast += LowGasSafeMath.mul(FixedPoint112.encode(_reserve0).uqdiv(_reserve1), timeElapsed);
        }
        _reserve0 = uint112(_balance0);
        _reserve1 = uint112(_balance1);

        slot0.reserve0 = _reserve0;
        slot0.reserve1 = _reserve1;
        slot0.blockTimestampLast = blockTimestamp;

        emit Sync(_reserve0, _reserve1);
    }

    /// @dev If fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = ISimswapFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /// @inheritdoc ISimswapPoolActions
    /// @dev This low-level function should be called from a contract which performs important safety checks
    function mint(address recipient) external override nonReentrant returns (uint256 liquidity) {
        Slot0 memory _slot0 = slot0;
        uint112 _reserve0 = _slot0.reserve0;
        uint112 _reserve1 = _slot0.reserve1;

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
            liquidity = Math.min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
        }
        require(liquidity > 0, 'Simswap: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(recipient, liquidity);

        _update(_balance0, _balance1, _reserve0, _reserve1);

        _slot0 = slot0;
        if (feeOn) kLast = uint256(_slot0.reserve0) * _slot0.reserve1; // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    /// @inheritdoc ISimswapPoolActions
    /// @dev This low-level function should be called from a contract which performs important safety checks
    function burn(address recipient) external override nonReentrant returns (uint256 amount0, uint256 amount1) {
        Slot0 memory _slot0 = slot0;
        uint112 _reserve0 = _slot0.reserve0;
        uint112 _reserve1 = _slot0.reserve1;

        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint256 _balance0 = balance0();
        uint256 _balance1 = balance1();
        uint256 liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity * _balance0 / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity * _balance1 / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'Simswap: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, recipient, amount0);
        _safeTransfer(_token1, recipient, amount1);
        _balance0 = balance0();
        _balance1 = balance1();

        _update(_balance0, _balance1, _reserve0, _reserve1);
        _slot0 = slot0;
        if (feeOn) kLast = uint(_slot0.reserve0) * _slot0.reserve1; // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, recipient);
    }

    /// @inheritdoc ISimswapPoolActions
    /// @dev This low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address recipient, bytes calldata data) external override nonReentrant noDelegateCall {
        require(amount0Out > 0 || amount1Out > 0, 'Simswap: INSUFFICIENT_OUTPUT_AMOUNT');

        Slot0 memory _slot0 = slot0;
        uint112 _reserve0 = _slot0.reserve0;
        uint112 _reserve1 = _slot0.reserve1;

        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'Simswap: INSUFFICIENT_LIQUIDITY');
        
        uint256 _balance0;
        uint256 _balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(recipient != _token0 && recipient != _token1, 'Simswap: INVALID_TO');

        if (amount0Out > 0) _safeTransfer(_token0, recipient, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, recipient, amount1Out); // optimistically transfer tokens
        if (data.length > 0) ISimswapCallee(recipient).simswapCall(msg.sender, amount0Out, amount1Out, data);
        _balance0 = balance0();
        _balance1 = balance1();
        }

        uint256 res0 = _reserve0 - amount0Out;
        uint256 res1 = _reserve1 - amount1Out;

        uint256 amount0In = _balance0 > res0 ? _balance0 - res0 : 0;
        uint256 amount1In = _balance1 > res1 ? _balance1 - res1 : 0;
        require(amount0In > 0 || amount1In > 0, 'Simswap: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        uint256 balance0Adjusted = _balance0 * 1000 - amount0In * 3;
        uint256 balance1Adjusted = _balance1 * 1000 - amount1In * 3;
        require(balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * 1000000, 'Simswap: K');
        }

        _update(_balance0, _balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, recipient);
    }

    /// @dev Force balances to match reserves
    function skim(address recipient) external override nonReentrant {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        Slot0 memory _slot0 = slot0;
        _safeTransfer(_token0, recipient, balance0() - _slot0.reserve0);
        _safeTransfer(_token1, recipient, balance1() - _slot0.reserve1);
    }

    /// @dev Force reserves to match balances
    function sync() external override nonReentrant {
        Slot0 memory _slot0 = slot0;
        _update(balance0(), balance1(), _slot0.reserve0, _slot0.reserve1);
    }
}