const { expectRevert } = require("@openzeppelin/test-helpers");
const { assert } = require("chai");

const FlokiToken = artifacts.require('FlokiToken');

contract('FlokiToken', ([alice, bob, carol, operator, owner]) => {
    beforeEach(async () => {
        this.floki = await FlokiToken.new({ from: owner });
        // this.floki2 = await FlokiToken.new({ from: owner });
        this.burnAddress = '0x000000000000000000000000000000000000dEaD';
        this.zeroAddress = '0x0000000000000000000000000000000000000000';
    });

    it('burned imediately and max cap', async () => {
        assert(await this.floki.balanceOf(this.burnAddress).toString(), "500000000000000000000000000000")
        const cap = await this.floki.cap()
        await expectRevert(this.floki.mint(alice, cap, { from: owner }), "FLOKI::transfer: Supply Reach Cap")
    });


    it('operator should be free', async () => {
        assert((await this.floki.operator()), owner)
        await this.floki.transfer(alice, 500, {from: owner})
        assert.equal((await this.floki.balanceOf(alice)).toString(), "500")
        await this.floki.transfer(owner, 400, {from: alice})
        assert.equal((await this.floki.balanceOf(alice)).toString(), "100")
    });

    it('mint with dev', async () => {
        await this.floki.mintWithDevReward(alice, bob, 5000, {from: owner});
        assert.equal((await this.floki.balanceOf(alice)).toString(), "4091");
        assert.equal((await this.floki.balanceOf(bob)).toString(), "909");
    });

    it('only operator', async () => {
        assert.equal((await this.floki.owner()), owner);
        assert.equal((await this.floki.operator()), owner);

        await expectRevert(this.floki.updateTransferTaxRate(500, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.floki.updateBurnRate(20, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.floki.updateMaxTransferAmountRate(100, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.floki.updateSwapAndLiquifyEnabled(true, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.floki.setExcludedFromAntiWhale(operator, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.floki.updateFlokiSwapRouter(operator, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.floki.updateMinAmountToLiquify(100, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.floki.transferOperator(alice, { from: operator }), 'operator: caller is not the operator');
    });

    it('transfer operator', async () => {
        await expectRevert(this.floki.transferOperator(operator, { from: operator }), 'operator: caller is not the operator');
        await this.floki.transferOperator(operator, { from: owner });
        assert.equal((await this.floki.operator()), operator);

        await expectRevert(this.floki.transferOperator(this.zeroAddress, { from: operator }), 'FLOKI::transferOperator: new operator is the zero address');
    });

    it('update transfer tax rate', async () => {
        await this.floki.transferOperator(operator, { from: owner });
        assert.equal((await this.floki.operator()), operator);

        assert.equal((await this.floki.transferTaxRate()).toString(), '500');
        assert.equal((await this.floki.burnRate()).toString(), '20');

        await this.floki.updateTransferTaxRate(0, { from: operator });
        assert.equal((await this.floki.transferTaxRate()).toString(), '0');
        await this.floki.updateTransferTaxRate(1000, { from: operator });
        assert.equal((await this.floki.transferTaxRate()).toString(), '1000');
        await expectRevert(this.floki.updateTransferTaxRate(1001, { from: operator }), 'FLOKI::updateTransferTaxRate: Transfer tax rate must not exceed the maximum rate.');

        await this.floki.updateBurnRate(0, { from: operator });
        assert.equal((await this.floki.burnRate()).toString(), '0');
        await this.floki.updateBurnRate(100, { from: operator });
        assert.equal((await this.floki.burnRate()).toString(), '100');
        await expectRevert(this.floki.updateBurnRate(101, { from: operator }), 'FLOKI::updateBurnRate: Burn rate must not exceed the maximum rate.');
    });

    it('transfer', async () => {
        await this.floki.transferOperator(operator, { from: owner });
        assert.equal((await this.floki.operator()), operator);

        await this.floki.mint(alice, 10000000, { from: owner }); // max transfer amount 25,000
        assert.equal((await this.floki.balanceOf(alice)).toString(), '10000000');
        assert.equal((await this.floki.balanceOf(this.burnAddress)).toString(), '500000000000000000000000000000');
        assert.equal((await this.floki.balanceOf(this.floki.address)).toString(), '0');

        await this.floki.transfer(bob, 12345, { from: alice });
        assert.equal((await this.floki.balanceOf(alice)).toString(), '9987655');
        assert.equal((await this.floki.balanceOf(bob)).toString(), '11728');
        assert.equal((await this.floki.balanceOf(this.burnAddress)).toString(), '500000000000000000000000000123');
        assert.equal((await this.floki.balanceOf(this.floki.address)).toString(), '494');

        await this.floki.approve(carol, 22345, { from: alice });
        await this.floki.transferFrom(alice, carol, 22345, { from: carol });
        assert.equal((await this.floki.balanceOf(alice)).toString(), '9965310');
        assert.equal((await this.floki.balanceOf(carol)).toString(), '21228');
        assert.equal((await this.floki.balanceOf(this.burnAddress)).toString(), '500000000000000000000000000346');
        assert.equal((await this.floki.balanceOf(this.floki.address)).toString(), '1388');
    });

    it('transfer small amount', async () => {
        await this.floki.transferOperator(operator, { from: owner });
        assert.equal((await this.floki.operator()), operator);

        await this.floki.mint(alice, 10000000, { from: owner });
        assert.equal((await this.floki.balanceOf(alice)).toString(), '10000000');
        assert.equal((await this.floki.balanceOf(this.burnAddress)).toString(), '500000000000000000000000000000');
        assert.equal((await this.floki.balanceOf(this.floki.address)).toString(), '0');

        await this.floki.transfer(bob, 19, { from: alice });
        assert.equal((await this.floki.balanceOf(alice)).toString(), '9999981');
        assert.equal((await this.floki.balanceOf(bob)).toString(), '19');
        assert.equal((await this.floki.balanceOf(this.burnAddress)).toString(), '500000000000000000000000000000');
        assert.equal((await this.floki.balanceOf(this.floki.address)).toString(), '0');
    });

    it('transfer without transfer tax', async () => {
        await this.floki.transferOperator(operator, { from: owner });
        assert.equal((await this.floki.operator()), operator);

        assert.equal((await this.floki.transferTaxRate()).toString(), '500');
        assert.equal((await this.floki.burnRate()).toString(), '20');

        await this.floki.updateTransferTaxRate(0, { from: operator });
        assert.equal((await this.floki.transferTaxRate()).toString(), '0');

        await this.floki.mint(alice, 10000000, { from: owner });
        assert.equal((await this.floki.balanceOf(alice)).toString(), '10000000');
        assert.equal((await this.floki.balanceOf(this.burnAddress)).toString(), '500000000000000000000000000000');
        assert.equal((await this.floki.balanceOf(this.floki.address)).toString(), '0');

        await this.floki.transfer(bob, 10000, { from: alice });
        assert.equal((await this.floki.balanceOf(alice)).toString(), '9990000');
        assert.equal((await this.floki.balanceOf(bob)).toString(), '10000');
        assert.equal((await this.floki.balanceOf(this.burnAddress)).toString(), '500000000000000000000000000000');
        assert.equal((await this.floki.balanceOf(this.floki.address)).toString(), '0');
    });

    it('transfer without burn', async () => {
        await this.floki.transferOperator(operator, { from: owner });
        assert.equal((await this.floki.operator()), operator);

        assert.equal((await this.floki.transferTaxRate()).toString(), '500');
        assert.equal((await this.floki.burnRate()).toString(), '20');

        await this.floki.updateBurnRate(0, { from: operator });
        assert.equal((await this.floki.burnRate()).toString(), '0');

        await this.floki.mint(alice, 10000000, { from: owner });
        assert.equal((await this.floki.balanceOf(alice)).toString(), '10000000');
        assert.equal((await this.floki.balanceOf(this.burnAddress)).toString(), '500000000000000000000000000000');
        assert.equal((await this.floki.balanceOf(this.floki.address)).toString(), '0');

        await this.floki.transfer(bob, 1234, { from: alice });
        assert.equal((await this.floki.balanceOf(alice)).toString(), '9998766');
        assert.equal((await this.floki.balanceOf(bob)).toString(), '1173');
        assert.equal((await this.floki.balanceOf(this.burnAddress)).toString(), '500000000000000000000000000000');
        assert.equal((await this.floki.balanceOf(this.floki.address)).toString(), '61');
    });

    it('transfer all burn', async () => {
        await this.floki.transferOperator(operator, { from: owner });
        assert.equal((await this.floki.operator()), operator);

        assert.equal((await this.floki.transferTaxRate()).toString(), '500');
        assert.equal((await this.floki.burnRate()).toString(), '20');

        await this.floki.updateBurnRate(100, { from: operator });
        assert.equal((await this.floki.burnRate()).toString(), '100');

        await this.floki.mint(alice, 10000000, { from: owner });
        assert.equal((await this.floki.balanceOf(alice)).toString(), '10000000');
        assert.equal((await this.floki.balanceOf(this.burnAddress)).toString(), '500000000000000000000000000000');
        assert.equal((await this.floki.balanceOf(this.floki.address)).toString(), '0');

        await this.floki.transfer(bob, 1234, { from: alice });
        assert.equal((await this.floki.balanceOf(alice)).toString(), '9998766');
        assert.equal((await this.floki.balanceOf(bob)).toString(), '1173');
        assert.equal((await this.floki.balanceOf(this.burnAddress)).toString(), '500000000000000000000000000061');
        assert.equal((await this.floki.balanceOf(this.floki.address)).toString(), '0');
    });

    it('max transfer amount', async () => {
        assert.equal((await this.floki.maxTransferAmountRate()).toString(), '100');
        assert.equal((await this.floki.maxTransferAmount()).toString(), '0');

        await this.floki.mint(alice, 1000000, { from: owner });
        assert.equal((await this.floki.maxTransferAmount()).toString(), '10000');

        await this.floki.mint(alice, 1000, { from: owner });
        assert.equal((await this.floki.maxTransferAmount()).toString(), '10010');

        await this.floki.transferOperator(operator, { from: owner });
        assert.equal((await this.floki.operator()), operator);

        await this.floki.updateMaxTransferAmountRate(200, { from: operator }); // 2%
        assert.equal((await this.floki.maxTransferAmount()).toString(), '20020');
    });

    it('anti whale', async () => {
        await this.floki.transferOperator(operator, { from: owner });
        assert.equal((await this.floki.operator()), operator);

        assert.equal((await this.floki.isExcludedFromAntiWhale(operator)), false);
        await this.floki.setExcludedFromAntiWhale(operator, true, { from: operator });
        assert.equal((await this.floki.isExcludedFromAntiWhale(operator)), true);
        await this.floki.updateMaxTransferAmountRate(50, { from: operator });

        await this.floki.mint(alice, 10000, { from: owner });
        await this.floki.mint(bob, 10000, { from: owner });
        await this.floki.mint(carol, 10000, { from: owner });
        await this.floki.mint(operator, 10000, { from: owner });
        await this.floki.mint(owner, 10000, { from: owner });

        // total supply: 50,000, max transfer amount: 250
        assert.equal((await this.floki.maxTransferAmount()).toString(), '250');
        await expectRevert(this.floki.transfer(bob, 251, { from: alice }), 'FLOKI::antiWhale: Transfer amount exceeds the maxTransferAmount');
        await this.floki.approve(carol, 251, { from: alice });
        await expectRevert(this.floki.transferFrom(alice, carol, 251, { from: carol }), 'FLOKI::antiWhale: Transfer amount exceeds the maxTransferAmount');

        await this.floki.transfer(bob, 250, { from: alice });
        await this.floki.transferFrom(alice, carol, 249, { from: carol });

        await this.floki.transfer(this.burnAddress, 251, { from: alice });
        await this.floki.transfer(operator, 251, { from: alice });
        await this.floki.transfer(owner, 251, { from: alice });
        await this.floki.transfer(this.floki.address, 251, { from: alice });

        await this.floki.transfer(alice, 251, { from: operator });
        await this.floki.transfer(alice, 251, { from: owner });
        await this.floki.transfer(owner, 251, { from: operator });
    });

    it('update SwapAndLiquifyEnabled', async () => {
        await expectRevert(this.floki.updateSwapAndLiquifyEnabled(true, { from: operator }), 'operator: caller is not the operator');
        assert.equal((await this.floki.swapAndLiquifyEnabled()), false);

        await this.floki.transferOperator(operator, { from: owner });
        assert.equal((await this.floki.operator()), operator);

        await this.floki.updateSwapAndLiquifyEnabled(true, { from: operator });
        assert.equal((await this.floki.swapAndLiquifyEnabled()), true);
    });

    it('update min amount to liquify', async () => {
        await expectRevert(this.floki.updateMinAmountToLiquify(100, { from: operator }), 'operator: caller is not the operator');
        assert.equal((await this.floki.minAmountToLiquify()).toString(), '500000000000000000000');

        await this.floki.transferOperator(operator, { from: owner });
        assert.equal((await this.floki.operator()), operator);

        await this.floki.updateMinAmountToLiquify(100, { from: operator });
        assert.equal((await this.floki.minAmountToLiquify()).toString(), '100');
    });
});
