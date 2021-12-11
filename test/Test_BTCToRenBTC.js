const truffleAssert = require('truffle-assertions');
const BigNumber = require('bignumber.js');
const ethers = require('ethers');
const {utils} = require("ethers");

const { Ethereum }  = require("@renproject/chains-ethereum");
const { MockChain, MockProvider }  = require("@renproject/mock-provider");
const RenJS  = require("@renproject/ren");
const {RenVMProvider}  = require("@renproject/rpc/build/main/v2");    

const Adapter = artifacts.require('Basic');
const GatewayFactory = artifacts.require('Stub_GatewayFactory');
const BasicAdapter = artifacts.require('Stub_BasicAdapter');
const RENBTC = artifacts.require('Stub_ERC20');

//Bitcoin address
const CoinKey = require('coinkey');

contract('Witnessing the transition from BTC to renBTC', async (accounts) => {
    let adapter;
    let gatewayFactory;
    let gatewayRegistryAddress;
    let basicAdapter;
    let Bitcoin;
    let renJS;
    let network;
    let renBtc;
    let user;
    let wallet;
    const tempBTCadd = '183Y3PKMjkmH4vLTzZwpkVAxp45RTuz9rZ';
    //5c88ae5b66f18a4d3aca65b8b2535d89e9546db3f2107a2b180d42784f968584
    let balanceAfter;

    before(async() =>{

        wallet = new CoinKey.createRandom();
        private_Key = wallet.privateKey.toString('hex');
        addressBTC = await wallet.publicAddress;
      
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
        network = {
            name: "dev",
            chain: "dev",
            chainLabel: "dev",
            isTestnet: false,
            networkID: 1337,
            infura: "",
            publicProvider: () => "",
            explorer: {
            address: () => "",
            transaction: () => "",
            },
            etherscan: "",
            addresses: {
            GatewayRegistry: gatewayRegistryAddress,
            BasicAdapter: basicAdapter.address,
            },
      };
  
        renJS = new RenJS(new RenVMProvider(network, mockRenVMProvider));
        
        //Deploy Adapter [main contract]
        adapter  = await Adapter.new(gatewayRegistryAddress, {from: accounts[0]});
        const renAddress = await adapter.getRenERC20();
        
        renBtc = await RENBTC.at(renAddress,{from: accounts[0]});

        const provider = await ethers.getDefaultProvider('http://localhost:8545');
        user = await provider.getSigner();
    });

    it('should mint some tokens', async () =>{
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

      // Check that the balance of the contract increased by the expected amount.
      balanceAfter = await adapter.userBalance(accounts[2]);
      
      const expected = satsAmount.minus(fixedFee).times(1 - percentFee / 10000).integerValue(BigNumber.ROUND_UP);
      assert((balanceAfter - balanceBefore).toString() == expected.toString(),'Problem with minting of renBTC');
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
      
    });
});



