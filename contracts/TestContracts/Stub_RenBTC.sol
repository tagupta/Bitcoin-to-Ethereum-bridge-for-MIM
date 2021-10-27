// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Stub_RenBTC is ERC20{
    constructor() ERC20('renBTC','renBTC'){
    }
    function mint(address _to, uint _value) external {
       _mint(_to,_value);
    }
}
