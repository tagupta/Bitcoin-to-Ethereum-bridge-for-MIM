const truffleAssert = require('truffle-assertions');
const BigNumber = require('bignumber.js');
const ethers = require('ethers');
const { Ethereum, EthereumConfig }  = require("@renproject/chains-ethereum");
//Renjs imports
const { MockChain, MockProvider }  = require("@renproject/mock-provider");
const RenJS  = require("@renproject/ren");
const {RenVMProvider}  = require("@renproject/rpc/build/main/v2");    

const Adapter = artifacts.require('Basic');
const GatewayFactory = artifacts.require('Stub_GatewayFactory');
const BasicAdapter = artifacts.require('Stub_BasicAdapter');

contract('Witnessing the transition from BTC to renBTC', async (accounts) => {
    let adapter;
    let gatewayFactory;
    let basicAdapter;
    let Bitcoin;
    let renJS;
    let network;
    let registry;
    let user;

    before(async() =>{

        const mockRenVMProvider = new MockProvider();
    
        // Set up mock Bitcoin chain.
        Bitcoin = new MockChain("BTC");
        mockRenVMProvider.registerChain(Bitcoin);
        mockRenVMProvider.registerAsset(Bitcoin.asset);

        // Get mint authority from mock provider.
        const mintAuthority =  mockRenVMProvider.mintAuthority();
        // Deploy Gateway Factory.
        gatewayFactory = await GatewayFactory.new(mintAuthority, "Ethereum", {from: accounts[0]});
        const gatewayRegistryAddress = await gatewayFactory.registry();      
        // // Deploy BTC and ZEC tokens and gateways.
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
        const provider = await ethers.getDefaultProvider('http://localhost:8545');
        user = await provider.getSigner();
    });

    it('should mint some tokens', async () =>{
        const decimals = Bitcoin.assetDecimals(Bitcoin.asset);
        const btcAmount = new BigNumber(Math.random()).decimalPlaces(decimals);
       
        // Shift the amount by the asset's decimals (8 for BTC).
        const satsAmount = new BigNumber(btcAmount).times(new BigNumber(10).exponentiatedBy(decimals));

        const fixedFee = 1000; // sats
        const percentFee = 15; // BIPS
       
        // Initialize RenJS lockAndMint.
        const mint = await renJS.lockAndMint({
            // Send BTC from the Bitcoin blockchain to the Ethereum blockchain.
            asset: "BTC", // `bitcoin.asset`
            from: Bitcoin,
            // If you change this to another chain, you also have to change the
            // chain name passed to `gatewayFactory` above.

            to: Ethereum({provider: user.provider, signer: user},network).Contract({
            // The contract we want to interact with
            sendTo: adapter.address,

            // The name of the function we want to call
            contractFn: "deposit",

            // Arguments expected for calling `deposit`
            contractParams: [
                {
                name: "_msg",
                type: "bytes",
                value: Buffer.from(`Depositing ${btcAmount.toFixed()} BTC`),
                },
            ],
            }),
        });

        // Mock deposit. Currently must be passed in as a number.
        Bitcoin.addUTXO(mint.gatewayAddress, satsAmount.toNumber());

        const balanceBefore = await adapter.balance();
        console.log("Basic contract balance Before: " + balanceBefore);

        await new Promise((resolve, reject) => {
            mint.on("deposit", async deposit => {
              try {
                await deposit.confirmed();
                await deposit.signed();
                await deposit.mint();
                resolve();
              } catch (error) {
                console.error(error);
                reject(error);
              }
            });
        });

      // Check that the balance of the contract increased by the expected amount.
      const balanceAfter = await adapter.balance();
      console.log("Basic contract balance after: "+ balanceAfter);
      const expected = satsAmount.minus(fixedFee).times(1 - percentFee / 10000).integerValue(BigNumber.ROUND_UP);
      console.log("expected amount: "+ expected);
      assert((balanceAfter - balanceBefore).toString() == expected.toString(),'Problem with minting of renBTC');
    });
});



