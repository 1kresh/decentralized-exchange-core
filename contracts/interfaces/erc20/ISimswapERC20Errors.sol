// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

/// @title Errors reverted by a erc20
/// @notice Contains all errors reverted by the erc20
interface ISimswapERC20Errors {
    error SimswapERC20_BURN_FROM_ZERO_ADDRESS(address account, uint256 amount);
    error SimswapERC20_APPROVE_FROM_ZERO_ADDRESS(address owner, address spender, uint256 amount);
    error SimswapERC20_APPROVE_TO_ZERO_ADDRESS(address owner, address spender, uint256 amount);
    error SimswapERC20_TRANSFER_FROM_ZERO_ADDRESS(address spender, address recipient, uint256 amount);
    error SimswapERC20_TRANSFER_TO_ZERO_ADDRESS(address spender, address recipient, uint256 amount);
    error Simswap_EXPIRED(uint256 deadline, uint256 blockTimestamp);
}