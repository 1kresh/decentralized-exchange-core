// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import '../SimswapERC20.sol';

contract ERC20 is SimswapERC20 {
    constructor(uint _totalSupply) {
        _mint(msg.sender, _totalSupply);
    }
}