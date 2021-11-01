// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.4.22 <0.9.0;

interface IRenERC20{
    
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function exchangeRateCurrent() external view returns(uint);
    function set_exchange_rate(uint rate) external;
}
