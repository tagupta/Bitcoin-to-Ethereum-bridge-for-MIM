const Registry = artifacts.require("Stub_registry");

module.exports = async function (deployer) {
  deployer.deploy(Registry);
};
