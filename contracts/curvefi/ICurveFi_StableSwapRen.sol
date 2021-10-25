// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.4.22 <0.9.0;

interface ICurveFi_StableSwapRen{

    function add_liquidity(uint256[2] calldata amounts, uint256 min_mint_amount) external;
    function remove_liquidity(uint256 _amount, uint256[2] calldata min_amounts) external;
    function remove_liquidity_imbalance(uint256[2] calldata amounts, uint256 max_burn_amount) external;
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;

    function coins(int128 arg0) external view returns(address);
    function balances(int128 arg0) external view returns(uint256);
    
}