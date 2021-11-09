const RenERC20 = artifacts.require("Stub_RenERC20"); // Rpresents Ren Pool

module.exports = function (deployer) {
  deployer.deploy(RenERC20);
};
