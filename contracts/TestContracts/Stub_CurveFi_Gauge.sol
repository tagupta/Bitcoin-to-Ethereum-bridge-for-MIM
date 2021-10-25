// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "../curvefi/ICurveFi_Minter.sol";
import "../curvefi/ICurveFi_Gauge.sol";

contract Stub_CurveFi_Gauge{
   //CRV distribution number
    uint128 period;
    //Simplification to keep timestamp
    uint period_timestamp;
    //CRV Minter contract
    address public __minter;
    //CRV token
    address public __crv_token;
    //LP-token from Curve pool
    address public __lp_token;
    uint public totalSupply;

    mapping(address => uint) public balanceOf;
    //Total shares of CRV for the user
    mapping(address => uint) public __integrate_fraction;
    mapping (uint256 => uint) public integrate_inv_supply;
    mapping(address => uint) public integrate_inv_supply_of;
    mapping(address => uint) public integrate_checkpoint_of;
    
    mapping(address => uint) public working_balances;
    uint public working_supply; 

    uint public constant TOKENLESS_PRODUCTION = 40;
    //Rate taken from CRV
    uint public constant YEAR = 365 * 24 * 60 * 60;
    uint public constant INITIAL_RATE = (274_815_283 * (10 ** 18)) / YEAR;

    function initialize(address lp_addr, address _minter) public {
        __minter = _minter;
        __lp_token = lp_addr;

        __crv_token = ICurveFi_Minter(_minter).token();
        period_timestamp = block.timestamp;
    }

    function user_checkpoint(address addr)public returns(bool){
        require(msg.sender == addr || msg.sender == __minter, "Unauthorized minter");
        _checkpoint(addr);
        _update_liquidity_limit(addr, balanceOf[addr]); // totalsupply - 3rd parameter
        return true;
    }

    function _checkpoint(address addr)internal{
        uint _integrate_inv_supply = integrate_inv_supply[period];
        uint _working_balance = working_balances[addr];
        uint _working_supply = working_supply;

        if(block.timestamp > period_timestamp){
            uint dt = block.timestamp - period_timestamp;
            if(_working_supply > 0){
                 _integrate_inv_supply += INITIAL_RATE * dt / _working_supply;
            }
        }
        _integrate_inv_supply += 2;
        period += 1;
        period_timestamp = block.timestamp;
        integrate_inv_supply[period] = _integrate_inv_supply;
        __integrate_fraction[addr] += _working_balance * (_integrate_inv_supply - integrate_inv_supply_of[addr]) / 10 ** 18;
        integrate_inv_supply_of[addr] = _integrate_inv_supply;
        integrate_checkpoint_of[addr] = block.timestamp;
    }

    function _update_liquidity_limit(address addr, uint l)public{
        uint lim = l * TOKENLESS_PRODUCTION / 100;
        uint old_bal = working_balances[addr];
        working_balances[addr] = lim;
        working_supply = working_supply + lim - old_bal;
    }

}