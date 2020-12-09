const { assert } = require('chai');

const {
  BN,
} = require('@openzeppelin/test-helpers');

const { currentTimestamp, DAY } = require('./common');

const TetherToken = artifacts.require('TetherToken');
const UniswapV2Factory = artifacts.require('UniswapV2Factory');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const EURxb = artifacts.require('EURxb');

contract('Router', ([owner, alice, bob]) => {
  it('test using uniswap', async () => {
    const router = await UniswapV2Router02.deployed();

    const eurxb = await EURxb.new(owner);
    await eurxb.configure(owner);
    await eurxb.mint(owner, web3.utils.toWei('1000000', 'ether'));
    const usdt = await TetherToken.deployed();

    assert.equal(await eurxb.balanceOf(owner), web3.utils.toWei('1000000', 'ether'));
    assert.equal(await usdt.balanceOf(owner), web3.utils.toWei('12042213561', 'ether'));

    await eurxb.approve(router.address, web3.utils.toWei('1000000', 'ether'));
    await usdt.approve(router.address, web3.utils.toWei('12042213561', 'ether'));

    const timestamp = (await currentTimestamp()) + DAY;
    await router.addLiquidity(
      eurxb.address,
      usdt.address,
      web3.utils.toWei('10000', 'ether'),
      web3.utils.toWei('10000', 'ether'),
      0,
      0,
      alice,
      timestamp
    );

    const factory = await UniswapV2Factory.deployed();
    const pairAddress = await factory.allPairs.call(new BN('0'));
    console.log(pairAddress);
  });
});
