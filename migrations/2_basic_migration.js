const Basic = artifacts.require("Basic");
const GatewayFactory = artifacts.require("Stub_GatewayFactory");

module.exports = async function (deployer) {
  //kovan gatewayRegistry address: 0x557e211EC5fc9a6737d2C6b7a1aDe3e0C11A8D5D

// const GatewayFactory = artifacts.require("Stub_GatewayFactory");

//   var gateway_Fact = await GatewayFactory.deployed();
//   var gatewayRegistryAddress = await gateway_Fact.registry(); 
  deployer.deploy(Basic,"0x557e211EC5fc9a6737d2C6b7a1aDe3e0C11A8D5D");
};
