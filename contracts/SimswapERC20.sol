// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

import { ISimswapERC20 } from './interfaces/ISimswapERC20.sol';

contract SimswapERC20 is ISimswapERC20 {
    string private constant _name = 'Simswap';
    string private constant _symbol = 'SIMP';
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private immutable INITIAL_CHAIN_ID;
    bytes32 private immutable INITIAL_DOMAIN_SEPARATOR;

    // keccak256("Permit(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)");
    bytes32 private constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    mapping(address => uint256) private _nonces;

    constructor() {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    function name() public pure override returns (string memory) {
        return _name;
    }

    function symbol() public pure override returns (string memory) {
        return _symbol;
    }

    function decimals() public pure override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function nonces(address owner) public view override returns (uint256) {
        return _nonces[owner];
    }

    function _mint(address account, uint256 amount) internal {
        _totalSupply += amount;
        _balances[account] += amount;

        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0))
            revert SimswapERC20_BURN_FROM_ZERO_ADDRESS(account, amount);

        _balances[account] -= amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        if (owner == address(0))
            revert SimswapERC20_APPROVE_FROM_ZERO_ADDRESS(
                owner,
                spender,
                amount
            );
        if (spender == address(0))
            revert SimswapERC20_APPROVE_TO_ZERO_ADDRESS(owner, spender, amount);

        _allowances[owner][spender] = amount;

        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        if (from == address(0))
            revert SimswapERC20_TRANSFER_FROM_ZERO_ADDRESS(from, to, amount);
        if (to == address(0))
            revert SimswapERC20_TRANSFER_TO_ZERO_ADDRESS(from, to, amount);

        _balances[from] -= amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address account, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(msg.sender, account, amount);
        return true;
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            _approve(owner, spender, currentAllowance - amount);
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        _spendAllowance(from, to, amount);
        _transfer(from, to, amount);
        return true;
    }

    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override {
        {
            uint256 blockTimestamp = block.timestamp;
            if (deadline < blockTimestamp)
                revert SimswapERC20_EXPIRED(deadline, blockTimestamp);
        }

        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        '\x19\x01',
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                PERMIT_TYPEHASH,
                                owner,
                                spender,
                                amount,
                                _nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );
            require(recoveredAddress == owner, 'Simswap: INVALID_SIGNATURE');
            _approve(recoveredAddress, spender, amount);
        }
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return
            block.chainid == INITIAL_CHAIN_ID
                ? INITIAL_DOMAIN_SEPARATOR
                : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DOMAIN_TYPEHASH,
                    keccak256(bytes(_name)),
                    keccak256('1'),
                    block.chainid,
                    address(this)
                )
            );
    }
}
