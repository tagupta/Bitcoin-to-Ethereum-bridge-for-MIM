// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import '@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol';

contract Stub_addressProvider is Initializable{
    using Address for * ;
    address registry;
    address public admin;

    struct AddressInfo{
        address addr;
        bool is_active;
        uint256 version;
        uint256 last_modified;
        string description;
    }
    uint256 queue_length;
    mapping(uint256 => AddressInfo) public get_id_info;


    function initialize(address _admin)public initializer{
       admin = _admin;
       queue_length = 1;
       get_id_info[0].description = "Main Registry";
    }

    function get_registry() external view returns(address){
        return registry;
    }

    function set_address(uint256 _id, address _address) external returns(bool){

        require(msg.sender == admin,'Stub_addressProvider: admin-only function');
        require(Address.isContract(_address),'Stub_addressProvider: not a contract');
        require(queue_length > _id,'Stub_addressProvider: id does not exist');
        
        uint256 version = get_id_info[_id].version + 1;

        get_id_info[_id].addr = _address;
        get_id_info[_id].is_active = true;
        get_id_info[_id].version = version;
        get_id_info[_id].last_modified = block.timestamp;

        if (_id == 0){
         registry = _address;
        }
        
        return true;
    }
}