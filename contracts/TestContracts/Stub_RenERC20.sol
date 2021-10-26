// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../curvefi/IRenERC20.sol';

contract Stub_RenERC20 is ERC20{

    constructor() ERC20('RenTokens','renBTC/wBTC'){
    }
}