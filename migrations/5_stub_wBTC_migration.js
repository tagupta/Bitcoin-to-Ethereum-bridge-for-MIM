const WBTC = artifacts.require("Stub_WBTC");

module.exports = function (deployer) {
  deployer.deploy(WBTC);
};
