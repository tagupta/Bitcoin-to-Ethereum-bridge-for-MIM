const MasterContractManager = artifacts.require("Stub_MasterContractManager");

module.exports = async function (deployer) {
  deployer.deploy(MasterContractManager);
};
