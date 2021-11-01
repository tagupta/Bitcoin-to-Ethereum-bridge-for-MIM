// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '../curvefi/ICurveFi_StableSwapRen.sol';
import '../curvefi/IRenERC20.sol';
import './Stub_LPToken.sol';

contract Stub_CurveFi_Swap is ICurveFi_StableSwapRen,Initializable,Context{
    
    uint256 public constant N_COINS = 2;
    uint256 constant MAX_EXCHANGE_FEE = 0.05*1e18;

    address public __token;
    uint256[N_COINS] public __balances;
    address[N_COINS] public __coins;
    uint256 public __fee;

    function initialize(address[N_COINS] memory _coins, address _pool_token, uint256 _fee )public initializer {
        for (uint256 i = 0; i < N_COINS; i++) {
            require(_coins[i]!= address(0),'Coin address can not be zero');
            __coins[i] = _coins[i];
        }
        __token = _pool_token;
        __fee = _fee;
    }

    function add_liquidity(uint256[N_COINS] memory amounts, uint256 min_mint_amount) public override{
        uint256 mint_amount = calculateMintAmount(amounts);
        require(mint_amount >= min_mint_amount,'Min mint amount failed');
        
        //Transfer tokens from sender to this contract
        for(uint i = 0 ; i < N_COINS ; i++){
          IRenERC20(__coins[i]).transferFrom(_msgSender(), address(this), amounts[i]);
        }
      
        Stub_LPToken(__token).mint(_msgSender(), mint_amount);
    }

    function remove_liquidity (uint256 _amount, uint256[N_COINS] memory min_amounts) public override{
        uint256 total_supply = IERC20(__token).totalSupply();
        uint256[] memory amounts = new uint256[](__coins.length);

        for (uint256 i=0; i < __coins.length; i++){
            uint256 value = __balances[i];
            amounts[i] = (_amount * value )/total_supply;
            require(amounts[i] >= min_amounts[i], "Min withdraw amount failed");
            IRenERC20(__coins[i]).transfer(_msgSender(), amounts[i]);
        }
        Stub_LPToken(__token).burn(_msgSender(), _amount);
    }

    function remove_liquidity_imbalance(uint256[N_COINS] memory amounts, uint256 max_burn_amount) public override{
        uint256 total_supply = IERC20(__token).totalSupply();
        require(total_supply > 0, "Nothing to withdraw");

        uint256 token_amount = change_token_amount_with_fees(amounts, false);

        for (uint256 i=0; i < N_COINS; i++){
            if(amounts[i] > 0){
                IRenERC20(__coins[i]).transfer(_msgSender(), amounts[i]);
            }
        }

        require(max_burn_amount == 0 || token_amount <= max_burn_amount, "Min burn amount failed");
        Stub_LPToken(__token).burn(_msgSender(), token_amount);
    }

    function calculateMintAmount(uint256[N_COINS] memory amounts)internal returns(uint256){
        uint256 mint_amount;

        if(IERC20(__token).totalSupply() > 0){
            mint_amount = change_token_amount_with_fees(amounts, true);
        }
        else{
           uint total;
           for(uint i = 0 ; i < N_COINS ; i++){
                __balances[i] += amounts[i];
                total += normalize(__coins[i], amounts[i]);
           }
            mint_amount = total;
        }

        return mint_amount;
    }

    function calc_token_amount(uint256[N_COINS] memory amounts, bool deposit) public view returns(uint256) {

        uint256[4] memory _balances;
        uint256 total;
        for (uint256 i = 0; i < N_COINS; i++) {
            _balances[i] = __balances[i];
            if (deposit)
                _balances[i] += amounts[i];
            else
                _balances[i] -= amounts[i];
            total += normalize(__coins[i], amounts[i]);
        }
        return total;
    }

    function change_token_amount_with_fees(uint256[N_COINS] memory amounts, bool deposit) internal returns(uint){
        uint256[N_COINS] memory new_balances;
        uint256[N_COINS] memory old_balances;

        for(uint i = 0 ; i < N_COINS ; i++){
            old_balances[i] = __balances[i];
        }

        // D0 = self.get_D_mem(rates, old_balances, amp)
        uint256 total;
        for (uint i = 0; i < N_COINS; i++) {
            if (deposit)
                new_balances[i] = old_balances[i] + amounts[i];
            else
                new_balances[i] = old_balances[i] - amounts[i];

            total += normalize(__coins[i], amounts[i]);
        }

        //D1: uint256 = self.get_D_mem(rates, new_balances)
        uint256 _fee = __fee * N_COINS / (4 * (N_COINS - 1));
        for (uint i = 0; i < N_COINS; i++) {
            uint256 ideal_balance = old_balances[i] * 9900 / 10000;//D1 * old_balances[i] / D0;
            uint256 difference;
            if (ideal_balance > new_balances[i])
                difference = ideal_balance - new_balances[i];
            else
                difference = new_balances[i] - ideal_balance;

            uint256 feee = _fee * difference / (10 ** 10);
            new_balances[i] = new_balances[i] - feee;
        }

        // D2: uint256 = self.get_D_mem(rates, new_balances)
        for (uint i = 0; i < N_COINS; i++) {
            __balances[i] = new_balances[i];
        }
        return total;
    }

    function normalize(address coin, uint amount) internal view returns(uint result){
        uint8 decimal  = ERC20(coin).decimals();
        if(decimal == 18){
            result =  amount; 
        }
        else if(decimal > 18){
            result =  amount / 10 ** (decimal-18);
        }
        else if(decimal < 18){
            result = amount * 10 ** (18-decimal);
        }
    }

    function balances(int128 i) public view override returns(uint256) {
        return __balances[uint(uint128(i))];//IERC20(__coins[uint256(i)]).balanceOf(address(this));
    }

    function fee() public view returns(uint256) {
        return __fee;
    }

    function coins(int128 i) public view override returns (address) {
        return __coins[uint(uint128(i))];
    }

}