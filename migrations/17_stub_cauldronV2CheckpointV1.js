const BentoBox = artifacts.require("Stub_bentoBox");
const MagicInternetMoney = artifacts.require("Stub_MagicInternetMoney");
const CauldronV2CheckpointV1 = artifacts.require("Stub_CauldronV2CheckpointV1");

module.exports = async function (deployer) {
    deployer.deploy(CauldronV2CheckpointV1,BentoBox.address,MagicInternetMoney.address);
};
  