const TokenFactory = artifacts.require("Stub_TokenFactory");

module.exports = async function (deployer) {
  deployer.deploy(TokenFactory);
};
