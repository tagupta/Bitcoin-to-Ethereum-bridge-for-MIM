const { BN } = require('@openzeppelin/test-helpers');
const truffleAssert = require('truffle-assertions');
const ethers = require('ethers');

const RENERC20 = artifacts.require('Stub_RenERC20');
const ERC20 = artifacts.require('Stub_ERC20');

const CurveSwap = artifacts.require('Stub_CurveFi_Swap');
const CurveLPToken = artifacts.require('Stub_LPToken');
const CurveCRVMinter = artifacts.require('Stub_CurveFi_Minter');
const CurveGauge = artifacts.require('Stub_CurveFi_Gauge');

const Registry = artifacts.require('Stub_addressProvider');
const MainRegistry = artifacts.require('Stub_registry');
const TokenFactory = artifacts.require('Stub_TokenFactory');
const VoterProxy = artifacts.require('Stub_CurveVoterProxy');
const Booster = artifacts.require('Stub_Booster');

const MoneyToCurve = artifacts.require('MainContract');

//abracadabra integration
const MIM = artifacts.require('Stub_MagicInternetMoney');
const BenToBox =  artifacts.require('Stub_bentoBox');
const Cauldron =  artifacts.require('Stub_CauldronV2CheckpointV1');

const supplies = {
    renbtc : new BN('1000000000000000000000000'),
    wbtc : new BN('0')
};

const deposits  = {
    renbtc: new BN('10000000000'), 
    wbtc: new BN('0'), 
}

contract('Witnessing the transition of renBTC to cvxrencrv', async accounts =>{
    // accounts[0] : owner
    // accounts[1] : defiowner
    // accounts[2] : user 1
    // accounts[3] : user 2

    let renBtc;
    let wBtc;
    let _renBtc;
    let _wBtc;

    let curveLPToken;
    let curveSwap;
    let crvToken;
    let curveMinter;
    let curveGauge;
    let moneyToCurve;

    let registry;
    let mainRegistry;
    let tokenFactory;
    let voterProxy;
    let booster;
    //abracadabra integration
    let mim;
    let benToBox;
    let cauldron;
    let mimCollateral;

    before(async() =>{
        _renBtc = await ERC20.new({from: accounts[0]});
        await _renBtc.initialize('renBTC','renBTC',18);

        _wBtc = await ERC20.new({from: accounts[0]});
        await _wBtc.initialize('wBTC','wBTC',18);

        renBtc = await RENERC20.new({from: accounts[0]});
        await renBtc.initialize(_renBtc.address,'ren_RENBTC',18,supplies.renbtc);

        wBtc = await RENERC20.new({from: accounts[0]});
        await wBtc.initialize(_wBtc.address,'ren_wBTC',18,supplies.wbtc);

        curveLPToken = await CurveLPToken.deployed();
        await curveLPToken.initialize();

        curveSwap = await CurveSwap.deployed();
        await curveSwap.initialize([renBtc.address,wBtc.address],curveLPToken.address,10,{from: accounts[0]}); //address[N_COINS] memory _coins, address _pool_token, uint256 _fee
        await curveLPToken.addMinter(curveSwap.address, {from:accounts[0]});

        crvToken = await ERC20.new({from: accounts[0]});
        await crvToken.initialize('CRV','CRV',18);

        curveMinter = await CurveCRVMinter.deployed();
        await curveMinter.initialize(crvToken.address, {from: accounts[0]});
        await crvToken.addMinter(curveMinter.address, { from: accounts[0]});

        curveGauge = await CurveGauge.deployed();
        await curveGauge.initialize(curveLPToken.address, curveMinter.address,{from: accounts[0]});
        await crvToken.addMinter(curveGauge.address, {from: accounts[0]});
        
        booster = await Booster.deployed();

        registry = await Registry.deployed();
        await registry.initialize(accounts[0]);

        mainRegistry = await MainRegistry.deployed();
        await mainRegistry.initialize(registry.address);
        await mainRegistry.add_pool(curveSwap.address,2,curveLPToken.address,web3.utils.fromUtf8("Rate"),8,8,true,true,'ren');
        await mainRegistry.set_liquidity_gauges(curveSwap.address,[curveGauge.address,
                                                                  '0x0000000000000000000000000000000000000000',
                                                                  '0x0000000000000000000000000000000000000000',
                                                                  '0x0000000000000000000000000000000000000000',
                                                                  '0x0000000000000000000000000000000000000000',
                                                                  '0x0000000000000000000000000000000000000000',
                                                                  '0x0000000000000000000000000000000000000000',
                                                                  '0x0000000000000000000000000000000000000000',
                                                                  '0x0000000000000000000000000000000000000000',
                                                                  '0x0000000000000000000000000000000000000000']);
        await registry.set_address(0,mainRegistry.address);

        tokenFactory = await TokenFactory.deployed();
        await tokenFactory.initialize(booster.address);

        voterProxy = await VoterProxy.deployed();
        await voterProxy.initialize();
        await voterProxy.setOperator(booster.address);
        
        await booster.initialize(voterProxy.address, registry.address); 
        await booster.setFactories(tokenFactory.address);
        await booster.addPool(curveSwap.address, curveGauge.address, 1);
        
        //abracadabra contracts
        mim = await MIM.deployed();
        benToBox = await BenToBox.deployed();
        cauldron = await Cauldron.deployed();
        var _pool = await booster.poolInfo(0);
        mimCollateral = _pool.token;
        const INTEREST_CONVERSION = 1e18 / (365.25 * 3600 * 24) / 100;
        const OPENING_CONVERSION = 1e5 / 100;

        // 75% LTV .5% initial 0.5% Interest
        const collateralization = 75 * 1e3; // 75% LTV
        const opening = 0.5 * OPENING_CONVERSION; // .5% initial
        const interest = parseInt(String(0.5 * INTEREST_CONVERSION)); // 0.5% Interest
        const liquidation = 12.5 * 1e3 + 1e5;

        let initData = ethers.utils.defaultAbiCoder.encode(
          ["address","uint64", "uint256", "uint256", "uint256"],
          [mimCollateral, interest, liquidation, collateralization, opening]
        );
      
        // Main contract
        moneyToCurve = await MoneyToCurve.deployed();
        await moneyToCurve.initialize({from:accounts[1]});
        await moneyToCurve.setup(curveSwap.address, 
                                 curveGauge.address, 
                                 curveMinter.address,
                                 curveLPToken.address,
                                 booster.address,
                                 voterProxy.address,
                                 cauldron.address,
                                 benToBox.address,
                                 mim.address,
                                 initData,{from:accounts[1]});

        //preliminary balances
        await renBtc.transfer(accounts[2], new BN('20000000000'),{from: accounts[0]});
        await wBtc.transfer(accounts[2], new BN('0'), {from: accounts[0]});

        await renBtc.transfer(accounts[3], new BN('10000000000'), {from: accounts[0]});
        await wBtc.transfer(accounts[3], new BN('0'), {from: accounts[0]});

    });

    it('Deposit the money into the Defi', async () => {
        await renBtc.approve(moneyToCurve.address, deposits.renbtc, {from:accounts[2]});
        await wBtc.approve(moneyToCurve.address,deposits.wbtc,{from:accounts[2]});
        await truffleAssert.passes(moneyToCurve.multiStepDeposit([deposits.renbtc,deposits.wbtc], {from:accounts[2]}));
    });
    
    it('Renpool tokens are deposited to curve.fi swap', async () => {
      let swaprenBTC = await renBtc.balanceOf(curveSwap.address);
      let depositrenBTC = deposits.renbtc;
      let swapwBTC = await wBtc.balanceOf(curveSwap.address);
      let depositwBTC = deposits.wbtc;

      assert(swaprenBTC.toString() == depositrenBTC.toString(),'RenBTC not deposited in curve.Fi swap');
      assert(swapwBTC.toString() == depositwBTC.toString(),'wBTC not deposited in curve.Fi swap');
    });

    it('Curve.Fi LP-tokens are staked in Gauge', async () =>{
        let lptokens = deposits.renbtc.add(deposits.wbtc); 
        let stakedTokens =  await moneyToCurve.curveLPTokenStaked()
        assert(lptokens.toString() == stakedTokens.toString(), 'Staking failed');
    });

    it('Additional Deposit to create extra liquidity from user 2', async () =>{
        await renBtc.approve(moneyToCurve.address, deposits.renbtc, {from:accounts[3]});
        await wBtc.approve(moneyToCurve.address,deposits.wbtc, {from:accounts[3]});
        await truffleAssert.passes(moneyToCurve.multiStepDeposit([deposits.renbtc,0], {from:accounts[3]}));
    });

    it('Additional Deposit to create extra liquidity from user 1', async () =>{
        await renBtc.approve(moneyToCurve.address, deposits.renbtc, {from:accounts[2]});
        await wBtc.approve(moneyToCurve.address, deposits.wbtc, {from:accounts[2]});
        await truffleAssert.passes(moneyToCurve.multiStepDeposit([deposits.renbtc,0], {from:accounts[2]}));
    });

    it('Withdraw money by user 1', async () =>{
       await truffleAssert.passes(moneyToCurve.multiStepWithdraw([deposits.renbtc,0],{from:accounts[2]}));
    });
})