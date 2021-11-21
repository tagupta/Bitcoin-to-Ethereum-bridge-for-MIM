// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
//import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";

import '../curvefi/IRenERC20.sol';

contract Stub_RenERC20 is IRenERC20, Initializable, Context, ERC20, ERC20Detailed{
   
    uint public exchangeRateStored;
    uint constant EXP_SCALE = 1e18;
    uint constant INITIAL_RATE = 1 * EXP_SCALE;
    uint prev_time;
    ERC20Mintable public underlying;

    
    // constructor() ERC20('RenTokens','renBTC/wBTC'){
    // }
    
    // function mint(address _to, uint _value) external {
    //    _mint(_to,_value);
    // }
    
    function initialize(address _underlying,string memory symb, uint8 uDecimals,uint256 _supply) public initializer {
        exchangeRateStored = 10 ** 18;
        ERC20Detailed.initialize("renPoolTokens", symb, uDecimals);
        underlying = ERC20Mintable(_underlying);
        prev_time = block.timestamp;
        _mint(_msgSender(), _supply);
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