const CurveGauge = artifacts.require("Stub_CurveFi_Gauge");

module.exports = function (deployer) {
  deployer.deploy(CurveGauge);
};
