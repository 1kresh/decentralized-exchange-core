import chai, { expect } from 'chai';
import { Contract, BigNumber, constants, utils } from 'ethers';
import { solidity, MockProvider, deployContract } from 'ethereum-waffle';
import { ecsign } from 'ethereumjs-util';

import { expandTo18Decimals, getApprovalDigest } from './shared/utilities';

import ERC20 from '../build/ERC20.json';

chai.use(solidity);

const TOTAL_SUPPLY = expandTo18Decimals(10000);
const TEST_AMOUNT = expandTo18Decimals(10);

describe('SimswapERC20', () => {
  const provider = new MockProvider({
    ganacheOptions: {
      hardfork: 'london',
      mnemonic:
        'simple simple simple simple simple simple simple simple simple simple simple simple',
      gasLimit: 99999999,
    },
  });
  const [wallet, other] = provider.getWallets();

  let token: Contract;
  beforeEach(async () => {
    token = await deployContract(wallet, ERC20, [TOTAL_SUPPLY]);
  });

  it('name, symbol, decimals, totalSupply, balanceOf, DOMAIN_SEPARATOR', async () => {
    const name = await token.name();
    expect(name).to.eq('Simswap');
    expect(await token.symbol()).to.eq('SIMP');
    expect(await token.decimals()).to.eq(18);
    expect(await token.totalSupply()).to.eq(TOTAL_SUPPLY);
    expect(await token.balanceOf(wallet.address)).to.eq(TOTAL_SUPPLY);
    expect(await token.DOMAIN_SEPARATOR()).to.eq(
      utils.keccak256(
        utils.defaultAbiCoder.encode(
          ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
          [
            utils.keccak256(
              utils.toUtf8Bytes(
                'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
              )
            ),
            utils.keccak256(utils.toUtf8Bytes(name)),
            utils.keccak256(utils.toUtf8Bytes('1')),
            1337,
            token.address,
          ]
        )
      )
    );
  });

  it('approve', async () => {
    await expect(token.approve(other.address, TEST_AMOUNT))
      .to.emit(token, 'Approval')
      .withArgs(wallet.address, other.address, TEST_AMOUNT);
    expect(await token.allowance(wallet.address, other.address)).to.eq(TEST_AMOUNT);
  });

  it('transfer', async () => {
    await expect(token.transfer(other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, TEST_AMOUNT);
    expect(await token.balanceOf(wallet.address)).to.eq(TOTAL_SUPPLY.sub(TEST_AMOUNT));
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT);
  });

  it('transfer:fail', async () => {
    await expect(token.transfer(other.address, TOTAL_SUPPLY.add(1))).to.be.reverted; // ds-math-sub-underflow
    await expect(token.connect(other).transfer(wallet.address, 1)).to.be.reverted; // ds-math-sub-underflow
  });

  it('transferFrom', async () => {
    await token.approve(other.address, TEST_AMOUNT);
    await expect(token.connect(other).transferFrom(wallet.address, other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, TEST_AMOUNT);
    expect(await token.allowance(wallet.address, other.address)).to.eq(0);
    expect(await token.balanceOf(wallet.address)).to.eq(TOTAL_SUPPLY.sub(TEST_AMOUNT));
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT);
  });

  it('transferFrom:max', async () => {
    await token.approve(other.address, constants.MaxUint256);
    await expect(token.connect(other).transferFrom(wallet.address, other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, TEST_AMOUNT);
    expect(await token.allowance(wallet.address, other.address)).to.eq(constants.MaxUint256);
    expect(await token.balanceOf(wallet.address)).to.eq(TOTAL_SUPPLY.sub(TEST_AMOUNT));
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT);
  });

  it('permit', async () => {
    const nonce = await token.nonces(wallet.address);
    const deadline = constants.MaxUint256;
    const digest = await getApprovalDigest(
      token,
      { owner: wallet.address, spender: other.address, value: TEST_AMOUNT },
      nonce,
      deadline
    );

    const { v, r, s } = ecsign(
      Buffer.from(digest.slice(2), 'hex'),
      Buffer.from(wallet.privateKey.slice(2), 'hex')
    );

    await expect(
      token.permit(
        wallet.address,
        other.address,
        TEST_AMOUNT,
        deadline,
        v,
        utils.hexlify(r),
        utils.hexlify(s)
      )
    )
      .to.emit(token, 'Approval')
      .withArgs(wallet.address, other.address, TEST_AMOUNT);
    expect(await token.allowance(wallet.address, other.address), 'allowance').to.eq(TEST_AMOUNT);
    expect(await token.nonces(wallet.address), 'nonces').to.eq(BigNumber.from(1));
  });
});
