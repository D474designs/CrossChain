pragma solidity ^0.5.0;

// subchain manage contract
contract SubchainManageContract {
    
    // subchain info
    struct SubchainStruct {
        bytes32 genesisHash;
        string name;
        string chainType;
        string subchainNodeIP;
        uint subchainNodePort;
        bool isValid;
    }
    
    // endorsement info
    struct EndorsementStruct {
        string name;
        address endorsementContractAddress;
        string endorsementContractAbi;
        address businessContractAddress;
        string businessContractAbi;
        bool isValid;
    }
    
    // SMN attention
    struct SMNAttention {
        bytes32 subchainGenesisHash;
        bool isValid;
    }
    
    modifier AdminPermission() {
        require(msg.sender == owner, "sender must be owner");
        _;
    }
    
    address internal constant emptyAddress = address(0x0);
    SubchainStruct internal emptySubchain = SubchainStruct("", "", "", "", 0, false);
    EndorsementStruct internal emptyEndorsement = EndorsementStruct("", emptyAddress, "", emptyAddress, "", false);
    SMNAttention internal emptySMNAttention = SMNAttention("", false);
    
    // contract owner
    address public owner;
    
    // genesisHash => index
    mapping(bytes32 => uint) public subchainMapping;
    SubchainStruct[] public subchains;
    // subchainIndex => endorsements
    mapping(uint => EndorsementStruct[]) public endorsements;
    
    // smn address => subchain array
    mapping(address => SMNAttention[]) public smnAttentions;
    
    constructor(address _owner) public {
        owner = _owner;
        subchains.push(emptySubchain);
    }
    
    function addSubchain(bytes32 genesisHash, string memory name, string memory chainType, string memory subchainNodeIP, uint subchainNodePort) public AdminPermission {
        require(subchainMapping[genesisHash] == 0);
        SubchainStruct memory subchain = SubchainStruct(genesisHash, name, chainType, subchainNodeIP, subchainNodePort, true);
        uint index = subchains.length;
        subchains.push(subchain);
        subchainMapping[genesisHash] = index;
    }
    
    function addEndorsement(uint subchainIndex, string memory name, address endorsementContractAddress, string memory endorsementContractAbi, address businessContractAddress, string memory businessContractAbi) public AdminPermission {
        if (subchainIndex >= subchains.length) {
            return;
        }
        EndorsementStruct memory endorsement = EndorsementStruct(name, endorsementContractAddress, endorsementContractAbi, businessContractAddress, businessContractAbi, true);
        endorsements[subchainIndex].push(endorsement);
    }
    
    function getSubchain(bytes32 _genesisHash) public view returns(bytes32 genesisHash, string memory name, string memory chainType, string memory subchainNodeIP, uint subchainNodePort, bool isValid) {
        SubchainStruct memory subchain = subchains[subchainMapping[_genesisHash]];
        if (!subchain.isValid) {
            return subchain2MultipleReturns(emptySubchain);
        }
        return subchain2MultipleReturns(subchain);
    }

    function getEndorsement(uint subchainIndex, uint endorsementIndex) public view returns(string memory name, address endorsementContractAddress, string memory endorsementContractAbi, address businessContractAddress, string memory businessContractAbi, bool isValid) {
        if (subchainIndex >= subchains.length || endorsementIndex >= endorsements[subchainIndex].length) {
            return endorsement2MultipleReturns(emptyEndorsement);
        }
        EndorsementStruct memory endorsement = endorsements[subchainIndex][endorsementIndex];
        return endorsement2MultipleReturns(endorsement);
    }
    
    function subchain2MultipleReturns(SubchainStruct memory subchain) internal pure returns(bytes32 genesisHash, string memory name, string memory chainType, string memory subchainNodeIP, uint subchainNodePort, bool isValid) {
        return (subchain.genesisHash, subchain.name, subchain.chainType, subchain.subchainNodeIP, subchain.subchainNodePort, subchain.isValid);
    }
    
    function endorsement2MultipleReturns(EndorsementStruct memory endorsement) internal pure returns(string memory name, address endorsementContractAddress, string memory endorsementContractAbi, address businessContractAddress, string memory businessContractAbi, bool isValid) {
        return (endorsement.name, endorsement.endorsementContractAddress, endorsement.endorsementContractAbi, endorsement.businessContractAddress, endorsement.businessContractAbi, endorsement.isValid);
    }
    
    function deleteSubchain(uint index) public AdminPermission {
        subchains[index].isValid = false;
    }
    
    function subchainSize() public view returns(uint) {
        return subchains.length;
    }
    
    function endorsementSize(uint subchainIndex) public view returns(uint) {
        return endorsements[subchainIndex].length;
    }
    
    function deleteEndorsement(uint subchainIndex, uint index) public AdminPermission {
        endorsements[subchainIndex][index].isValid = false;
    }
    
    function addSMNAttention(address smnAddress, bytes32 subchainGenesisHash) public AdminPermission {
        SMNAttention memory attention = SMNAttention(subchainGenesisHash, true);
        smnAttentions[smnAddress].push(attention);
    }
    
    function smnAttentionSize(address smnAddress) public view returns(uint) {
        return smnAttentions[smnAddress].length;
    }
    
    function getSMNAttention(address smnAddress, uint attentionIndex) public view returns(bytes32 subchainGenesisHash, bool isValid) {
        if (attentionIndex >= smnAttentions[smnAddress].length) {
            return smnAttention2MultipleReturns(emptySMNAttention);
        }
        return smnAttention2MultipleReturns(smnAttentions[smnAddress][attentionIndex]);
    }
    
    function smnAttention2MultipleReturns(SMNAttention memory attention) internal pure returns(bytes32 subchainGenesisHash, bool isValid) {
        return (attention.subchainGenesisHash, attention.isValid);
    }
    
    function deleteSMNAttention(address smnAddress, uint attentionIndex) public AdminPermission {
        smnAttentions[smnAddress][attentionIndex].isValid = false;
    }
}