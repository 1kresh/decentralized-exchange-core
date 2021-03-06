import { Contract, Wallet, providers } from 'ethers'
import { deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './utilities'

import ERC20 from '../../build/ERC20.json'
import SimswapFactory from '../../build/SimswapFactory.json'
import SimswapPool from '../../build/SimswapPool.json'

interface FactoryFixture {
  factory: Contract
}

const overrides = {
  gasLimit: 99999999,
}

export async function factoryFixture([wallet]: Wallet[], _: providers.Web3Provider): Promise<FactoryFixture> {
  const factory = await deployContract(wallet, SimswapFactory, [wallet.address, wallet.address], overrides)
  return { factory }
}

interface PoolFixture extends FactoryFixture {
  token0: Contract
  token1: Contract
  pool: Contract
}

export async function poolFixture([wallet]: Wallet[], provider: providers.Web3Provider): Promise<PoolFixture> {
  const { factory } = await factoryFixture([wallet], provider)

  const tokenA = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)], overrides)
  const tokenB = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)], overrides)

  await factory.createPool(tokenA.address, tokenB.address, overrides)
  const poolAddress = await factory.getPool(tokenA.address, tokenB.address)
  const pool = new Contract(poolAddress, JSON.stringify(SimswapPool.abi), provider).connect(wallet)

  const token0Address = (await pool.token0()).address
  const token0 = tokenA.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.address === token0Address ? tokenB : tokenA

  return { factory, token0, token1, pool }
}
