// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../curvefi/ICurveFi_Minter.sol";
import "../curvefi/ICurveFi_Gauge.sol";

contract Stub_CurveFi_Gauge is ICurveFi_Gauge, Initializable, Context{
    using SafeMath for uint256;

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
    mapping(address => mapping(address => bool)) public approved_to_deposit;
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
        _update_liquidity_limit(addr, balanceOf[addr],totalSupply); // totalsupply - 3rd parameter
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

    function _update_liquidity_limit(address addr, uint l, uint L)public{
        uint lim = l * TOKENLESS_PRODUCTION / 100;
        uint old_bal = working_balances[addr];
        working_balances[addr] = lim;
        working_supply = working_supply + lim - old_bal;
        L+=1; //using L just to avoid warning
    }

    function deposit(uint _value) public {
      _checkpoint(_msgSender());

      if (_value != 0){
        balanceOf[_msgSender()] = balanceOf[_msgSender()].add(_value);
        totalSupply = totalSupply.add(_value);

        _update_liquidity_limit(_msgSender(),  balanceOf[_msgSender()], totalSupply);

        IERC20(__lp_token).transferFrom(_msgSender(), address(this), _value);
      }
        
    }

    function deposit(uint256 _value, address addr) public{
        if(addr != _msgSender()){
            require(approved_to_deposit[_msgSender()][addr], "Not approved to deposit for other address");
        }
         _checkpoint(addr);

         if(_value != 0){
             uint256 _balance = balanceOf[addr].add(_value);
             uint256 _supply = totalSupply.add(_value);
             balanceOf[addr] = _balance;
             totalSupply = _supply;

             _update_liquidity_limit(addr, _balance, _supply);

             IERC20(__lp_token).transferFrom(_msgSender(), address(this), _value);
         }
    }

    function withdraw(uint _value)public {
        _checkpoint(_msgSender());
        balanceOf[_msgSender()] = balanceOf[_msgSender()].sub(_value);
        totalSupply = totalSupply.sub(_value);

        _update_liquidity_limit(_msgSender(), balanceOf[_msgSender()], totalSupply);
        
        IERC20(__lp_token).transfer(_msgSender(), _value);
    }

    function claimable_tokens(address addr)public returns(uint){
        _checkpoint(addr);
        return __integrate_fraction[addr] - ICurveFi_Minter(__minter).minted(addr, address(this));
    }

    function minter() public view returns(address) {
        return __minter;
    }

    function crv_token() public view returns(address) {
        return __crv_token;
    }

    function lp_token() public view returns(address) {
        return __lp_token;
    }

    function integrate_fraction(address _for) public view returns(uint256) {
        return __integrate_fraction[_for];
    }

    function set_approve_deposit(address addr,bool can_deposit)public{
        approved_to_deposit[addr][_msgSender()] = can_deposit;
    }

}