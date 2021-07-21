const ZorroStrategy = artifacts.require("ZorroStrategy");

module.exports = function(deployer) {
  deployer.deploy(ZorroStrategy);
};