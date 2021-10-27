const CurveMinter = artifacts.require("Stub_CurveFi_Minter");

module.exports = function (deployer) {
  deployer.deploy(CurveMinter);
};
