// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Stub_WBTC is ERC20{
    constructor() ERC20('wBTC','wBTC'){
    }
    function mint(address _to, uint _value) external {
       _mint(_to,_value);
    }
}
