const TAB = artifacts.require("TransparentTPA");
const ethUtils = require('ethereumjs-util')
const abi = require('ethereumjs-abi')

const sk_admin = new Buffer('66de31e4b624e6a4f76c45be15336a73105e34bf22d3f3774ab40845909815de', 'hex')
const sk_tpa = new Buffer('891a8af021f042a13626b0b450caffe91b699021bef09b5acef011bad9fc5bc3', 'hex')
const sk_data_owner = new Buffer('866e5961ee1e158d837399f834f0c975ad6d3163d802c1a62b4ae0af9bb65dfa', 'hex')
const sk_data_user = new Buffer('cd99fdbe32bdc750565f682a9e6eaefbb348c306e29c46b993684cd01b6e8c1c', 'hex')
const sk_monitor = new Buffer('d39d70b0042e1cc8b443725a07de5cd80a8c5b09eb40b0e7758eed4856ea4fa2', 'hex')

const pk_admin = '0x' + ethUtils.privateToPublic(sk_admin).toString('hex')
const pk_tpa = '0x' + ethUtils.privateToPublic(sk_tpa).toString('hex')
const pk_data_owner = '0x' + ethUtils.privateToPublic(sk_data_owner).toString('hex')
const pk_data_user = '0x' + ethUtils.privateToPublic(sk_data_user).toString('hex')
const pk_monitor = '0x' + ethUtils.privateToPublic(sk_monitor).toString('hex')


contract("TransparentTPA", accounts => {
	addr_admin = accounts[0]
	addr_tpa = accounts[1];
	addr_data_owner = accounts[2];
	addr_data_user = accounts[3];
	addr_monitor = accounts[4];

	// it("test the deployment", () => 
	// 	TAB.deployed()
	// 	.then(instance => instance.owner())
	// 	.then(addr => {
	// 		assert.equal(addr, addr_admin, 'admin should be the first account')
	// 	})
	// );
	it("test the deployment using async", async () => {
		let instance = await TAB.new({from:addr_admin});
		let receipt = await web3.eth.getTransactionReceipt(instance.transactionHash);
		console.log(`GasUsed - deployment: ${receipt.gasUsed}`);
	});

	// const instance = TAB.new({from:addr_admin});
	// var instance;
	before(async () => {
		this.instance = await TAB.new({from:addr_admin});
	});
	it("test the enrollOpen", async () => {
		let result = await this.instance.enrollOpen({from:addr_admin});
		console.log(`GasUsed - enrollOpen: ${result.receipt.gasUsed}`);
	});

	before(async () => {
		// this.instance = await TAB.new({from:addr_admin});
		await this.instance.enrollOpen({from:addr_admin});
		var vrs_tpa = ethUtils.ecsign(new Buffer(web3.utils.soliditySha3(addr_tpa, pk_tpa).slice(2), 'hex'), sk_tpa);
		this.sign_tpa = {v:vrs_tpa.v, r:'0x'+vrs_tpa.r.toString('hex'), s:'0x'+vrs_tpa.s.toString('hex')};
		var vrs_do =  ethUtils.ecsign(new Buffer(web3.utils.soliditySha3(addr_data_owner, pk_data_owner).slice(2), 'hex'), sk_data_owner);
		this.sign_do = {v:vrs_do.v, r:'0x'+vrs_do.r.toString('hex'), s:'0x'+vrs_do.s.toString('hex')};
		var vrs_du =  ethUtils.ecsign(new Buffer(web3.utils.soliditySha3(addr_data_user, pk_data_user).slice(2), 'hex'), sk_data_user);
		this.sign_du = {v:vrs_du.v, r:'0x'+vrs_du.r.toString('hex'), s:'0x'+vrs_du.s.toString('hex')};
		var vrs_m =  ethUtils.ecsign(new Buffer(web3.utils.soliditySha3(addr_monitor, pk_monitor).slice(2), 'hex'), sk_monitor);
		this.sign_m = {v:vrs_m.v, r:'0x'+vrs_m.r.toString('hex'), s:'0x'+vrs_m.s.toString('hex')};
	});
	it("test the registerAuthority", async () => {
		let result = await this.instance.registerAuthority(pk_tpa, this.sign_tpa, {from:addr_tpa});
		console.log(`GasUsed - registerAuthority: ${result.receipt.gasUsed}`);
		// console.log(web3.utils.soliditySha3("AUTHORITY_ROLE"));
		// console.log(web3.utils.soliditySha3({t: 'string', v:'AUTHORITY_ROLE'}));
		// console.log(instance.getRoleMemberCount(role));
		// console.log(instance.getRoleMember(role, 0));
	});
	it("test the registerActorDataOwner", async () => {
		let result = await this.instance.registerActorDataOwner(pk_data_owner, this.sign_do, {from:addr_data_owner});
		console.log(`GasUsed - registerActorDataOwner: ${result.receipt.gasUsed}`);
	});
	it("test the registerActorDataUser", async () => {
		let result = await this.instance.registerActorDataUser(pk_data_user, this.sign_du, {from:addr_data_user});
		console.log(`GasUsed - registerActorDataUser: ${result.receipt.gasUsed}`);
	});
	it("test the registerMonitor", async () => {
		let result = await this.instance.registerMonitor(pk_monitor, this.sign_m, {from:addr_monitor});
		console.log(`GasUsed - registerMonitor: ${result.receipt.gasUsed}`);
	});
	it("test the enrollLock", async () => {
		let result = await this.instance.enrollLock({from:addr_admin});
		console.log(`GasUsed - enrollLock: ${result.receipt.gasUsed}`);
	});
	// it("test the enrollLock", async () => {
	// 	var res = await this.instance.enrollLock.call({from:addr_admin});
	// 	console.log(res);
	// });

	before(async () => {
		// instance = await TAB.new({from:addr_admin});
		// await this.instance.enrollOpen({from:addr_admin});
		await this.instance.registerAuthority(pk_tpa, this.sign_tpa, {from:addr_tpa});
		await this.instance.registerActorDataOwner(pk_data_owner, this.sign_do, {from:addr_data_owner});
		await this.instance.registerActorDataUser(pk_data_user, this.sign_du, {from:addr_data_user});
		await this.instance.registerMonitor(pk_monitor, this.sign_m, {from:addr_monitor});
		await this.instance.enrollLock({from:addr_admin});
	});
	it("test the depositeGuarantee - TPA", async () => {
		let result = await this.instance.depositeGuarantee({from:addr_tpa, value: web3.utils.toWei('1', 'ether')});
		console.log(`GasUsed - depositeGuarantee-TPA: ${result.receipt.gasUsed}`);
	});
	it("test the depositeGuarantee - Data User", async () => {
		let result = await this.instance.depositeGuarantee({from:addr_data_user, value: web3.utils.toWei('1.1', 'ether')});
		console.log(`GasUsed - depositeGuarantee-DU: ${result.receipt.gasUsed}`);
	});

	before(async () => {
		await this.instance.depositeGuarantee({from:addr_tpa, value: web3.utils.toWei('1', 'ether')});
		await this.instance.depositeGuarantee({from:addr_data_user, value: web3.utils.toWei('1.1', 'ether')});
	});
	it("test the rewardRegisterCost - TPA", async () => {
		let result = await this.instance.rewardRegisterCost({from:addr_tpa});
		console.log(`GasUsed - rewardRegisterCost-TPA: ${result.receipt.gasUsed}`);
	});
	it("test the rewardDeploymentCost", async () => {
		let result = await this.instance.rewardDeploymentCost({from:addr_admin});
		console.log(`GasUsed - rewardDeploymentCost: ${result.receipt.gasUsed}`);
	});

	before(async () => {
		this.kspkId = '0x4d1ebdae1b4a4e464e176765f0fcd504455a8b9c000000000000000000000000';
		this.kspkReq = 0;
		this.kspkReqT = new Date().getTime();
		kspkReqVRS =  ethUtils.ecsign(new Buffer(web3.utils.soliditySha3(this.kspkId, this.kspkReq, this.kspkReqT).slice(2), 'hex'), sk_data_owner);
		this.sign_kspkreq = {v:kspkReqVRS.v, r:'0x'+kspkReqVRS.r.toString('hex'), s:'0x'+kspkReqVRS.s.toString('hex')};
	});
	it("test the recordKSPKResquest", async () => {
		let result = await this.instance.recordKSPKResquest(this.kspkId, this.kspkReq, this.kspkReqT, this.sign_kspkreq, {from:addr_data_owner});
		console.log(`GasUsed - recordKSPKResquest: ${result.receipt.gasUsed}`);
	});

	before(async () => {
		await this.instance.recordKSPKResquest(this.kspkId, this.kspkReq, this.kspkReqT, this.sign_kspkreq, {from:addr_data_owner});
		this.kspkResp = '0x2d5f348b361c5ebdea650e8436cd6f66be71ea4f1610725c5afdb00885210600';
		this.kspkRespT = new Date().getTime();
		kspkRespVRS =  ethUtils.ecsign(new Buffer(web3.utils.soliditySha3(this.kspkId, this.kspkResp, this.kspkRespT).slice(2), 'hex'), sk_tpa);
		this.sign_kspkresp = {v:kspkRespVRS.v, r:'0x'+kspkRespVRS.r.toString('hex'), s:'0x'+kspkRespVRS.s.toString('hex')};
		
	});
	it("test the recordKSPKResponse", async () => {
		let result = await this.instance.recordKSPKResponse(this.kspkId, this.kspkResp, this.kspkRespT, this.sign_kspkresp, {from:addr_tpa});
		console.log(`GasUsed - recordKSPKResponse: ${result.receipt.gasUsed}`);
	});

	before(async () => {
		await this.instance.recordKSPKResponse(this.kspkId, this.kspkResp, this.kspkRespT, this.sign_kspkresp, {from:addr_tpa});
		this.confirmT = new Date().getTime();
		var confirmVRS = ethUtils.ecsign(new Buffer(web3.utils.soliditySha3(addr_tpa, this.kspkId, this.kspkResp, this.confirmT, 
			this.sign_kspkresp.v, this.sign_kspkresp.r, this.sign_kspkresp.s).slice(2), 'hex'), sk_data_owner);
		this.sign_confirm = {v:confirmVRS.v, r:'0x'+confirmVRS.r.toString('hex'), s:'0x'+confirmVRS.s.toString('hex')};
	});
	it("test the recordKSConfirm", async () => {
		let result = await this.instance.recordKSConfirm(addr_tpa, this.kspkId, this.kspkResp, this.confirmT, this.sign_kspkresp, this.sign_confirm, {from:addr_data_owner});
		console.log(`GasUsed - recordKSConfirm: ${result.receipt.gasUsed}`);
	});


	before(async () => {
		this.ksskId = '0x4d1ebdae1b4a4e464e176765f0fcd504455a8b9c000000000000000000000011';
		this.ksskReq = [1,1,1,1,1];
		this.ksskReqT = new Date().getTime();
		ksskReqVRS =  ethUtils.ecsign(new Buffer(web3.utils.soliditySha3(this.ksskId, 1, 1, 1, 1, 1, this.ksskReqT).slice(2), 'hex'), sk_data_user);
		this.sign_ksskreq = {v:ksskReqVRS.v, r:'0x'+ksskReqVRS.r.toString('hex'), s:'0x'+ksskReqVRS.s.toString('hex')};
	});
	it("test the recordKSSKResquest", async () => {
		let result = await this.instance.recordKSSKResquest(this.ksskId, this.ksskReq, this.ksskReqT, this.sign_ksskreq, {from:addr_data_user, value: web3.utils.toWei('0.01', 'ether')});
		console.log(`GasUsed - recordKSSKResquest: ${result.receipt.gasUsed}`);
	});

	before(async () => {
		await this.instance.recordKSSKResquest(this.ksskId, this.ksskReq, this.ksskReqT, this.sign_ksskreq, {from:addr_data_user, value: web3.utils.toWei('0.01', 'ether')});
		this.ksskResp = '0x2d5f348b361c5ebdea650e8436cd6f66be71ea4f1610725c5afdb00885210611';
		this.ksskRespT = new Date().getTime();
		ksskRespVRS =  ethUtils.ecsign(new Buffer(web3.utils.soliditySha3(this.ksskId, this.ksskResp, this.ksskRespT).slice(2), 'hex'), sk_tpa);
		this.sign_ksskresp = {v:ksskRespVRS.v, r:'0x'+ksskRespVRS.r.toString('hex'), s:'0x'+ksskRespVRS.s.toString('hex')};
		
	});
	it("test the recordKSSKResponse", async () => {
		let result = await this.instance.recordKSSKResponse(this.ksskId, this.ksskResp, this.ksskRespT, this.sign_ksskresp, {from:addr_tpa});
		console.log(`GasUsed - recordKSSKResponse: ${result.receipt.gasUsed}`);
	});
	it("test the inspectObligationKS", async () => {
		let result = await this.instance.inspectObligationKS(this.ksskId, {from:addr_monitor});
		console.log(`GasUsed - inspectObligationKS: ${result.receipt.gasUsed}`);
	});
	it("test the inspectObligationPP", async () => {
		let result = await this.instance.inspectObligationPP(addr_tpa, pk_tpa, this.sign_tpa, {from:addr_monitor});
		console.log(`GasUsed - inspectObligationPP: ${result.receipt.gasUsed}`);
	});
	// before(async () => {
	// });
	it("test the drapout", async () => {
		await this.instance.enrollOpen({from:addr_admin});
		let result = await this.instance.drapout({from:addr_tpa});
		console.log(`GasUsed - drapout: ${result.receipt.gasUsed}`);
	});
});







