// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.4.22 <0.9.0;

interface ICurveFi_Gauge{

    function lp_token() external view returns(address);
    function crv_token() external view returns(address);
 
    function balanceOf(address arg0) external view returns (uint256);

    // function deposit(uint256 _value, address addr) external;
    function deposit(uint256 _value) external;

    function withdraw(uint256 _value) external;

    function claimable_tokens(address addr) external returns (uint256);
    function minter() external view returns(address); //use minter().mint(gauge_addr) to claim CRV

    function integrate_fraction(address arg0) external view returns(uint256);
    function user_checkpoint(address addr) external returns(bool);
}