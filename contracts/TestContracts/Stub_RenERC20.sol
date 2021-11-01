// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../curvefi/IRenERC20.sol';

contract Stub_RenERC20 is ERC20{
   
    uint public exchangeRateStored;
    uint constant EXP_SCALE = 1e18;
    uint constant INITIAL_RATE = 1 * EXP_SCALE;
    uint prev_time;
    address underlying;

    
    constructor() ERC20('RenTokens','renBTC/wBTC'){
    }
    
    function mint(address _to, uint _value) external {
       _mint(_to,_value);
    }
    
    function initialize(address _underlying) public{
        exchangeRateStored = 10 ** 18;
        underlying = _underlying;
        prev_time = block.timestamp;
    }

    function set_exchange_rate(uint rate) public {
        exchangeRateStored = rate;
    }

    function exchangeRateCurrent() public view returns(uint){
        return _exchangeRate(); //exchangeRateStored
    }

    function _exchangeRate() internal view returns(uint){
        uint sec = block.timestamp - prev_time + 10;
        return INITIAL_RATE + (INITIAL_RATE * sec / 365 days / EXP_SCALE);
    }

}