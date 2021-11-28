const LPToken = artifacts.require("Stub_LPToken");

module.exports = function (deployer, network, accounts) {
  deployer.deploy(LPToken);
};
