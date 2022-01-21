const BigNumber = require('bignumber.js');
const truffleAssert = require('truffle-assertions');
const { BN } = require('@openzeppelin/test-helpers');
const ethers = require('ethers');
const {utils} = require("ethers");

//renjs integration
const { Ethereum }  = require("@renproject/chains-ethereum");
const { MockChain, MockProvider }  = require("@renproject/mock-provider");
const RenJS  = require("@renproject/ren");
const {RenVMProvider}  = require("@renproject/rpc/build/main/v2");    

const Adapter = artifacts.require('Basic');
const GatewayFactory = artifacts.require('Stub_GatewayFactory');
const BasicAdapter = artifacts.require('Stub_BasicAdapter');

//curve intergration
const RENERC20 = artifacts.require('Stub_RenERC20');
const ERC20 = artifacts.require('Stub_ERC20');
const CurveSwap = artifacts.require('Stub_CurveFi_Swap');
const CurveLPToken = artifacts.require('Stub_LPToken');
const CurveCRVMinter = artifacts.require('Stub_CurveFi_Minter');
const CurveGauge = artifacts.require('Stub_CurveFi_Gauge');
const MoneyToCurve = artifacts.require('RenBTCtoCurve');

//convex intergration
const Registry = artifacts.require('Stub_addressProvider');
const MainRegistry = artifacts.require('Stub_registry');
const TokenFactory = artifacts.require('Stub_TokenFactory');
const VoterProxy = artifacts.require('Stub_CurveVoterProxy');
const Booster = artifacts.require('Stub_Booster');
const DepositToken = artifacts.require('Stub_DepositToken');

//abracadabra integration
const MIM = artifacts.require('Stub_MagicInternetMoney');
const BenToBox =  artifacts.require('Stub_bentoBox');
const Cauldron =  artifacts.require('Stub_CauldronV2CheckpointV1');

const supplies = {
    wbtc : new BN('0'),
};

const deposits  = {
    wbtc:  new BN('0'), 
}

contract('Witnessing the transition of BTC to MIM and vice versa', async accounts => {
    //renjs integration
    let adapter;
    let gatewayFactory;
    let gatewayRegistryAddress;
    let basicAdapter;
    let Bitcoin;
    let renJS;
    let network;
    let user;
    
    //curve intergration
    let renBTC_userA;
    let renBTC_userB;
    let renBTCAddress;
    let renBtc;
    let wBtc;
    let _wBtc;
    let curveLPToken;
    let curveSwap;
    let crvToken;
    let curveMinter;
    let curveGauge;
    let moneyToCurve;
    
    //convex intergration
    let registry;
    let mainRegistry;
    let tokenFactory;
    let voterProxy;
    let booster;
    let depositToken;
    //abracadabra integration
    let mim;
    let benToBox;
    let cauldron;
    let mimCollateral;

    const tempBTCadd = '183Y3PKMjkmH4vLTzZwpkVAxp45RTuz9rZ';
     
    before(async () =>{
        //owner: accounts[0]
        //defi owner: accounts[1]
        //user 1: accounts[2]
        //user 2: accounts[3]

        const mockRenVMProvider = new MockProvider();

        // Set up mock Bitcoin chain.
        Bitcoin = new MockChain("BTC");
        mockRenVMProvider.registerChain(Bitcoin);
        mockRenVMProvider.registerAsset(Bitcoin.asset);

        // Get mint authority from mock provider.
        const mintAuthority =  mockRenVMProvider.mintAuthority();
        gatewayFactory = await GatewayFactory.new(mintAuthority, "Ethereum", {from: accounts[0]});
        gatewayRegistryAddress = await gatewayFactory.registry(); 

        await gatewayFactory.addToken("Bitcoin", "BTC", 8);

        // Deploy BasicAdapter.
        basicAdapter = await BasicAdapter.new(gatewayRegistryAddress,{from: accounts[0]});
        network = LocalEthereumNetwork(1337,gatewayRegistryAddress,basicAdapter.address);

        renJS = new RenJS(new RenVMProvider(network, mockRenVMProvider));
        adapter  = await Adapter.new(gatewayRegistryAddress, {from: accounts[0]});
        renBTCAddress = await adapter.getRenERC20();

        const provider = await ethers.getDefaultProvider('http://localhost:8545');
        user = await provider.getSigner();

        renBtc = await RENERC20.at(renBTCAddress,{from: accounts[0]});
        _wBtc = await ERC20.new({from: accounts[0]});
        await _wBtc.initialize('wBTC','wBTC',18);
        wBtc = await RENERC20.new({from: accounts[0]});
        await wBtc.initialize(_wBtc.address,'ren_wBTC',18,supplies.wbtc);

        curveLPToken = await CurveLPToken.deployed();
        await curveLPToken.initialize();

        curveSwap = await CurveSwap.deployed();
        await curveSwap.initialize([renBtc.address,wBtc.address],curveLPToken.address,10,{from: accounts[0]});
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
        depositToken = await DepositToken.at(mimCollateral, {from: accounts[0]});
        console.log("mimCollateral: "+ mimCollateral);
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

        //console.log(initData);
        //await cauldron.init(initData,{value: 0});
        //await cauldron.registeringProtocol();
        console.log("cauldron address: "+ cauldron.address);
      

        //Main contract
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
                                 initData,0,{from:accounts[1]});

        var xx = await benToBox.masterContractOf(cauldron.address);
        console.log("xx: "+ xx);
        //preliminary balances 1000000000
        await wBtc.transfer(accounts[2], deposits.wbtc, {from: accounts[0]});
        await wBtc.transfer(accounts[3], deposits.wbtc, {from: accounts[0]});
        
    });

    it('Checking the minting of renBTC from BTC for User 1', async () => {
        const decimals = Bitcoin.assetDecimals(Bitcoin.asset);
        const btcAmount = new BigNumber(Math.random()).decimalPlaces(decimals);
        const nonce = utils.keccak256(Buffer.from("1"));

        // Shift the amount by the asset's decimals (8 for BTC).
        const satsAmount = new BigNumber(btcAmount).times(new BigNumber(10).exponentiatedBy(decimals));

        const fixedFee = 1000; // sats
        const percentFee = 15; // BIPS

        const mint = await renJS.lockAndMint({
            asset: "BTC",
            from: Bitcoin,
            to: Ethereum({provider: user.provider, signer: user},network).Contract({
            sendTo: adapter.address,
            contractFn: "temporaryMint",
            contractParams: [
              {
                name: "to",
                type: "address",
                value: accounts[2],
              },
              {
                name: "nonce",
                type: "bytes32",
                value: nonce,
              }
            ],
            }),
        });

        // Mock deposit. Currently must be passed in as a number.
        Bitcoin.addUTXO(mint.gatewayAddress, satsAmount.toNumber());
        
        const balanceBefore = await adapter.userBalance(accounts[2]);
    
        await new Promise((resolve, reject) => {
            mint.on("deposit", async deposit => {
              try {
                await deposit.confirmed();
                await deposit.signed();
                //await deposit.mint();
                const tx = await deposit.queryTx();
                if (tx.out && !tx.out.revert) {
                  await adapter.temporaryMint(accounts[2], nonce, 'BTC', new BigNumber(tx.out.amount.toString()), tx.out.nhash, tx.out.signature);
                } else {
                  throw new Error('revert was present on the out');
                }
                resolve();
              } catch (error) {
                console.error(error);
                reject(error);
              }
            });
        });

        renBTC_userA = await adapter.userBalance(accounts[2]);
        const expected = satsAmount.minus(fixedFee).times(1 - percentFee / 10000).integerValue(BigNumber.ROUND_UP);
        assert((renBTC_userA - balanceBefore).toString() == expected.toString(),'Problem with minting of renBTC');
    });

    it('Deposit the money into Defi for User 1', async () =>{

        await renBtc.approve(moneyToCurve.address, renBTC_userA, {from: accounts[2]});
        await wBtc.approve(moneyToCurve.address,deposits.wbtc, {from:accounts[2]});
        await truffleAssert.passes(moneyToCurve.multiStepDeposit([renBTC_userA,deposits.wbtc], {from:accounts[2]}));
      });
    
    it('Curve.Fi LP-tokens of User 1 are staked in Gauge', async () =>{
      let swaprenBTC = await renBtc.balanceOf(curveSwap.address);
      let swapwBTC = await wBtc.balanceOf(curveSwap.address);

      let lptokens = (swaprenBTC.toNumber() * 10000000000) + swapwBTC.toNumber();
      let stakedTokens  = await moneyToCurve.curveLPTokenStaked();
      assert(lptokens.toString() == stakedTokens.toString(),'CurveFi: problem with the staking');
    });

    it('Lending cvxrencrv to borrow MIM using abracadabra', async ()=> {
      await mim.mintToBentoBox(cauldron.address, new BigNumber(100000 * 10 ** 18), benToBox.address);
      console.log(accounts[2]);
      
      var cvxrencrvBalance = await depositToken.balanceOf(moneyToCurve.address);
      console.log("cvxrencrvBalance: "+ cvxrencrvBalance);
      
      //1 MIM = 1 USD
      //1 cvxrencrv = 42304.3455 MIM
      // Borrow balance for 25% collateralization ratio
      var mim_borrow = web3.utils.fromWei(cvxrencrvBalance.toString(),'ether') * 42304.3455 * 0.25;
      console.log(mim_borrow);
      //ACTION_BENTO_SETAPPROVAL
      var data_0 = ethers.utils.defaultAbiCoder.encode( ["address","address", "bool"],[moneyToCurve.address, cauldron.address, true]);
      //ACTION_BORROW
      console.log("moneyToCurve: "+ moneyToCurve.address);
      console.log("MIM address: "+ mim.address);

      var data_1 = ethers.utils.defaultAbiCoder.encode(["int256","address"],[web3.utils.toWei(mim_borrow.toString(),'ether'), moneyToCurve.address]);
      
      //ACTION_BENTO_WITHDRAW
      var data_2 = ethers.utils.defaultAbiCoder.encode(["address","address","int256","int256"],[mim.address, moneyToCurve.address,web3.utils.toWei(mim_borrow.toString(),'ether'),0]);
      
      //ACTION_BENTO_DEPOSIT
      var data_3 = ethers.utils.defaultAbiCoder.encode(["address","address","int256","int256"],[mimCollateral, moneyToCurve.address,(cvxrencrvBalance).toString(),0]);
      
      //ACTION_ADD_COLLATERAL
      var data_4 = ethers.utils.defaultAbiCoder.encode(["int256","address","bool"],[1,moneyToCurve.address,false]);
      
      await moneyToCurve.cookCalling([24,5,21,20,10],[0,0,0,0,0],[data_0,data_1,data_2,data_3,data_4], {value: 0, from: accounts[2]});
      
      var mimBalance = await mim.balanceOf(moneyToCurve.address);
      console.log("mimBalance: "+ mimBalance);
      var cvx = await depositToken.balanceOf(moneyToCurve.address);
      console.log("mimBalance: "+ cvx);
      
    });

    it('Repaying MIM to get back cvxrencrv', async () => {

    });
    
    // it('Checking the minting of renBTC from BTC for User 2', async () => {
    //     const decimals = Bitcoin.assetDecimals(Bitcoin.asset);
    //     const btcAmount = new BigNumber(Math.random()).decimalPlaces(decimals);
    //     const nonce = utils.keccak256(Buffer.from("1"));

    //     // Shift the amount by the asset's decimals (8 for BTC).
    //     const satsAmount = new BigNumber(btcAmount).times(new BigNumber(10).exponentiatedBy(decimals));
    //     const fixedFee = 1000; // sats
    //     const percentFee = 15; // BIPS

    //     const mint = await renJS.lockAndMint({
    //         asset: "BTC",
    //         from: Bitcoin,
    //         to: Ethereum({provider: user.provider, signer: user},network).Contract({
    //         sendTo: adapter.address,
    //         contractFn: "temporaryMint",
    //         contractParams: [
    //           {
    //             name: "to",
    //             type: "address",
    //             value: accounts[3],
    //           },
    //           {
    //             name: "nonce",
    //             type: "bytes32",
    //             value: nonce,
    //           }
    //         ],
    //         }),
    //     });

    //     // Mock deposit. Currently must be passed in as a number.
    //     Bitcoin.addUTXO(mint.gatewayAddress, satsAmount.toNumber());
        
    //     const balanceBefore = await adapter.userBalance(accounts[3]);

    //     await new Promise((resolve, reject) => {
    //         mint.on("deposit", async deposit => {
    //           try {
    //             await deposit.confirmed();
    //             await deposit.signed();
    //             //await deposit.mint();
    //             const tx = await deposit.queryTx()
    //             if (tx.out && !tx.out.revert) {
    //               await adapter.temporaryMint(accounts[3], nonce, 'BTC', new BigNumber(tx.out.amount.toString()), tx.out.nhash, tx.out.signature)
    //             } else {
    //               throw new Error('revert was present on the out')
    //             }
    //             resolve();
    //           } catch (error) {
    //             console.error(error);
    //             reject(error);
    //           }
    //         });
    //     });

    //     renBTC_userB = await adapter.userBalance(accounts[3]);
    //     const expected = satsAmount.minus(fixedFee).times(1 - percentFee / 10000).integerValue(BigNumber.ROUND_UP);
    //     assert((renBTC_userB - balanceBefore).toString() == expected.toString(),'Problem with minting of renBTC');
    // });

    // it('Deposit the money into Defi for User 2', async () =>{
    //     await renBtc.approve(moneyToCurve.address, renBTC_userB, {from: accounts[3]});
    //     await wBtc.approve(moneyToCurve.address,deposits.wbtc, {from:accounts[3]});
    //     await truffleAssert.passes(moneyToCurve.multiStepDeposit([renBTC_userB,deposits.wbtc], {from:accounts[3]}));
    // });

    // it('Withdraw money from curve.fi by user 1', async () =>{
    //   await truffleAssert.passes(moneyToCurve.multiStepWithdraw([renBTC_userA,0],{from:accounts[2]}));
    // });

    // it('should be able to burn the minted tokens for user 1', async () =>{
    //   const amount = renBTC_userA / 10 ** 8;
    //   await renBtc.approve(adapter.address, renBTC_userA,{from: accounts[2]})
    //   const burnAndRelease = await renJS.burnAndRelease({
    //     asset: "BTC",
    //     to: Bitcoin.Address(tempBTCadd),
    //     from: Ethereum({provider: user.provider, signer: user},network).Contract((btcAddress) => ({
    //       sendTo: adapter.address,
    //       contractFn: "temporaryBurn",
    //       contractParams: [
    //       {
    //         type: "bytes",
    //         name: "_msg",
    //         value: Buffer.from(`Withdrawing ${amount} BTC`),
    //       },
    //       {
    //         type: "bytes",
    //         name: "_to",
    //         value: btcAddress,
    //       },
    //       {
    //         type: "uint256",
    //         name: "_amount",
    //         value: renJS.utils.toSmallestUnit(amount, 8),
    //       },
    //       {
    //         type: 'address',
    //         name: 'from',
    //         value: accounts[2]
    //       }
    //       ],
    //     }))
    //    });
       
    //    await burnAndRelease.burn();
    //    await burnAndRelease.release();
      
    // });   
});

const LocalEthereumNetwork = (networkID, gatewayRegistryAddress, basicAdapterAddress) =>({
    name: "dev",
    chain: "dev",
    chainLabel: "dev",
    isTestnet: false,
    networkID,
    infura: "",
    publicProvider: () => "",
    explorer: {
    address: () => "",
    transaction: () => "",
    },
    etherscan: "",
    addresses: {
    GatewayRegistry: gatewayRegistryAddress,
    BasicAdapter: basicAdapterAddress,
    },
});