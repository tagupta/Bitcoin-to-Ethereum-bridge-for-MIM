// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Stub_DepositToken.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";

contract Stub_TokenFactory is Initializable{
    address public operator;

    function initialize(address _operator)public initializer{
       operator = _operator;
    }

    function CreateDepositToken(address _lptoken) external returns(address){
        require(msg.sender == operator, "Stub_TokenFactory: !authorized");
        Stub_DepositToken dtoken = new Stub_DepositToken();
        dtoken.initialize(operator, _lptoken);
        return address(dtoken);
    }
}