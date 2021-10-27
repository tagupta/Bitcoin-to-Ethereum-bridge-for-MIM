const CurveSwap = artifacts.require("Stub_CurveFi_Swap");

module.exports = function (deployer) {
  deployer.deploy(CurveSwap);
};
