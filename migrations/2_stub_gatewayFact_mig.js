const { MockChain, MockProvider }  = require("@renproject/mock-provider");
const RenJS  = require("@renproject/ren");
const RenVMProvider  = require("@renproject/rpc/build/main/v2");
const GatewayFactory = artifacts.require('Stub_GatewayFactory');

module.exports = async function (deployer,network,accounts) {
    const mockRenVMProvider = new MockProvider();
    // const x = await RenVMProvider.new("testnet", mockRenVMProvider);
    // const renJS = new RenJS(x);

    const Bitcoin = new MockChain();
    mockRenVMProvider.registerChain(Bitcoin);

    const mintAuthority =  mockRenVMProvider.mintAuthority();
    //const gatewayFactory = await GatewayFactory.new(mintAuthority, "Ethereum", {from: accounts[0]});
   deployer.deploy(GatewayFactory,mintAuthority,"Ethereum");
};