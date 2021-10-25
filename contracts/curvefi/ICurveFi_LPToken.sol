// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.4.22 <0.9.0;

interface ICurveFi_LPToken{

    function set_minter(address _minter) external;
    function totalSupply() external returns(uint256 out);
    function allowance(address _owner, address _spender) external returns(uint256 out);
    function transfer(address _to, uint256 _value) external returns(bool out);
    function transferFrom(address _from,address _to,uint256 _value) external returns(bool out);
    
}