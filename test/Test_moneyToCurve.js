const { BN } = require('@openzeppelin/test-helpers');
const truffleAssert = require('truffle-assertions');

const ERC20 = artifacts.require('Stub_ERC20');
const RENBTC = artifacts.require('Stub_RenBTC');
const WBTC = artifacts.require('Stub_WBTC');
const RENERC20 = artifacts.require('Stub_RenERC20');
const CRVToken = artifacts.require('Stub_CRVToken');

const CurveSwap = artifacts.require('Stub_CurveFi_Swap');
const CurveLPToken = artifacts.require('Stub_LPToken');
const CurveCRVMinter = artifacts.require('Stub_CurveFi_Minter');
const CurveGauge = artifacts.require('Stub_CurveFi_Gauge');

const MoneyToCurve = artifacts.require('RenBTCtoCurve');

const supplies = {
    renbtc : new BN('1000000000000000000000000'),
    wbtc : new BN('1000000000000')
};

const deposits  = {
    renbtc: new BN('100000000000000000000'), 
    wbtc: new BN('200000000'), 
}

contract('Integrate Curve.fi into the Defi', async accounts =>{
    // accounts[0] : owner
    // accounts[1] : defiowner
    // accounts[2] : user 1
    // accounts[3] : user 2

    let renBtc;
    let wBtc;

    let curveLPToken;
    let curveSwap;

    let crvToken;
    let curveMinter;
    let curveGauge;

    let moneyToCurve;

    before(async() =>{
        renBtc = await RENBTC.deployed();
        renBtc.mint(accounts[0], supplies.renbtc,{from: accounts[0]});
        
        wBtc = await WBTC.deployed();
        wBtc.mint(accounts[0], supplies.wbtc, {from: accounts[0]});
        curveLPToken = await CurveLPToken.deployed();

        curveSwap = await CurveSwap.deployed();
        await curveSwap.initialize([renBtc.address,wBtc.address],curveLPToken.address,10,{from: accounts[0]}); //address[N_COINS] memory _coins, address _pool_token, uint256 _fee
        
        crvToken = await CRVToken.deployed();

        curveMinter = await CurveCRVMinter.deployed();
        await curveMinter.initialize(crvToken.address, {from: accounts[0]});
        
        curveGauge = await CurveGauge.deployed();
        await curveGauge.initialize(curveLPToken.address, curveMinter.address,{from: accounts[0]});

        //Main contract
        moneyToCurve = await MoneyToCurve.deployed();
        await moneyToCurve.setup(curveSwap.address, curveGauge.address, curveMinter.address,curveLPToken.address, {from:accounts[1]});

        //preliminary balances
        await renBtc.transfer(accounts[2], new BN('1000000000000000000000'),{from: accounts[0]});
        await wBtc.transfer(accounts[2], new BN('1000000000'), {from: accounts[0]});

        await renBtc.transfer(accounts[3], new BN('1000000000000000000000'), {from: accounts[0]});
        await wBtc.transfer(accounts[3], new BN('1000000000'), {from: accounts[0]});

    });

   
    it('Deposit the money into the Defi', async () => {

        await renBtc.approve(moneyToCurve.address, deposits.renbtc, {from:accounts[2]});
        await wBtc.approve(moneyToCurve.address, deposits.wbtc, {from:accounts[2]});

        let renbtcBefore = await renBtc.balanceOf(accounts[2]);
        let wbtcBefore = await wBtc.balanceOf(accounts[2]);

        console.log("RenBTC before " + renbtcBefore);
        console.log("WBTC before " + wbtcBefore);

        await moneyToCurve.multiStepDeposit([deposits.renbtc, deposits.wbtc], {from:accounts[2]});

        let renbtcAfter = await renBtc.balanceOf(accounts[2]);
        let wbtcAfter = await wBtc.balanceOf(accounts[2]);

        console.log("RenBTC after " + renbtcAfter);
        console.log("WBTC after " + wbtcAfter);

        assert((renbtcBefore - renbtcAfter).toString() == (deposits.renbtc).toString(), 'Assert failed');
    })
    


})