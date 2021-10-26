// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Stub_ERC20 is ERC20{
    constructor(uint _value)ERC20('Stub_ERC20','sERC20'){
        _mint(msg.sender,_value);
    }
}