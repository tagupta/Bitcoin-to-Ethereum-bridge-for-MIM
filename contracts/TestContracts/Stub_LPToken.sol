// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';


contract Stub_LPToken is ERC20Burnable{

    constructor() ERC20('Curve.fi LP Token','LPT'){
    }

    function mint(address _to, uint _value) external {
       _mint(_to,_value);
    }

    function burn(address _from, uint _value) external{
        _burn(_from, _value);
    }
}
