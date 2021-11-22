// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import '@renproject/gateway-sol/contracts/Gateway/GatewayFactory.sol';

contract Stub_GatewayFactory is GatewayFactory{

    constructor(address _mintAuthority, 
                string memory _chainName)
                GatewayFactory(_mintAuthority, _chainName)public{}
}
