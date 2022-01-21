const MoneytoCurve = artifacts.require("RenBTCtoCurve");

module.exports = function (deployer) {
  deployer.deploy(MoneytoCurve);
};
