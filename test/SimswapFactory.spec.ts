import chai, { expect } from 'chai'
import { Contract, BigNumber, constants, utils } from 'ethers'
import { solidity, MockProvider, createFixtureLoader } from 'ethereum-waffle'

import { getCreate2Address } from './shared/utilities'
import { factoryFixture } from './shared/fixtures'

import SimswapPool from '../build/SimswapPool.json'

chai.use(solidity)

const TEST_ADDRESSES: [string, string] = [
  '0x1000000000000000000000000000000000000000',
  '0x2000000000000000000000000000000000000000',
]

describe('SimswapFactory', () => {
  const provider = new MockProvider({
    ganacheOptions: {
      hardfork: 'london',
      mnemonic: 'simple simple simple simple simple simple simple simple simple simple simple simple',
      gasLimit: 99999999,
    },
  })
  const [wallet, other] = provider.getWallets()
  const loadFixture = createFixtureLoader([wallet, other], provider)

  let factory: Contract
  beforeEach(async () => {
    const fixture = await loadFixture(factoryFixture)
    factory = fixture.factory
  })

  it('feeTo, feeToSetter, allPoolsLength', async () => {
    expect(await factory.feeTo()).to.eq(wallet.address)
    expect(await factory.feeToSetter()).to.eq(wallet.address)
    expect(await factory.allPoolsLength()).to.eq(0)
  })

  async function createPool(tokens: [string, string]) {
    const bytecode = `0x${SimswapPool.evm.bytecode.object}`
    const create2Address = getCreate2Address(factory.address, tokens, bytecode)

    await expect(factory.createPool(...tokens))
      .to.emit(factory, 'PoolCreated')
      .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], create2Address, BigNumber.from(1))
    await expect(factory.createPool(...tokens)).to.be.reverted // Simswap: POOL_EXISTS
    await expect(factory.createPool(...tokens.slice().reverse())).to.be.reverted // Simswap: POOL_EXISTS
    expect(await factory.getPool(...tokens)).to.eq(create2Address)
    expect(await factory.getPool(...tokens.slice().reverse())).to.eq(create2Address)
    expect((await factory.allPools())[0]).to.eq(create2Address)
    expect(await factory.allPoolsLength()).to.eq(1)

    const pool = new Contract(create2Address, JSON.stringify(SimswapPool.abi), provider)
    expect(await pool.factory()).to.eq(factory.address)
    expect(await pool.token0()).to.eq(TEST_ADDRESSES[0])
    expect(await pool.token1()).to.eq(TEST_ADDRESSES[1])
  }

  it('createPool', async () => {
    await createPool(TEST_ADDRESSES)
  })

  it('createPool:reverse', async () => {
    await createPool(TEST_ADDRESSES.slice().reverse() as [string, string])
  })

  it('createPool:gas', async () => {
    const tx = await factory.createPool(...TEST_ADDRESSES)
    const receipt = await tx.wait()
    expect(receipt.gasUsed).to.eq(1907717)
  })

  it('setFeeTo', async () => {
    await expect(factory.connect(other).setFeeTo(other.address)).to.be.reverted
    await factory.setFeeTo(wallet.address)
    expect(await factory.feeTo()).to.eq(wallet.address)
  })

  it('setFeeToSetter', async () => {
    await expect(factory.connect(other).setFeeToSetter(other.address)).to.be.reverted
    await factory.setFeeToSetter(other.address)
    expect(await factory.feeToSetter()).to.eq(other.address)
    await expect(factory.setFeeToSetter(wallet.address)).to.be.reverted
  })
})
