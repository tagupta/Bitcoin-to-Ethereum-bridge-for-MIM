const truffleAssert = require('truffle-assertions');
const { BigNumber, utils }  = require('ethers');
const ethers = require('ethers');
const { Ethereum, EthereumConfig }  = require("@renproject/chains-ethereum");
//Renjs imports
const { MockChain, MockProvider }  = require("@renproject/mock-provider");
const RenJS  = require("@renproject/ren");
const { RenVMProvider } = require("@renproject/rpc/build/main/v2");
// const { BasicAdapter__factory,
//         GatewayFactory__factory,
//         IERC20__factory,
//         GatewayRegistry__factory} = require('@renproject/gateway-sol/typechain');
// const { GatewayRegistry } = require('@renproject/gateway-sol/typechain');     

const Adapter = artifacts.require('Basic');

contract('Witnessing the transition from BTC to renBTC', async accounts => {
    let adapter;
    let Bitcoin;
    let renjs;
    let network;
    let registry;

    before(async() =>{
        const [deployer, user] = await ethers.getSigners();
        console.log(deployer);
        console.log(user);
    });
   

})



