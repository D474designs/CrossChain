pragma solidity ^0.5.0;

// permission manage contract interface
contract IPermissionManageContract {
    
    enum Role{JMN, SMN, WORKER}
    
    function getPermission(address userAddress) external view returns(address, Role, bool);
}