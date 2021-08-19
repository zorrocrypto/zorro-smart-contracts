const ZorroStrategy = artifacts.require("ZorroStrategy");
const ZorroTimelock = artifacts.require("ZorroTimelock");

module.exports = function(deployer) {
  deployer.deploy(ZorroStrategy);
  deployer.deploy(ZorroTimelock);
};