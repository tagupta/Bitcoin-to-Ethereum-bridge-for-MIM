const BigNumber = require('bignumber.js');
const ethers = require('ethers');

const CurveSwap = artifacts.require('Stub_CurveFi_Swap');
const CurveLPToken = artifacts.require('Stub_LPToken');
const CurveGauge = artifacts.require('Stub_CurveFi_Gauge');
const CurveCRVMinter = artifacts.require('Stub_CurveFi_Minter');

const Booster = artifacts.require('Stub_Booster');
const VoterProxy = artifacts.require('Stub_CurveVoterProxy');

const MIM = artifacts.require('Stub_MagicInternetMoney');
const BenToBox =  artifacts.require('Stub_bentoBox');
const Cauldron =  artifacts.require('Stub_CauldronV2CheckpointV1');
const DepositToken = artifacts.require('Stub_DepositToken');
const MoneyToCurve = artifacts.require('MainContract');


module.exports = async function (deployer) {
    let booster;
    let mim;
    let benToBox;
    let cauldron;
    let mimCollateral;
    let depositToken;
    let moneyToCurve;
    
    booster = await Booster.deployed();
    mim = await MIM.deployed();
    benToBox = await BenToBox.deployed();
    cauldron = await Cauldron.deployed();
    var _pool = await booster.poolInfo(0);
    mimCollateral = _pool.token;
    depositToken = await DepositToken.at(mimCollateral);
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

    moneyToCurve = await MoneyToCurve.deployed();
    await moneyToCurve.initialize();
    await moneyToCurve.setup(CurveSwap.address, 
                             CurveGauge.address, 
                             CurveCRVMinter.address, 
                             CurveLPToken.address,
                             Booster.address,
                             VoterProxy.address, 
                             Cauldron.address,
                             BenToBox.address,
                             MIM.address,
                             initData);
    await mim.mintToBentoBox(Cauldron.address, new BigNumber(1000000000000000 * 10 ** 18), BenToBox.address);
};