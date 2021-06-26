const { expectRevert } = require('@openzeppelin/test-helpers');
const { assert } = require("chai");

const FlokiReferral = artifacts.require('FlokiReferral');

contract('FlokiReferral', ([alice, bob, carol, referrer, operator, owner]) => {
    beforeEach(async () => {
        this.flokiReferral = await FlokiReferral.new({ from: owner });
        this.zeroAddress = '0x0000000000000000000000000000000000000000';
    });

    it('should allow operator and only owner to update operator', async () => {
        assert.equal((await this.flokiReferral.operators(operator)).valueOf(), false);
        await expectRevert(this.flokiReferral.recordReferral(alice, referrer, { from: operator }), 'Operator: caller is not the operator');

        await expectRevert(this.flokiReferral.updateOperator(operator, true, { from: carol }), 'Ownable: caller is not the owner');
        await this.flokiReferral.updateOperator(operator, true, { from: owner });
        assert.equal((await this.flokiReferral.operators(operator)).valueOf(), true);

        await this.flokiReferral.updateOperator(operator, false, { from: owner });
        assert.equal((await this.flokiReferral.operators(operator)).valueOf(), false);
        await expectRevert(this.flokiReferral.recordReferral(alice, referrer, { from: operator }), 'Operator: caller is not the operator');
    });

    it('record referral', async () => {
        assert.equal((await this.flokiReferral.operators(operator)).valueOf(), false);
        await this.flokiReferral.updateOperator(operator, true, { from: owner });
        assert.equal((await this.flokiReferral.operators(operator)).valueOf(), true);

        await this.flokiReferral.recordReferral(this.zeroAddress, referrer, { from: operator });
        await this.flokiReferral.recordReferral(alice, this.zeroAddress, { from: operator });
        await this.flokiReferral.recordReferral(this.zeroAddress, this.zeroAddress, { from: operator });
        await this.flokiReferral.recordReferral(alice, alice, { from: operator });
        assert.equal((await this.flokiReferral.getReferrer(alice)).valueOf(), this.zeroAddress);
        assert.equal((await this.flokiReferral.referralsCount(referrer)).valueOf(), '0');

        await this.flokiReferral.recordReferral(alice, referrer, { from: operator });
        assert.equal((await this.flokiReferral.getReferrer(alice)).valueOf(), referrer);
        assert.equal((await this.flokiReferral.referralsCount(referrer)).valueOf(), '1');

        assert.equal((await this.flokiReferral.referralsCount(bob)).valueOf(), '0');
        await this.flokiReferral.recordReferral(alice, bob, { from: operator });
        assert.equal((await this.flokiReferral.referralsCount(bob)).valueOf(), '0');
        assert.equal((await this.flokiReferral.getReferrer(alice)).valueOf(), referrer);

        await this.flokiReferral.recordReferral(carol, referrer, { from: operator });
        assert.equal((await this.flokiReferral.getReferrer(carol)).valueOf(), referrer);
        assert.equal((await this.flokiReferral.referralsCount(referrer)).valueOf(), '2');
    });

    it('record referral commission', async () => {
        assert.equal((await this.flokiReferral.totalReferralCommissions(referrer)).valueOf(), '0');

        await expectRevert(this.flokiReferral.recordReferralCommission(referrer, 1, { from: operator }), 'Operator: caller is not the operator');
        await this.flokiReferral.updateOperator(operator, true, { from: owner });
        assert.equal((await this.flokiReferral.operators(operator)).valueOf(), true);

        await this.flokiReferral.recordReferralCommission(referrer, 1, { from: operator });
        assert.equal((await this.flokiReferral.totalReferralCommissions(referrer)).valueOf(), '1');

        await this.flokiReferral.recordReferralCommission(referrer, 0, { from: operator });
        assert.equal((await this.flokiReferral.totalReferralCommissions(referrer)).valueOf(), '1');

        await this.flokiReferral.recordReferralCommission(referrer, 111, { from: operator });
        assert.equal((await this.flokiReferral.totalReferralCommissions(referrer)).valueOf(), '112');

        await this.flokiReferral.recordReferralCommission(this.zeroAddress, 100, { from: operator });
        assert.equal((await this.flokiReferral.totalReferralCommissions(this.zeroAddress)).valueOf(), '0');
    });
});
