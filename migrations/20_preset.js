const CurveSwap = artifacts.require('Stub_CurveFi_Swap');
const CurveLPToken = artifacts.require('Stub_LPToken');
const CurveGauge = artifacts.require('Stub_CurveFi_Gauge');

const Registry = artifacts.require('Stub_addressProvider');
const MainRegistry = artifacts.require('Stub_registry');
const TokenFactory = artifacts.require('Stub_TokenFactory');
const VoterProxy = artifacts.require('Stub_CurveVoterProxy');
const Booster = artifacts.require('Stub_Booster');


module.exports = async function (deployer) {
    
    let registry;
    let mainRegistry;
    let tokenFactory;
    let voterProxy;
    let booster;

    booster = await Booster.deployed();
    registry = await Registry.deployed();
    await registry.initialize("0x9C87885Dfe734F274Da768EC985768C483BB89fa");

    mainRegistry = await MainRegistry.deployed();
    await mainRegistry.initialize(Registry.address);
    await mainRegistry.add_pool(CurveSwap.address,2,CurveLPToken.address,web3.utils.fromUtf8("Rate"),8,8,true,true,'ren');
    await mainRegistry.set_liquidity_gauges(CurveSwap.address,[CurveGauge.address,
                                                               '0x0000000000000000000000000000000000000000',
                                                               '0x0000000000000000000000000000000000000000',
                                                               '0x0000000000000000000000000000000000000000',
                                                               '0x0000000000000000000000000000000000000000',
                                                               '0x0000000000000000000000000000000000000000',
                                                               '0x0000000000000000000000000000000000000000',
                                                               '0x0000000000000000000000000000000000000000',
                                                               '0x0000000000000000000000000000000000000000',
                                                               '0x0000000000000000000000000000000000000000']);
    await registry.set_address(0,MainRegistry.address);

    tokenFactory = await TokenFactory.deployed();
    await tokenFactory.initialize(Booster.address);

    voterProxy = await VoterProxy.deployed();
    await voterProxy.initialize();
    await voterProxy.setOperator(Booster.address);

    await booster.initialize(VoterProxy.address, Registry.address); 
    await booster.setFactories(TokenFactory.address);
    await booster.addPool(CurveSwap.address, CurveGauge.address, 1);
};
  