import chai, { expect } from 'chai';
import { Contract, BigNumber, constants, utils } from 'ethers';
import { solidity, MockProvider, createFixtureLoader } from 'ethereum-waffle';

import { expandTo18Decimals, mineBlock, encodePrice } from './shared/utilities';
import { poolFixture } from './shared/fixtures';

import SimswapPool from '../build/SimswapPool.json';

const MINIMUM_LIQUIDITY = BigNumber.from(10).pow(3);

chai.use(solidity);

const overrides = {
  gasLimit: 99999999,
};

describe('SimswapPool', () => {
  const provider = new MockProvider({
    ganacheOptions: {
      hardfork: 'london',
      mnemonic:
        'simple simple simple simple simple simple simple simple simple simple simple simple',
      gasLimit: 99999999,
    },
  });
  const [wallet, other] = provider.getWallets();
  const loadFixture = createFixtureLoader([wallet], provider);

  let factory: Contract;
  let token0: Contract;
  let token1: Contract;
  let pool: Contract;
  beforeEach(async () => {
    const fixture = await loadFixture(poolFixture);
    factory = fixture.factory;
    token0 = fixture.token0;
    token1 = fixture.token1;
    pool = fixture.pool;
  });

  it('mint', async () => {
    const bytecode = `0x${SimswapPool.evm.bytecode.object}`;

    const token0Amount = expandTo18Decimals(1);
    const token1Amount = expandTo18Decimals(4);
    await token0.transfer(pool.address, token0Amount);
    await token1.transfer(pool.address, token1Amount);

    const expectedLiquidity = expandTo18Decimals(2);
    await expect(pool.mint(wallet.address, overrides))
      .to.emit(pool, 'Transfer')
      .withArgs(constants.AddressZero, constants.AddressZero, MINIMUM_LIQUIDITY)
      .to.emit(pool, 'Transfer')
      .withArgs(constants.AddressZero, wallet.address, expectedLiquidity.sub(MINIMUM_LIQUIDITY))
      .to.emit(pool, 'Sync')
      .withArgs(token0Amount, token1Amount)
      .to.emit(pool, 'Mint')
      .withArgs(wallet.address, token0Amount, token1Amount);

    expect(await pool.totalSupply()).to.eq(expectedLiquidity);
    expect(await pool.balanceOf(wallet.address)).to.eq(expectedLiquidity.sub(MINIMUM_LIQUIDITY));
    expect(await token0.balanceOf(pool.address)).to.eq(token0Amount);
    expect(await token1.balanceOf(pool.address)).to.eq(token1Amount);
    const slot0 = await pool.slot0();
    expect(slot0[0]).to.eq(token0Amount);
    expect(slot0[1]).to.eq(token1Amount);
  });

  async function addLiquidity(token0Amount: BigNumber, token1Amount: BigNumber) {
    await token0.transfer(pool.address, token0Amount);
    await token1.transfer(pool.address, token1Amount);
    await pool.mint(wallet.address, overrides);
  }
  const swapTestCases: BigNumber[][] = [
    [1, 5, 10, '1662497915624478906'],
    [1, 10, 5, '453305446940074565'],

    [2, 5, 10, '2851015155847869602'],
    [2, 10, 5, '831248957812239453'],

    [1, 10, 10, '906610893880149131'],
    [1, 100, 100, '987158034397061298'],
    [1, 1000, 1000, '996006981039903216'],
  ].map((a) => a.map((n) => (typeof n === 'string' ? BigNumber.from(n) : expandTo18Decimals(n))));
  swapTestCases.forEach((swapTestCase, i) => {
    it(`getInputPrice:${i}`, async () => {
      const [swapAmount, token0Amount, token1Amount, expectedOutputAmount] = swapTestCase;
      await addLiquidity(token0Amount, token1Amount);
      await token0.transfer(pool.address, swapAmount);
      await expect(pool.swap(0, expectedOutputAmount.add(1), wallet.address, '0x', overrides)).to.be
        .reverted;
      await pool.swap(0, expectedOutputAmount, wallet.address, '0x', overrides);
    });
  });

  const optimisticTestCases: BigNumber[][] = [
    ['997000000000000000', 5, 10, 1], // given amountIn, amountOut = floor(amountIn * .997)
    ['997000000000000000', 10, 5, 1],
    ['997000000000000000', 5, 5, 1],
    [1, 5, 5, '1003009027081243732'], // given amountOut, amountIn = ceiling(amountOut / .997)
  ].map((a) => a.map((n) => (typeof n === 'string' ? BigNumber.from(n) : expandTo18Decimals(n))));
  optimisticTestCases.forEach((optimisticTestCase, i) => {
    it(`optimistic:${i}`, async () => {
      const [outputAmount, token0Amount, token1Amount, inputAmount] = optimisticTestCase;
      await addLiquidity(token0Amount, token1Amount);
      await token0.transfer(pool.address, inputAmount);
      await expect(pool.swap(outputAmount.add(1), 0, wallet.address, '0x', overrides)).to.be
        .reverted;
      await pool.swap(outputAmount, 0, wallet.address, '0x', overrides);
    });
  });

  it('swap:token0', async () => {
    const token0Amount = expandTo18Decimals(5);
    const token1Amount = expandTo18Decimals(10);
    await addLiquidity(token0Amount, token1Amount);

    const swapAmount = expandTo18Decimals(1);
    const expectedOutputAmount = BigNumber.from('1662497915624478906');
    await token0.transfer(pool.address, swapAmount);
    await expect(pool.swap(0, expectedOutputAmount, wallet.address, '0x', overrides))
      .to.emit(token1, 'Transfer')
      .withArgs(pool.address, wallet.address, expectedOutputAmount)
      .to.emit(pool, 'Sync')
      .withArgs(token0Amount.add(swapAmount), token1Amount.sub(expectedOutputAmount))
      .to.emit(pool, 'Swap')
      .withArgs(wallet.address, swapAmount, 0, 0, expectedOutputAmount, wallet.address);

    const slot0 = await pool.slot0();
    expect(slot0[0]).to.eq(token0Amount.add(swapAmount));
    expect(slot0[1]).to.eq(token1Amount.sub(expectedOutputAmount));
    expect(await token0.balanceOf(pool.address)).to.eq(token0Amount.add(swapAmount));
    expect(await token1.balanceOf(pool.address)).to.eq(token1Amount.sub(expectedOutputAmount));
    const totalSupplyToken0 = await token0.totalSupply();
    const totalSupplyToken1 = await token1.totalSupply();
    expect(await token0.balanceOf(wallet.address)).to.eq(
      totalSupplyToken0.sub(token0Amount).sub(swapAmount)
    );
    expect(await token1.balanceOf(wallet.address)).to.eq(
      totalSupplyToken1.sub(token1Amount).add(expectedOutputAmount)
    );
  });

  it('swap:token1', async () => {
    const token0Amount = expandTo18Decimals(5);
    const token1Amount = expandTo18Decimals(10);
    await addLiquidity(token0Amount, token1Amount);

    const swapAmount = expandTo18Decimals(1);
    const expectedOutputAmount = BigNumber.from('453305446940074565');
    await token1.transfer(pool.address, swapAmount);
    await expect(pool.swap(expectedOutputAmount, 0, wallet.address, '0x', overrides))
      .to.emit(token0, 'Transfer')
      .withArgs(pool.address, wallet.address, expectedOutputAmount)
      .to.emit(pool, 'Sync')
      .withArgs(token0Amount.sub(expectedOutputAmount), token1Amount.add(swapAmount))
      .to.emit(pool, 'Swap')
      .withArgs(wallet.address, 0, swapAmount, expectedOutputAmount, 0, wallet.address);

    const slot0 = await pool.slot0();
    expect(slot0[0]).to.eq(token0Amount.sub(expectedOutputAmount));
    expect(slot0[1]).to.eq(token1Amount.add(swapAmount));
    expect(await token0.balanceOf(pool.address)).to.eq(token0Amount.sub(expectedOutputAmount));
    expect(await token1.balanceOf(pool.address)).to.eq(token1Amount.add(swapAmount));
    const totalSupplyToken0 = await token0.totalSupply();
    const totalSupplyToken1 = await token1.totalSupply();
    expect(await token0.balanceOf(wallet.address)).to.eq(
      totalSupplyToken0.sub(token0Amount).add(expectedOutputAmount)
    );
    expect(await token1.balanceOf(wallet.address)).to.eq(
      totalSupplyToken1.sub(token1Amount).sub(swapAmount)
    );
  });

  it('swap:gas', async () => {
    const token0Amount = expandTo18Decimals(5);
    const token1Amount = expandTo18Decimals(10);
    await addLiquidity(token0Amount, token1Amount);

    // ensure that setting price{0,1}CumulativeLast for the first time doesn't affect our gas math
    await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1);
    await pool.sync(overrides);

    const swapAmount = expandTo18Decimals(1);
    const expectedOutputAmount = BigNumber.from('453305446940074565');
    await token1.transfer(pool.address, swapAmount);
    await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1);
    const tx = await pool.swap(expectedOutputAmount, 0, wallet.address, '0x', overrides);
    const receipt = await tx.wait();
    expect(receipt.gasUsed).to.eq(60477);
  });

  it('burn', async () => {
    const token0Amount = expandTo18Decimals(3);
    const token1Amount = expandTo18Decimals(3);
    await addLiquidity(token0Amount, token1Amount);

    const expectedLiquidity = expandTo18Decimals(3);
    await pool.transfer(pool.address, expectedLiquidity.sub(MINIMUM_LIQUIDITY));
    await expect(pool.burn(wallet.address, overrides))
      .to.emit(pool, 'Transfer')
      .withArgs(pool.address, constants.AddressZero, expectedLiquidity.sub(MINIMUM_LIQUIDITY))
      .to.emit(token0, 'Transfer')
      .withArgs(pool.address, wallet.address, token0Amount.sub(1000))
      .to.emit(token1, 'Transfer')
      .withArgs(pool.address, wallet.address, token1Amount.sub(1000))
      .to.emit(pool, 'Sync')
      .withArgs(1000, 1000)
      .to.emit(pool, 'Burn')
      .withArgs(wallet.address, token0Amount.sub(1000), token1Amount.sub(1000), wallet.address);

    expect(await pool.balanceOf(wallet.address)).to.eq(0);
    expect(await pool.totalSupply()).to.eq(MINIMUM_LIQUIDITY);
    expect(await token0.balanceOf(pool.address)).to.eq(1000);
    expect(await token1.balanceOf(pool.address)).to.eq(1000);
    const totalSupplyToken0 = await token0.totalSupply();
    const totalSupplyToken1 = await token1.totalSupply();
    expect(await token0.balanceOf(wallet.address)).to.eq(totalSupplyToken0.sub(1000));
    expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1.sub(1000));
  });

  it('price{0,1}CumulativeLast', async () => {
    const token0Amount = expandTo18Decimals(3);
    const token1Amount = expandTo18Decimals(3);
    await addLiquidity(token0Amount, token1Amount);
    const blockTimestamp = (await pool.slot0())[2];
    await mineBlock(provider, blockTimestamp + 1);
    await pool.sync(overrides);
    const initialPrice = encodePrice(token0Amount, token1Amount);
    expect(await pool.price0CumulativeLast()).to.eq(initialPrice[0]);
    expect(await pool.price1CumulativeLast()).to.eq(initialPrice[1]);
    expect((await pool.slot0())[2]).to.eq(blockTimestamp + 1);
    const swapAmount = expandTo18Decimals(3);
    await token0.transfer(pool.address, swapAmount);
    await mineBlock(provider, blockTimestamp + 10);
    // swap to a new price eagerly instead of syncing
    await pool.swap(0, expandTo18Decimals(1), wallet.address, '0x', overrides); // make the price nice
    expect(await pool.price0CumulativeLast()).to.eq(initialPrice[0].mul(10));
    expect(await pool.price1CumulativeLast()).to.eq(initialPrice[1].mul(10));
    expect((await pool.slot0())[2]).to.eq(blockTimestamp + 10);

    await mineBlock(provider, blockTimestamp + 20);
    await pool.sync(overrides);
    const newPrice = encodePrice(expandTo18Decimals(6), expandTo18Decimals(2));
    expect(await pool.price0CumulativeLast()).to.eq(
      initialPrice[0].mul(10).add(newPrice[0].mul(10))
    );
    expect(await pool.price1CumulativeLast()).to.eq(
      initialPrice[1].mul(10).add(newPrice[1].mul(10))
    );
    expect((await pool.slot0())[2]).to.eq(blockTimestamp + 20);
  });

  it('feeTo:off', async () => {
    const token0Amount = expandTo18Decimals(1000);
    const token1Amount = expandTo18Decimals(1000);
    await addLiquidity(token0Amount, token1Amount);

    const swapAmount = expandTo18Decimals(1);
    const expectedOutputAmount = BigNumber.from('996006981039903216');
    await token1.transfer(pool.address, swapAmount);
    await pool.swap(expectedOutputAmount, 0, wallet.address, '0x', overrides);

    const expectedLiquidity = expandTo18Decimals(1000);
    await pool.transfer(pool.address, expectedLiquidity.sub(MINIMUM_LIQUIDITY));
    await pool.burn(wallet.address, overrides);
    expect(await pool.totalSupply()).to.eq(MINIMUM_LIQUIDITY);
  });

  it('feeTo:on', async () => {
    await factory.setFeeTo(other.address);

    const token0Amount = expandTo18Decimals(1000);
    const token1Amount = expandTo18Decimals(1000);
    await addLiquidity(token0Amount, token1Amount);

    const swapAmount = expandTo18Decimals(1);
    const expectedOutputAmount = BigNumber.from('996006981039903216');
    await token1.transfer(pool.address, swapAmount);
    await pool.swap(expectedOutputAmount, 0, wallet.address, '0x', overrides);

    const expectedLiquidity = expandTo18Decimals(1000);
    await pool.transfer(pool.address, expectedLiquidity.sub(MINIMUM_LIQUIDITY));
    await pool.burn(wallet.address, overrides);
    expect(await pool.totalSupply()).to.eq(MINIMUM_LIQUIDITY.add('249750499251388'));
    expect(await pool.balanceOf(other.address)).to.eq('249750499251388');

    // using 1000 here instead of the symbolic MINIMUM_LIQUIDITY because the amounts only happen to be equal...
    // ...because the initial liquidity amounts were equal
    expect(await token0.balanceOf(pool.address)).to.eq(BigNumber.from(1000).add('249501683697445'));
    expect(await token1.balanceOf(pool.address)).to.eq(BigNumber.from(1000).add('250000187312969'));
  });
});
