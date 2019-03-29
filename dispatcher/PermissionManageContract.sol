pragma solidity ^0.5.0;

import "./IPermissionManageContract.sol";

// permission manage contract
contract PermissionManageContract is IPermissionManageContract {

    struct PermissionInfoStruct {
        address userAddress;
        Role role;
        bool isValid;
    }
    
    PermissionInfoStruct internal emptyPermission = PermissionInfoStruct(address(0x0), Role.WORKER, false);
    
    // contract owner
    address public owner;
    
    // permission list (userAddress => index)
    PermissionInfoStruct[] public permissions;
    mapping(address => uint) public permissionMapping;
    
    // WORKER address => SMN index
    mapping(address => uint) public smnMapping;
    
    modifier AdminPermission() {
        require(msg.sender == owner, "sender must be owner");
        _;
    }
    
    constructor(address _owner) public {
        owner = _owner;
        permissions.push(emptyPermission);
    }
    
    function addPermission(address userAddress, Role role, uint smnIndex) public AdminPermission {
        require(permissionMapping[userAddress] == 0 && (Role.WORKER != role || permissions[smnIndex].role == Role.SMN));
        PermissionInfoStruct memory permission = PermissionInfoStruct(userAddress, role, true);
        permissions.push(permission);
        permissionMapping[userAddress] = permissions.length - 1;
        if (Role.WORKER == role) {
            smnMapping[userAddress] = smnIndex;
        }
    }
    
    function getPermission(address userAddress) external view returns(address, Role, bool) {
        PermissionInfoStruct memory permission = permissions[permissionMapping[userAddress]];
        if (!permission.isValid) {
            return permissionInfo2MultipleReturns(emptyPermission);
        }
        return permissionInfo2MultipleReturns(permission);
    }
    
    function permissionSize() public view returns(uint) {
        return permissions.length;
    }
    
    function permissionInfo2MultipleReturns(PermissionInfoStruct memory permission) internal pure returns(address userAddress, Role role, bool isValid) {
        return (permission.userAddress, permission.role, permission.isValid);
    }
    
    function deletePermission(uint index) public AdminPermission {
        permissions[index].isValid = false;
    }
    
    function getSMNAddress(address workerAddress) public view returns(address, bool) {
        PermissionInfoStruct memory workerPermission = permissions[permissionMapping[workerAddress]];
        PermissionInfoStruct memory smnPermission = permissions[smnMapping[workerAddress]];
        if (!(workerPermission.isValid && smnPermission.isValid && (workerPermission.role == Role.WORKER) && (smnPermission.role == Role.SMN))) {
            return (address(0x0), false);
        }
        return (smnPermission.userAddress, true);
    }
}