const CRVToken = artifacts.require("Stub_CRVToken");

module.exports = function (deployer) {
  deployer.deploy(CRVToken);
};
