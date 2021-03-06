/* eslint no-unused-vars: 0 */
/* eslint eqeqeq: 0 */

const { assert } = require('chai');
const {
  BN,
  constants,
  expectEvent,
  expectRevert,
} = require('@openzeppelin/test-helpers');

const AllowList = artifacts.require('AllowList');

contract('AllowListTest', (accounts) => {
  const multisig = accounts[1];
  const alice = accounts[2];
  const bob = accounts[3];

  beforeEach(async () => {
    this.list = await AllowList.new(multisig);
  });

  it('check multisig is allow list admin', async () => {
    await this.list.allowAccount(alice, { from: multisig });
  });

  it('check empty list', async () => {
    assert(
      !(await this.list.isAllowedAccount(alice)),
      'alice must not be in the list in the beginning',
    );
  });

  it('only admin can allow account', async () => {
    assert(
      !(await this.list.isAllowedAccount(alice)),
      'alice must not be in the list in the beginning',
    );
    await expectRevert(
      this.list.allowAccount(alice, { from: bob }),
      'user is not admin',
    );
  });

  it('add account', async () => {
    assert(
      !(await this.list.isAllowedAccount(alice)),
      'alice must not be in the list in the beginning',
    );
    await this.list.allowAccount(alice, { from: multisig });
    assert(
      await this.list.isAllowedAccount(alice),
      'now the list should have alice',
    );
  });

  it('only admin can disallow account', async () => {
    assert(
      !(await this.list.isAllowedAccount(alice)),
      'alice must not be in the list in the beginning',
    );
    await this.list.allowAccount(alice, { from: multisig });
    await expectRevert(
      this.list.allowAccount(alice, { from: bob }),
      'user is not admin',
    );
  });

  it('disallow account', async () => {
    assert(
      !(await this.list.isAllowedAccount(alice)),
      'alice must not be in the list in the beginning',
    );
    await this.list.allowAccount(alice, { from: multisig });
    assert(
      await this.list.isAllowedAccount(alice),
      'now the list should have alice',
    );
    await this.list.disallowAccount(alice, { from: multisig });
    assert(
      !(await this.list.isAllowedAccount(alice)),
      'alice must have been removed',
    );
  });
});
