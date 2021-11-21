const MoneytoCurve = artifacts.require("RenBTCtoCurve");

module.exports = function (deployer, network, accounts) {
  deployer.deploy(MoneytoCurve,{from: accounts[1]});
};
