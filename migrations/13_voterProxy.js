const VoterProxy = artifacts.require("Stub_CurveVoterProxy");

module.exports = async function (deployer) {
  deployer.deploy(VoterProxy);
};
