pragma solidity ^0.4.25;

contract Endorsement {

    address private creator;                                                         // The creator of this contract
    bool private initialized;                                                        // Initialization state
    uint public lockTime;                                                            // Endorsement lock time
    mapping(uint => address[]) private locks;                                        // Endorsement lock collection storing SMNs in each endorsement period
    mapping(uint => mapping(address => bool)) keys;                                  // Endorsement key collection

    uint public endorsementReward;                                                   // Endorsement reward
    uint public endorsementSMNSize;                                                  // Endorsement limit
    mapping(uint => mapping(address => bool)) public isAddeds;                       // Endorsed SMN collection
    mapping(uint => mapping(string => address[]))  endorsementSenders;               // Endorsement senders based on endorsement number and endorsement data
    mapping(uint => address[])  endorsementSendersAll;                               // Endorsement senders based on endorsement number
    mapping(uint => EndorsementData[])  endorsementDatas;                            // Endorsement datas
    mapping(address => uint) public totalRewardSMNs;                                 // Total reward for each SMN

    mapping(uint => mapping(string => uint))  hashEndorsementCounter;               // Endorsement count based on endorsement number and endorsement data
    mapping(uint => string) private mainEndorsements;                                      // Main endorsements
    mapping(uint => uint) private endorsementsIndexs;                               // Main endorsements index
    mapping(uint => bool) public isEndorsements;                                    // Endorsed collection
    mapping(uint => uint) public endorsementCounter;                                // Endorsement count per endorsement number
    uint public endorsementSize;                                                    // Capacity of an endorsement number
    uint public bottomIndex;                                                        // Endorsed bottom index

    address emptyAddress = 0x0000000000000000000000000000000000000000;              // Empty address
    address permissionContractAddress;                                              // WTC permission contract

    event Deposit(uint value);                                                      // Deposit event
    event RewardSMNs(address[] contributors);                                       // Endorsement reward event
    event AddEndorsement(uint endorsementNumber, string hashFingerprints);          // Endorsement event

    modifier onlyOwner {
        require(msg.sender == creator);
        _;
    }

    struct EndorsementData {
        address sender;
        address worker;
        string hashFingerprints;
        uint blockNumber;
    }

    // Empty endorsement information structure
    EndorsementData emptyEndorsement = EndorsementData(emptyAddress, emptyAddress, "", 0);

    /**
    * Constructor
    * @param _creator Contract owner
    */
    constructor(address _creator) public {
        creator = _creator;
    }

    /**
    * Initialization contract
    * @return bool Returns true on success and false on failure.
    */
    function init(address _permissionContractAddress, uint _endorsementReward, uint _endorsementSize, uint _endorsementSMNSize, uint _lockTime) public onlyOwner returns (bool) {
        require(!initialized);
        permissionContractAddress = _permissionContractAddress;
        endorsementReward = _endorsementReward;
        endorsementSize = _endorsementSize;
        endorsementSMNSize = _endorsementSMNSize;
        lockTime = _lockTime;
        initialized = true;
        return true;
    }

    /**
    * add Endorsement
    * @param _endorsementNumber  Endorsement number
    * @param _hashFingerprints   Endorsement data
    * @return bool  Returns true on success and false on failure.
    */
    function addEndorsement(uint _endorsementNumber, string _hashFingerprints) public returns (bool){

        address  smn;
        bool  isSMN;
        (smn, isSMN) = PermissionContract(permissionContractAddress).getSMNAddress(msg.sender);
        require(isSMN);

        //Endorsement conditions
        uint section = SafeMath.div(block.number, lockTime);
        require(keys[section][smn]);
        require(endorsementReward > 0);
        require(endorsementCounter[_endorsementNumber] < endorsementSMNSize);
        require(address(this).balance > endorsementReward);
        require(!isEndorsements[_endorsementNumber]);
        require(!isAddeds[_endorsementNumber][smn]);

        // Endorsement data
        EndorsementData memory endorsementCurrent;
        endorsementCurrent.sender = smn;
        endorsementCurrent.worker = msg.sender;
        endorsementCurrent.hashFingerprints = _hashFingerprints;
        endorsementCurrent.blockNumber = block.number;

        endorsementSenders[_endorsementNumber][_hashFingerprints].push(smn);
        endorsementSendersAll[_endorsementNumber].push(smn);
        endorsementDatas[_endorsementNumber].push(endorsementCurrent);

        isAddeds[_endorsementNumber][smn] = true;
        endorsementCounter[_endorsementNumber] = SafeMath.add(endorsementCounter[_endorsementNumber], 1);
        hashEndorsementCounter[_endorsementNumber][_hashFingerprints] = SafeMath.add(hashEndorsementCounter[_endorsementNumber][_hashFingerprints], 1);

        if (endorsementDatas[_endorsementNumber].length < 2) {
            mainEndorsements[_endorsementNumber] = _hashFingerprints;
            endorsementsIndexs[_endorsementNumber] = SafeMath.sub(endorsementDatas[_endorsementNumber].length, 1);

        } else {
            uint mainEndorsementCounter = hashEndorsementCounter[_endorsementNumber][mainEndorsements[_endorsementNumber]];

            if (hashEndorsementCounter[_endorsementNumber][_hashFingerprints] > mainEndorsementCounter) {
                mainEndorsements[_endorsementNumber] = _hashFingerprints;
                endorsementsIndexs[_endorsementNumber] = SafeMath.sub(endorsementDatas[_endorsementNumber].length, 1);
            }
        }

        //Determine whether to reward
        if (endorsementCounter[_endorsementNumber] >= endorsementSMNSize) {
            rewardSMNs(endorsementSenders[_endorsementNumber][mainEndorsements[_endorsementNumber]], endorsementReward, _endorsementNumber);
            isEndorsements[_endorsementNumber] = true;
            if (isEndorsements[bottomIndex] == true) {
                bottomIndex++;
            }

        }

        emit AddEndorsement(_endorsementNumber, _hashFingerprints);
        return true;
    }

    /**
    * Get endorsement rights
    * @return bool  Returns true on success and false on failure.
    */
    function setLock() public returns (bool) {
        address  smnCurrent;
        bool isSMNCurrent;
        (smnCurrent, isSMNCurrent) = PermissionContract(permissionContractAddress).getSMNAddress(msg.sender);
        if (!isSMNCurrent) {
            return false;
        }

        uint section = SafeMath.div(block.number, lockTime);
        if (locks[section].length == endorsementSMNSize) {
            return keys[section][smnCurrent];
        }

        if (locks[section].length < endorsementSMNSize) {
            locks[section].push(smnCurrent);
            keys[section][smnCurrent] = true;
        }

        return keys[section][smnCurrent];
    }

    /**
    * Verify Endorsement permissions
    * @return bool true or false
    */
    function checkLock() public view returns (bool) {
        address  smnCurrent;
        bool isSMNCurrent;
        (smnCurrent, isSMNCurrent) = PermissionContract(permissionContractAddress).getSMNAddress(msg.sender);
        if (!isSMNCurrent) {
            return false;
        }

        uint section = SafeMath.div(block.number, lockTime);
        return keys[section][smnCurrent];

    }

    /**
    * Pay for SMNs
    * @param _endorsers  Reward SMN addresses
    * @param _rewardPerRecord     Total reward
    * @param _endorsementNumber    Endorsement number
    */
    function rewardSMNs(address[] _endorsers, uint _rewardPerRecord, uint _endorsementNumber) private {
        require(!isEndorsements[_endorsementNumber]);
        require(address(this).balance >= _rewardPerRecord);
        require(_endorsers.length <= endorsementSMNSize);

        uint rewardPerSMN = SafeMath.div(_rewardPerRecord, _endorsers.length);

        for (uint8 SMNIndex = 0; SMNIndex < _endorsers.length; SMNIndex++) {
            _endorsers[SMNIndex].transfer(rewardPerSMN);
            //Record total rewards for SMN
            totalRewardSMNs[_endorsers[SMNIndex]] = SafeMath.add(totalRewardSMNs[_endorsers[SMNIndex]], rewardPerSMN);
        }
        emit RewardSMNs(_endorsers);
    }

   /**
   * get Endorsement
   * @param _endorsementNumber    Endorsement number
   * @return mainEndorsement data
   */
    function getEndorsement(uint _endorsementNumber) public view returns (address sender, address worker, string hashFingerprints, uint blockNumber){

        if (!isEndorsements[_endorsementNumber]) {
            return (emptyEndorsement.sender, emptyEndorsement.worker, emptyEndorsement.hashFingerprints, emptyEndorsement.blockNumber);
        }
        EndorsementData[] memory endorsementAraayCurrent = endorsementDatas[_endorsementNumber];
        //Get the index of the endorsement data to be rewarded.
        uint endorsementsIndex = endorsementsIndexs[_endorsementNumber];
        EndorsementData memory endorsementCurrent = endorsementAraayCurrent[endorsementsIndex];
        string memory hashFingerprintsCurrent = endorsementCurrent.hashFingerprints;
        return (endorsementCurrent.sender, endorsementCurrent.worker, hashFingerprintsCurrent, endorsementCurrent.blockNumber);

    }

    /**
    * get Endorsement By Index
    * @param _endorsementNumber   Endorsement number
    * @param _index   Endorsement index
    * @return  Endorsement data
    */
    function getEndorsementByIndex(uint _endorsementNumber, uint _index) public view returns (address sender, address worker, string hashFingerprints, uint blockNumber){
        EndorsementData[] memory endorsementAraayCurrent = endorsementDatas[_endorsementNumber];
        EndorsementData memory endorsementCurrent = endorsementAraayCurrent[_index];
        string memory hashFingerprintsCurrent = endorsementCurrent.hashFingerprints;
        return (endorsementCurrent.sender, endorsementCurrent.worker, hashFingerprintsCurrent, endorsementCurrent.blockNumber);

    }

    /**
    * get Endorsement Senders
    * @param _endorsementNumber   Endorsement number
    * @return  address[]      Endorsement  Senders
    */
    function getEndorsementSendersAll(uint _endorsementNumber) public view returns (address[]){
        return endorsementSendersAll[_endorsementNumber];
    }

    function getlocks(uint _section) public view returns (address[]){
        return locks[_section];
    }

    /**
    * According to the Endorsement number and endorsement data , to get the endorsement senders.
    * @param _endorsementNumber   Endorsement number
    * @param _hash  Endorsement data
    * @return  address[]   Endorsement  Senders
    */
    function getEndorsementSenders(uint _endorsementNumber, string _hash) public view returns (address[]){
        return endorsementSenders[_endorsementNumber][_hash];
    }

    /**
   * According to the Endorsement number and endorsement data , to get the endorsement count.
   * @param _endorsementNumber   Endorsement number
   * @param _hash  Endorsement data
   * @return  uint   Endorsement count
   */
    function getHashEndorsementCounter(uint _endorsementNumber, string _hash) public view returns (uint){
        return hashEndorsementCounter[_endorsementNumber][_hash];
    }

    /**
    * Contract deposit
    * @return  bool  Returns true on success and false on failure.
    */
    function deposit() payable public returns (bool){
        emit Deposit(msg.value);
        return true;
    }

    /**
    * View contract balance
    * @return  uint Contract balance
    */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
    * string keccak256 to bytes32
    * @return  bytes32   data of fingerprints
    */
    function strToBytes32(string _str) public pure returns (bytes32){
        return keccak256(abi.encodePacked(_str));
    }
}

/**
 * SafeMath
 */
library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }

    function mod(uint256 a, uint256 b) external pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

/**
 *  WTC permissionContract interface
 */
contract PermissionContract {

    function getSMNAddress(address workerAddress) public view returns (address, bool);

}
