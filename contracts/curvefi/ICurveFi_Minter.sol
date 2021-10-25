// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.4.22 <0.9.0;

interface ICurveFi_Minter{

    function mint(address gauge_addr) external;
    function minted(address arg0, address arg1) external view returns(uint256);

    function toggle_approve_mint(address minting_user) external;
    function token() external view returns(address);

}