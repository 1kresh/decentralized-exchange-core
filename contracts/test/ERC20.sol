// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

import { SimswapERC20 } from '../SimswapERC20.sol';

contract ERC20 is SimswapERC20 {
    constructor(uint256 _totalSupply) {
        _mint(msg.sender, _totalSupply);
    }
}
