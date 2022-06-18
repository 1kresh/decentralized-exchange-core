// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import './interfaces/ISimswapERC20.sol';
import './libraries/LowGasSafeMath.sol';

contract SimswapERC20 is ISimswapERC20 {
    using LowGasSafeMath for uint256;

    string public constant override _name = 'Simswap';
    string public constant override _symbol = 'simp';
    uint8 public constant override _decimals = 18;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private immutable INITIAL_CHAIN_ID;
    bytes32 private immutable INITIAL_DOMAIN_SEPARATOR;

    // keccak256("Permit(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)");    
    bytes32 private constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    mapping(address => uint256) private _nonces;

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view override returns (uint256) { 
        return _allowances[owner][spender];
    }

    function nonces(address owner) public view override returns (uint256) { 
        return _nonces[owner];
    }

    constructor() {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }


    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "SimswapERC20: mint to the zero address");

        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "SimswapERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        _balances[account] = accountBalance - amount;
        _totalSupply = _totalSupply - amount;

        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "SimswapERC20: approve from the zero address");
        require(spender != address(0), "SimswapERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "SimswapERC20: transfer from the zero address");
        require(to != address(0), "SimswapERC20: transfer to the zero address");
        uint256 fromBalance = _balances[from];
        _balances[from] = fromBalance - amount;
        _balances[to] = _balances[to] + amount;
        emit Transfer(from, to, amount);
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address account, uint256 amount) external override returns (bool) {
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

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        _spendAllowance(from, to, amount);
        _transfer(from, to, amount);
        return true;
    }

    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override {
        require(deadline >= block.timestamp, 'Simswap: EXPIRED');

        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
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
            require(recoveredAddress != address(0) && recoveredAddress == owner, 'Simswap: INVALID_SIGNATURE');
            _approve(recoveredAddress, spender, amount);
        }
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DOMAIN_TYPEHASH,
                    keccak256(bytes(_name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }
}