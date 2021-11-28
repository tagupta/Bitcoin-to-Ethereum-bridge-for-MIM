const ERC20 = artifacts.require("Stub_ERC20"); // Rpresents Ren Pool

module.exports = function (deployer) {
  deployer.deploy(ERC20);
};
