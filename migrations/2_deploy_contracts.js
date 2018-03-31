var Task = artifacts.require("./Task.sol");
var User = artifacts.require("./User.sol");

module.exports = function(deployer) {
  deployer.deploy(User);
  deployer.deploy(Task);
};