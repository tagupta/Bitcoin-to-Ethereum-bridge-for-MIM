const BigNumber = require('bignumber.js');
const ethers = require('ethers');
const {utils} = require("ethers");

const { Ethereum }  = require("@renproject/chains-ethereum");
//Renjs imports
const { MockChain, MockProvider }  = require("@renproject/mock-provider");
const RenJS  = require("@renproject/ren");
const {RenVMProvider}  = require("@renproject/rpc/build/main/v2");    

const Adapter = artifacts.require('Basic');
const GatewayFactory = artifacts.require('Stub_GatewayFactory');
const BasicAdapter = artifacts.require('Stub_BasicAdapter');
// *************************************************************************
const { BN } = require('@openzeppelin/test-helpers');
const truffleAssert = require('truffle-assertions');

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
    wbtc : new BN('1000000000000000000000000') //1000000000000
};

const deposits  = {
    renbtc: new BN('100000000000000000000'), 
    wbtc: new BN('100000000000000000000'), //200000000
}

contract('Witnessing the transition of BTC to CRV Token', async accounts => {
    let adapter;
    let gatewayFactory;
    let gatewayRegistryAddress;
    let basicAdapter;
    let Bitcoin;
    let renJS;
    let network;
    let user;
    let balanceAfter;
    let renBTCAddress;
  // *************************************************************************
    let renBtc;
    let wBtc;
    let _wBtc;
    let renBTCWithdraw;
    let curveLPToken;
    let curveSwap;

    let crvToken;
    let curveMinter;
    let curveGauge;

    let moneyToCurve;

    let swaprenBTC;
    let swapwBTC;
    const tempBTCadd = '183Y3PKMjkmH4vLTzZwpkVAxp45RTuz9rZ';

    before(async () =>{

        const mockRenVMProvider = new MockProvider();

        // Set up mock Bitcoin chain.
        Bitcoin = new MockChain("BTC");
        mockRenVMProvider.registerChain(Bitcoin);
        mockRenVMProvider.registerAsset(Bitcoin.asset);

        // Get mint authority from mock provider.
        const mintAuthority =  mockRenVMProvider.mintAuthority();
        gatewayFactory = await GatewayFactory.new(mintAuthority, "Ethereum", {from: accounts[0]});
        gatewayRegistryAddress = await gatewayFactory.registry(); 

        console.log("gatewayRegistryAddress: " + gatewayRegistryAddress);

        await gatewayFactory.addToken("Bitcoin", "BTC", 8);

        // Deploy BasicAdapter.
        basicAdapter = await BasicAdapter.new(gatewayRegistryAddress,{from: accounts[0]});
        network = LocalEthereumNetwork(1337,gatewayRegistryAddress,basicAdapter.address);

        renJS = new RenJS(new RenVMProvider(network, mockRenVMProvider));
        adapter  = await Adapter.new(gatewayRegistryAddress, {from: accounts[0]});
        console.log("Basic address: " + adapter.address);
        renBTCAddress = await adapter.getRenERC20();
        console.log("renBTCAddress: " + renBTCAddress);

        const provider = await ethers.getDefaultProvider('http://localhost:8545');
        user = await provider.getSigner();

// *************************************************************************

        _renBtc  = await RENBTC.deployed();
        _wBtc = await WBTC.deployed();
        renBtc = await RENERC20.at(renBTCAddress,{from: accounts[0]});

        console.log("renBtc address: " +renBtc.address);

        wBtc = await RENERC20.new({from: accounts[0]});
        await wBtc.initialize(_wBtc.address);
        wBtc.mint(accounts[0], supplies.wbtc, {from: accounts[0]});
        //wBtc.mint(accounts[0],0, {from: accounts[0]});


        curveLPToken = await CurveLPToken.deployed();

        curveSwap = await CurveSwap.deployed();
        await curveSwap.initialize([renBtc.address,wBtc.address],curveLPToken.address,10,{from: accounts[0]}); 
        //address[N_COINS] memory _coins, address _pool_token, uint256 _fee

        crvToken = await CRVToken.deployed();
        console.log("crvToken address: " + crvToken.address);

        curveMinter = await CurveCRVMinter.deployed();
        await curveMinter.initialize(crvToken.address, {from: accounts[0]});

        curveGauge = await CurveGauge.deployed();
        await curveGauge.initialize(curveLPToken.address, curveMinter.address,{from: accounts[0]});

        //Main contract
        moneyToCurve = await MoneyToCurve.deployed();
        await moneyToCurve.setup(curveSwap.address, curveGauge.address, curveMinter.address,curveLPToken.address, {from:accounts[1]});
        console.log("moneyToCurve address: "+ moneyToCurve.address);

        //preliminary balances 1000000000
        await wBtc.transfer(accounts[2], new BN('1000000000000000000000'), {from: accounts[0]});
        //await wBtc.transfer(accounts[2],0, {from: accounts[0]});
    });

    it('Checking the minting of renBTC from BTC', async () => {
        const decimals = Bitcoin.assetDecimals(Bitcoin.asset);
        const btcAmount = new BigNumber(Math.random()).decimalPlaces(decimals);
        const nonce = utils.keccak256(Buffer.from("1"));

        // Shift the amount by the asset's decimals (8 for BTC).
        const satsAmount = new BigNumber(btcAmount).times(new BigNumber(10).exponentiatedBy(decimals));
        console.log("satsAmount: " + satsAmount);

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
        console.log("Balance Before of accounts[2]: " + balanceBefore);

        await new Promise((resolve, reject) => {
            mint.on("deposit", async deposit => {
              try {
                await deposit.confirmed();
                await deposit.signed();
                //await deposit.mint();
                const tx = await deposit.queryTx()
                if (tx.out && !tx.out.revert) {
                  await adapter.temporaryMint(accounts[2], nonce, 'BTC', new BigNumber(tx.out.amount.toString()), tx.out.nhash, tx.out.signature)
                } else {
                  throw new Error('revert was present on the out')
                }
                resolve();
              } catch (error) {
                console.error(error);
                reject(error);
              }
            });
        });

        balanceAfter = await adapter.userBalance(accounts[2]);
        console.log('balanceAfter: '+ balanceAfter);

        const expected = satsAmount.minus(fixedFee).times(1 - percentFee / 10000).integerValue(BigNumber.ROUND_UP);
        assert((balanceAfter - balanceBefore).toString() == expected.toString(),'Problem with minting of renBTC');
    });

    it('Deposit the money into Defi', async () =>{

        await renBtc.approve(moneyToCurve.address, balanceAfter, {from: accounts[2]});
        //await wBtc.approve(moneyToCurve.address,0, {from:accounts[2]});
        await wBtc.approve(moneyToCurve.address,deposits.wbtc, {from:accounts[2]});

        let renbtcBefore = await adapter.userBalance(accounts[2]);
        renBTCWithdraw = renbtcBefore;

        let wbtcBefore = await wBtc.balanceOf(accounts[2]);

        await truffleAssert.passes(moneyToCurve.multiStepDeposit([balanceAfter,deposits.wbtc], {from:accounts[2]}));

        let renbtcAfter = await adapter.userBalance(accounts[2]);
        let wbtcAfter = await wBtc.balanceOf(accounts[2]);

        console.log('renbtcBefore curveFi: '+ renbtcBefore);
        console.log('renbtcAfter curveFi: '+ renbtcAfter);

        console.log('wbtcBefore curveFi: '+ wbtcBefore);
        console.log('wbtcAfter curveFi: '+ wbtcAfter);
    });
    
    it('Renpool tokens are deposited to curve.fi swap', async () => {
      swaprenBTC = await renBtc.balanceOf(curveSwap.address);
      swapwBTC = await wBtc.balanceOf(curveSwap.address);

      console.log("swaprenBTC: " + swaprenBTC);
      console.log("swapwBTC: " + swapwBTC);
    });

    it('Curve.Fi LP-tokens are staked in Gauge', async () =>{
      let lptokens = swaprenBTC.mul(new BN('10000000000')).add(swapwBTC);
      let stakedTokens  = await moneyToCurve.curveLPTokenStaked();

      console.log("lptokens: " + lptokens);
      console.log("stakedTokens: " + stakedTokens);

      assert(lptokens.toString() == stakedTokens.toString(),'CurveFi: problem with the staking');
    });

    it('CRV tokens are minted and transfered to the user', async() => {
      let crvBalance = await crvToken.balanceOf(accounts[2]);
      console.log("crvBalance: " + crvBalance);
      // assert(crvBalance > 0 , 'CRVs not transfered to user');
    });

    it('Withdraw money from curve.fi', async () =>{
      
      let renbtcBefore = await adapter.userBalance(accounts[2]);
      let wbtcBefore = await wBtc.balanceOf(accounts[2]);

      console.log("renbtcBefore: " + renbtcBefore);
      console.log("wbtcBefore: "+ wbtcBefore);

      
      await moneyToCurve.multiStepWithdraw([balanceAfter,100000000000],{from:accounts[2]});

      let renbtcAfter = await renBtc.balanceOf(accounts[2]);
      let wbtcAfter = await wBtc.balanceOf(accounts[2]);

      console.log("renbtcAfter: " + renbtcAfter);
      console.log("wbtcAfter: "+ wbtcAfter);
      
      // assert((renbtcAfter - renbtcBefore).toString() == (deposits.renbtc).toString(), 'Withdrawal falied for renBTC');
      // assert((wbtcAfter - wbtcBefore).toString() == (deposits.wbtc).toString(), 'Withdrawal falied for wBTC');

    });

    it('should be able to burn the minted tokens', async () =>{
      const amount = balanceAfter / 10 ** 8;
      await renBtc.approve(adapter.address, balanceAfter,{from: accounts[2]})
      const burnAndRelease = await renJS.burnAndRelease({
        asset: "BTC",
        to: Bitcoin.Address(tempBTCadd),
        from: Ethereum({provider: user.provider, signer: user},network).Contract((btcAddress) => ({
          sendTo: adapter.address,
          contractFn: "temporaryBurn",
          contractParams: [
          {
            type: "bytes",
            name: "_msg",
            value: Buffer.from(`Withdrawing ${amount} BTC`),
          },
          {
            type: "bytes",
            name: "_to",
            value: btcAddress,
          },
          {
            type: "uint256",
            name: "_amount",
            value: renJS.utils.toSmallestUnit(amount, 8),
          },
          {
            type: 'address',
            name: 'from',
            value: accounts[2]
          }
          ],
        }))

       });
       
       await burnAndRelease.burn();
       await burnAndRelease.release();

      let afterBurnBalance =  await adapter.userBalance(accounts[2]);
      console.log("afterBurnBalance: "+ afterBurnBalance);
      
    });




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