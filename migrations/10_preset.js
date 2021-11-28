const { BN } = require('@openzeppelin/test-helpers');
const Basic = artifacts.require("Basic");
const RENERC20 = artifacts.require('Stub_RenERC20');
const ERC20 = artifacts.require('Stub_ERC20');
const CurveSwap = artifacts.require('Stub_CurveFi_Swap');
const CurveLPToken = artifacts.require('Stub_LPToken');
const CurveCRVMinter = artifacts.require('Stub_CurveFi_Minter');
const CurveGauge = artifacts.require('Stub_CurveFi_Gauge');
const MoneyToCurve = artifacts.require('RenBTCtoCurve');
module.exports = async (deployer, network, accounts) => {
    let curveSwap;
    let crvToken;
    let curveMinter;
    let curveGauge;
    let moneyToCurve;

    const supplies = {
        wbtc : new BN('1000000000000000000000000') //1000000000000
    };
    
    const deposits  = {
        wbtc: new BN('100000000000000000000'), //200000000
    }

    let adapter = await Basic.deployed();
    let renBTCAddress = await adapter.getRenERC20();

    let renBtc = await RENERC20.at(renBTCAddress);

    let _wBtc = await ERC20.new();
    await _wBtc.initialize('wBTC','wBTC',18);
    let wBtc = await RENERC20.new();
    console.log("wBtc: "+ wBtc.address);
    await wBtc.initialize(_wBtc.address,'ren_wBTC',18,supplies.wbtc);

    let curveLPToken = await CurveLPToken.deployed();
    await curveLPToken.initialize();

    curveSwap = await CurveSwap.deployed();
    await curveSwap.initialize([renBtc.address,wBtc.address],CurveLPToken.address,10);
    await curveLPToken.addMinter(CurveSwap.address);

    crvToken = await ERC20.new();
    console.log("crvToken: "+ crvToken.address);
    await crvToken.initialize('CRV','CRV',18);

    curveMinter = await CurveCRVMinter.deployed();
    await curveMinter.initialize(crvToken.address);
    await crvToken.addMinter(CurveCRVMinter.address);

    curveGauge = await CurveGauge.deployed();
    await curveGauge.initialize(CurveLPToken.address, CurveCRVMinter.address);
    await crvToken.addMinter(CurveGauge.address);

    moneyToCurve = await MoneyToCurve.deployed();
    await moneyToCurve.initialize();
    await moneyToCurve.setup(CurveSwap.address, CurveGauge.address, CurveCRVMinter.address, CurveLPToken.address);
    
    //await wBtc.approve(MoneyToCurve.address,deposits.wbtc,{from:'0x0b18bAc131e159Dd678387287536900eb7cAFd16'});

}
