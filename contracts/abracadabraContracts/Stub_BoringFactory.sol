// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

interface IMasterContract{
       function init(bytes calldata data) external payable;
}

contract Stub_BoringFactory{
 mapping(address => address) public masterContractOf;

//     function deploy(
//         address masterContract,
//         bytes calldata data,
//         bool useCreate2
//     ) public payable returns (address cloneAddress) {
//         require(masterContract != address(0), "BoringFactory: No masterContract");
//         bytes20 targetBytes = bytes20(masterContract); //Takes the first 20 bytes of the masterContract's address

//         if (useCreate2) {
//             bytes32 salt = keccak256(data);
//             assembly {
//                 let clone := mload(0x40)
//                 mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
//                 mstore(add(clone, 0x14), targetBytes)
//                 mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
//                 cloneAddress := create2(0, clone, 0x37, salt)
//             }
//         } else {
//             assembly {
//                 let clone := mload(0x40)
//                 mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
//                 mstore(add(clone, 0x14), targetBytes)
//                 mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
//                 cloneAddress := create(0, clone, 0x37)
//             }
//         }
//         masterContractOf[cloneAddress] = masterContract;

//         IMasterContract(cloneAddress).init{value: msg.value}(data);
//     }
}