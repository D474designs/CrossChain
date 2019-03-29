pragma solidity ^0.5.0;

// template manage contract
contract TemplateManageContract {
    
    // contract template info
    struct ContractTemplate {
        bytes32 hash;
        string name;
        string description;
        bytes bytecode;
        string abi;
        string version;
        bool hasBusinessContract;
        bool isValid;
    }
    
    ContractTemplate internal emptyContractTemplate = ContractTemplate("", "", "", "", "", "", false, false);
    
    // contract owner
    address public owner;

    // hash => index
    mapping(bytes32 => uint) public contractTemplateMapping;
    ContractTemplate[] public contractTemplates;
    
    modifier AdminPermission() {
        require(msg.sender == owner, "sender must be owner");
        _;
    }
    
    event deployContractEvent(string indexed key, uint indexed index, address indexed contractAddress);
    
    constructor(address _owner) public {
        owner = _owner;
        contractTemplates.push(emptyContractTemplate);
    }
    
    function addContractTemplate(
        bytes32 _hash,
        string memory _name,
        string memory _description,
        bytes memory _bytecode,
        string memory _abi,
        string memory _version,
        bool _hasBusinessContract
        ) public AdminPermission {
        require(contractTemplateMapping[_hash] == 0);
        ContractTemplate memory contractTemplate = ContractTemplate(_hash, _name, _description, _bytecode, _abi, _version, _hasBusinessContract, true);
        contractTemplates.push(contractTemplate);
        contractTemplateMapping[_hash] = contractTemplates.length - 1;
    }
    
    function getContractTemplate(bytes32 hash) public view returns(bytes32 _hash, string memory _name, string memory _description, bytes memory _bytecode, string memory _abi, string memory _version, bool _hasBusinessContract, bool _isValid) {
        ContractTemplate memory contractTemplate = contractTemplates[contractTemplateMapping[hash]];
        if (!contractTemplate.isValid) {
            return contractTemplate2MultipleReturns(emptyContractTemplate);
        }
        return contractTemplate2MultipleReturns(contractTemplate);
    }
    
    function contractTemplate2MultipleReturns(ContractTemplate memory contractTemplate) internal pure returns(bytes32 _hash, string memory _name, string memory _description, bytes memory _bytecode, string memory _abi, string memory _version, bool _hasBusinessContract, bool _isValid) {
        return (contractTemplate.hash, contractTemplate.name, contractTemplate.description, contractTemplate.bytecode, contractTemplate.abi, contractTemplate.version, contractTemplate.hasBusinessContract, contractTemplate.isValid);
    }
    
    function deleteContractTemplate(uint index) public AdminPermission {
        contractTemplates[index].isValid = false;
    }
    
    function contractTemplateSize() public view returns(uint) {
        return contractTemplates.length;
    }
    
    address[] public contractAddressList;
    
    function deployContract(string memory key, uint index, address _owner) public AdminPermission {
       bytes memory bytecode = contractTemplates[index].bytecode;
       bytes memory bytecodeWithAddress = splice(bytecode, _owner);
       address deployContractAddress;
       assembly {
           deployContractAddress := create(0, add(bytecodeWithAddress, 0x20), mload(bytecodeWithAddress))
       }
       contractAddressList.push(deployContractAddress);
       emit deployContractEvent(key, index, deployContractAddress);
    }

    // splice bytes and address(convert address to 32 bytes, front fill zero)
    function splice(bytes memory rawBytecode, address _address) internal pure returns(bytes memory) {
        bytes memory bytecode = new bytes(rawBytecode.length + 32);
        bytes memory addressBytes = toBytes(_address);
        for (uint i = 0; i < rawBytecode.length; i++) {
            bytecode[i] = rawBytecode[i];
        }
        for (uint i = 0; i < addressBytes.length; i++) {
            bytecode[rawBytecode.length + 12 + i] = addressBytes[i];
        }
        return bytecode;
    }
    
    // convert address to bytes
    function toBytes(address _address) internal pure returns(bytes memory _bytes) {
        assembly {
            let m := mload(0x40)
            mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, _address))
            mstore(0x40, add(m, 52))
            _bytes := m
        }
    }
}
