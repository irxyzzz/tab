pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";
import "./AccessControl.sol";


contract TransparentTPA is Ownable, AccessControl {
	bytes32 public constant AUTHORITY_ROLE = keccak256("AUTHORITY_ROLE");
    bytes32 public constant ACTOR_DATA_OWNER_ROLE = keccak256("ACTOR_DATA_OWNER_ROLE");
    bytes32 public constant ACTOR_DATA_USER_ROLE = keccak256("ACTOR_DATA_USER_ROLE");
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");

    struct snapshot {
    	bytes32 request;
    	bytes32 response;
    	uint requestTime;
    	uint responseTime;
    	bool exist;
        bool confirm;
    }

    struct signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    bool enrollStatus = false;
    uint punishment = 0.001 ether;
    // cost of the enroll of entities that did not need to pay
    uint minEnrollCost = 0.005 ether;
    uint minObligationCost = 0.0008 ether;
    // guarantee deposite 
    uint minGuarenteeValue = 1 ether;
    mapping(bytes32 => snapshot) obligationKS;
    mapping(address => bytes) obligationPP;

    // record whether an entity get the one-time registration cost.
    mapping(address => bool) gasRewardOneTime;
    mapping(address => uint) guaranteeDeposite;

    // modifier
    modifier onlyDataUser() {
        require(hasRole(ACTOR_DATA_USER_ROLE, msg.sender), "Caller is not a data user");
        _;
    }
    modifier onlyDataOwner() {
        require(hasRole(ACTOR_DATA_OWNER_ROLE, msg.sender), "Caller is not a data owner");
        _;
    }
    modifier onlyActor() {
        require(hasRole(ACTOR_DATA_OWNER_ROLE, msg.sender) || hasRole(ACTOR_DATA_USER_ROLE, msg.sender), "Caller is not a data owner");
        _;
    }
    modifier onlyAuthority() {
        require(hasRole(AUTHORITY_ROLE, msg.sender), "Caller is not a TPA");
        _;
    }
    modifier onlyMonitor() {
        require(hasRole(MONITOR_ROLE, msg.sender), "Caller is not a monitor");
        _;
    }
    modifier onlyDeposit() {
        require(hasRole(AUTHORITY_ROLE, msg.sender)||hasRole(ACTOR_DATA_OWNER_ROLE, msg.sender)||hasRole(ACTOR_DATA_USER_ROLE, msg.sender), "Caller is not allowed to deposit");
        _;
    }
    modifier onlyWithdrawRegisterCost() {
        require(hasRole(AUTHORITY_ROLE, msg.sender)||hasRole(ACTOR_DATA_OWNER_ROLE, msg.sender), "Caller is not allowed to withdrawCost");
        _;
    }


    // SC DEPLOYMENT: 2855646 gas - 0.057113 ether/0.0571129 ether
    constructor() public {
    	_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    	gasRewardOneTime[msg.sender] = false;
    }

    function enrollLock() public onlyOwner returns(bool){
    	enrollStatus = false;
        return enrollStatus;
    }

    function enrollOpen() public onlyOwner returns(bool){
    	enrollStatus = true;
        return enrollStatus;
    }

    // COST: 158677 gas - 0.0031078 ether/0.003174ether
    function registerAuthority(bytes memory _pk, signature memory _sign) public {
    	require(enrollStatus, 'enroll status should be open');
    	// verify signature is matched with address
    	require(ecrecover(keccak256(abi.encodePacked(msg.sender, _pk)), _sign.v, _sign.r, _sign.s) == msg.sender);
    	// verify pk is matched with address
    	require((uint(keccak256(_pk)) & 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) == uint(msg.sender));
    	// verify security deposit, as a guarantee.
    	// require(msg.value >= minGuarenteeValue);
    	
    	_setupRole(AUTHORITY_ROLE, msg.sender);
    	obligationPP[msg.sender] = _pk;
    	gasRewardOneTime[msg.sender] = false;
    	// guaranteeDeposite[msg.sender] = msg.value;
    }
 
    // COST: 158665 gas - 0.0031733 ether
    function registerActorDataOwner(bytes memory _pk, signature memory _sign) public {
    	require(enrollStatus, 'enroll status should be open');
    	// verify signature is matched with address
    	require(ecrecover(keccak256(abi.encodePacked(msg.sender, _pk)), _sign.v, _sign.r, _sign.s) == msg.sender);
    	// verify pk is matched with address
    	require((uint(keccak256(_pk)) & 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) == uint(msg.sender));

    	_setupRole(ACTOR_DATA_OWNER_ROLE, msg.sender);
    	obligationPP[msg.sender] = _pk;
    	gasRewardOneTime[msg.sender] = false;
    }

    // COST 156549 gas - 0.0031305 ether/0.003131 ether
    function registerActorDataUser(bytes memory _pk, signature memory _sign) public {
    	require(enrollStatus, 'enroll status should be open');
    	// verify signature is matched with address
    	require(ecrecover(keccak256(abi.encodePacked(msg.sender, _pk)), _sign.v, _sign.r, _sign.s) == msg.sender);
    	// verify pk is matched with address
    	require((uint(keccak256(_pk)) & 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) == uint(msg.sender));

    	// transfer reward for the registration of TPA and data owner
    	_setupRole(ACTOR_DATA_USER_ROLE, msg.sender);
    	obligationPP[msg.sender] = _pk;
    }

      // COST 155414 gas - 0.0031083 ether
    function registerMonitor(bytes memory _pk, signature memory _sign) public {
    	require(enrollStatus, 'enroll status should be open');
    	// verify signature is matched with address
    	require(ecrecover(keccak256(abi.encodePacked(msg.sender, _pk)), _sign.v, _sign.r, _sign.s) == msg.sender);
    	// verify pk is matched with address
    	require((uint(keccak256(_pk)) & 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) == uint(msg.sender));

    	_setupRole(MONITOR_ROLE, msg.sender);
    	obligationPP[msg.sender] = _pk;
    }

    function depositeGuarantee() public payable onlyDeposit {
    	require(!enrollStatus, 'enroll status should be locked.');

        if (hasRole(ACTOR_DATA_USER_ROLE, msg.sender)) {
            // compute the payment for other entities' registration
            uint payment = minEnrollCost * (getRoleMemberCount(ACTOR_DATA_OWNER_ROLE) + 1)/getRoleMemberCount(ACTOR_DATA_USER_ROLE) + minGuarenteeValue;
            require(msg.value >= payment);
            guaranteeDeposite[msg.sender] = msg.value - payment;
        } else if (hasRole(AUTHORITY_ROLE, msg.sender)) {
            require(msg.value >= minGuarenteeValue);
            guaranteeDeposite[msg.sender] = msg.value;
        }
    	
    }

    // COST 53068 gas - 0.0010614 ether
    function rewardRegisterCost() public onlyWithdrawRegisterCost {
    	// ensure that the registered entity has not been rewarded.
    	require(!gasRewardOneTime[msg.sender], 'Call has been rewarded');

    	msg.sender.transfer(minEnrollCost);
    	gasRewardOneTime[msg.sender] = true;
    }

    function rewardDeploymentCost() public onlyOwner {
    	require(!gasRewardOneTime[msg.sender], 'Call has been rewarded');
    	
    	msg.sender.transfer(0.05 ether);
    	gasRewardOneTime[msg.sender] = true;
    }

    function _checkGuaranteeDeposit(address account) private returns(bool) {
        if (guaranteeDeposite[account] > punishment) {
            return true;
        }
        else {
            return false;
        }
    }

    // COST: 43190 gas - 0.0008638 ether
    function recordKSPKResquest(bytes32 _requestIdentifier, uint _pkReqSymbol, uint _requestTime, signature memory _sign) public onlyDataOwner {
    	// verify recently passed time
	    require(_requestTime > now - 1 minutes);
        // require(_requestTime < now + 5 minutes);
	    // verify signature
	    require(ecrecover(keccak256(abi.encodePacked(_requestIdentifier, _pkReqSymbol, _requestTime)), _sign.v, _sign.r, _sign.s) == msg.sender);

	    obligationKS[_requestIdentifier].request = keccak256(abi.encodePacked(_pkReqSymbol));
	    obligationKS[_requestIdentifier].requestTime = _requestTime;
	    obligationKS[_requestIdentifier].exist = true;
    }

    // COST: 36091 gas - 0.0007218 ether
    function recordKSPKResponse(bytes32 _requestIdentifier, bytes32 _pkHash, uint _responseTime, signature memory _sign) public onlyAuthority {
        require(_checkGuaranteeDeposit(msg.sender), 'no extra guarantee deposit');
    	// verify recently passed time
	    require(_responseTime > obligationKS[_requestIdentifier].requestTime);
        // require(_responseTime < now);
	    // verify signature
	    require(ecrecover(keccak256(abi.encodePacked(_requestIdentifier, _pkHash, _responseTime)), _sign.v, _sign.r, _sign.s) == msg.sender);
	    // verify the request is exist
	    require(obligationKS[_requestIdentifier].exist, 'the request identifier is not there');

	    obligationKS[_requestIdentifier].response = _pkHash;
	    obligationKS[_requestIdentifier].responseTime = _responseTime;
    }

    function _inferencePreventionModule(uint[] memory _y) private returns(bool) {
        // verify y vector
        uint counter = 0;
        for(uint i = 0; i < _y.length; i++) {
            if (_y[i] != 0) {
                counter += 1;
            }
        }
        if (counter > (_y.length / 2)) {
            return true;
        }
        else {
            return false;
        }
    }

    // COST: 73190 gas - 0.0014638 ether
    function recordKSSKResquest(bytes32 _requestIdentifier, uint[] memory _y, uint _requestTime, signature memory _sign) public payable onlyDataUser returns(bool){
        require(_checkGuaranteeDeposit(msg.sender), 'no extra guarantee deposit');
    	// verify recently passed time
	    require(_requestTime > now - 5 minutes);
        // require(_requestTime < now);
	    // verify signature
	    require(ecrecover(keccak256(abi.encodePacked(_requestIdentifier, _y[0], _y[1], _y[2], _y[3], _y[4], _requestTime)), _sign.v, _sign.r, _sign.s) == msg.sender);
	    require(msg.value >= minObligationCost);

        if (_inferencePreventionModule(_y)) {
            obligationKS[_requestIdentifier].request = keccak256(abi.encodePacked(_y));
            obligationKS[_requestIdentifier].requestTime = _requestTime;
            obligationKS[_requestIdentifier].exist = true;
            return true;
        }
        else {
            guaranteeDeposite[msg.sender] -= punishment;
            return false;
        }
    }

    // COST: 77821 gas - 0.0015564 ether
    function recordKSSKResponse(bytes32 _requestIdentifier, bytes32 _skHash, uint _responseTime, signature memory _sign) public onlyAuthority {
        require(_checkGuaranteeDeposit(msg.sender), 'no extra guarantee deposit');
    	// verify recently passed time
	    require(_responseTime > obligationKS[_requestIdentifier].requestTime);
        // require(_responseTime < now);
	    // verify signature
	    require(ecrecover(keccak256(abi.encodePacked(_requestIdentifier, _skHash, _responseTime)), _sign.v, _sign.r, _sign.s) == msg.sender);
	    // verify the request is exist
	    require(obligationKS[_requestIdentifier].exist, 'the request identifier is not there');

	    obligationKS[_requestIdentifier].response = _skHash;
	    obligationKS[_requestIdentifier].responseTime = _responseTime;
	    
	    // transfer reward for the pk request recrod
	    if (address(this).balance > minObligationCost) {
	    	msg.sender.transfer(minObligationCost);
		}
    }

    function recordKSConfirm(address _tpa, bytes32 _requestIdentifier, bytes32 _keyHash, uint _confirmTime, 
        signature memory _signTPA, signature memory _signActor) public onlyActor {
        require(_confirmTime > obligationKS[_requestIdentifier].responseTime);
        // require(_confirmTime < now);
        // verify signature
        // require(ecrecover(keccak256(abi.encodePacked(_tpa, _requestIdentifier, _keyHash, _confirmTime, _signTPA.v, _signTPA.r, _signTPA.s)), _signActor.v, _signActor.r, _signActor.s) == msg.sender);
        // verify the request is exist
        require(obligationKS[_requestIdentifier].exist, 'the request identifier is not there');

        obligationKS[_requestIdentifier].confirm = true;
        if (_keyHash == obligationKS[_requestIdentifier].response) {
            if (!(ecrecover(keccak256(abi.encodePacked(_requestIdentifier, _keyHash, obligationKS[_requestIdentifier].responseTime)), _signTPA.v, _signTPA.r, _signTPA.s) == _tpa)) {
                guaranteeDeposite[_tpa] -= punishment;
                if (address(this).balance > punishment) {
                    msg.sender.transfer(punishment);
                }
            }
        }
    }

    // Monitor inspect the contents of the recorded audit obligations 
    function inspectObligationKS(bytes32 _requestIdentifier) public onlyMonitor returns(bool) {
    	// verify 15 minutes passed without response
	    // require(now >= obligationKS[_requestIdentifier].responseTime + 1 seconds);

	    if (obligationKS[_requestIdentifier].confirm && obligationKS[_requestIdentifier].response == bytes32(0)) {
	    	guaranteeDeposite[msg.sender] -= punishment;
	     	if (address(this).balance > punishment) {
		    	msg.sender.transfer(punishment);
			}
	    	return true;
	    }
	    else {
	    	return false;
	    }
    }

    function _bytesEqual(bytes memory b1, bytes memory b2) private returns(bool) {
        if (keccak256(abi.encodePacked(b1)) == keccak256(abi.encodePacked(b2))) {
            return true;
        } else {
            return false;
        }
    }
    // Monitor inspect the contents of the recorded audit obligations 
    function inspectObligationPP(address _address, bytes memory _pk, signature memory _sign) public onlyMonitor returns(bool) {
        require(ecrecover(keccak256(abi.encodePacked(_address, _pk)), _sign.v, _sign.r, _sign.s) == _address);
        if (!_bytesEqual(obligationPP[_address], _pk)) {
            guaranteeDeposite[_address] -= punishment;
            if (address(this).balance > punishment) {
                msg.sender.transfer(punishment);
            }
            return true;
        }
        else {
            return false;
        }
    }

    function drapout() public {
        require(enrollStatus, 'enrollment is not open');
        if (hasRole(AUTHORITY_ROLE, msg.sender)) {
            renounceRole(AUTHORITY_ROLE, msg.sender);
            msg.sender.transfer(guaranteeDeposite[msg.sender]);
        } else if (hasRole(ACTOR_DATA_USER_ROLE, msg.sender)) {
            renounceRole(ACTOR_DATA_USER_ROLE, msg.sender);
            msg.sender.transfer(guaranteeDeposite[msg.sender]);
        } else if (hasRole(ACTOR_DATA_OWNER_ROLE, msg.sender)){
            renounceRole(ACTOR_DATA_OWNER_ROLE, msg.sender);
        } else if (hasRole(MONITOR_ROLE, msg.sender)) {
            renounceRole(MONITOR_ROLE, msg.sender);
        }
    }
}