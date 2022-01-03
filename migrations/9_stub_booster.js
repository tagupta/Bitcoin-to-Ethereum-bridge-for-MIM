const Booster = artifacts.require("Stub_Booster");

module.exports = async function (deployer) {
  deployer.deploy(Booster);
};
