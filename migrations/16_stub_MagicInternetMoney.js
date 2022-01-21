const MagicInternetMoney = artifacts.require("Stub_MagicInternetMoney");

module.exports = async function (deployer) {
  deployer.deploy(MagicInternetMoney);
};
