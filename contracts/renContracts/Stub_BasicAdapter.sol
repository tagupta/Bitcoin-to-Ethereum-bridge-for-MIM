// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import '@renproject/gateway-sol/contracts/Gateway/adapters/BasicAdapter.sol';

contract Stub_BasicAdapter is BasicAdapter{

    constructor(IGatewayRegistry _registry) BasicAdapter(_registry)public{}
}