var TransparentTPA = artifacts.require("./TransparentTPA.sol");

module.exports = function(deployer) {
	deployer.deploy(TransparentTPA);
}