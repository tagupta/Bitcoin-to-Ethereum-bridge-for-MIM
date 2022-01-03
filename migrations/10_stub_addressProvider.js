const AddressProvider = artifacts.require("Stub_addressProvider");

module.exports = async function (deployer) {
  deployer.deploy(AddressProvider);
};
