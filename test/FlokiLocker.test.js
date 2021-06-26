const { expectRevert } = require('@openzeppelin/test-helpers');
const { assert } = require("chai");
const FlokiLocker = artifacts.require('FlokiLocker');
const MockBEP20 = artifacts.require('libs/MockBEP20');


contract('FlokiLocker', ([alice, bob, carol, owner]) => {
    beforeEach(async () => {
        this.lp1 = await MockBEP20.new('LPToken', 'LP1', '1000000', { from: owner });
        this.flokiLocker = await FlokiLocker.new({ from: owner });
    });

    it('only owner', async () => {
        assert.equal((await this.flokiLocker.owner()), owner);

        // lock
        await this.lp1.transfer(this.flokiLocker.address, '2000', { from: owner });
        assert.equal((await this.lp1.balanceOf(this.flokiLocker.address)).toString(), '2000');

        await expectRevert(this.flokiLocker.unlock(this.lp1.address, bob, { from: bob }), 'Ownable: caller is not the owner');
        await this.flokiLocker.unlock(this.lp1.address, carol, { from: owner });
        assert.equal((await this.lp1.balanceOf(carol)).toString(), '2000');
        assert.equal((await this.lp1.balanceOf(this.flokiLocker.address)).toString(), '0');
    });
})
