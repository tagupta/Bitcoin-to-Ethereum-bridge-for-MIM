// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import './Stub_CRVToken.sol';
import "../curvefi/ICurveFi_Minter.sol";
import "../curvefi/ICurveFi_Gauge.sol";

contract Stub_CurveFi_Minter is ICurveFi_Minter, Initializable, Context{
    // user -> gauge -> value
    mapping(address => mapping(address => uint)) __minted;
    // minter -> user -> can mint?
    mapping(address => mapping(address => bool)) allowed_to_mint_for;
    //CRV token
    address public __token;

    function initialize(address _token)public{
        __token = _token;
    }

    function mint(address gauge_addr) public override{
        _mint_for(gauge_addr, _msgSender());
    }

    function mint_for(address gauge_addr, address _for) public override{
        if (allowed_to_mint_for[_msgSender()][_for]){
           _mint_for(gauge_addr, _for);
        }
    }

    function toggle_approve_mint(address minting_user) public override{
      allowed_to_mint_for[minting_user][_msgSender()] = !allowed_to_mint_for[minting_user][_msgSender()];
    }

    function token() public view override returns(address) {
        return __token;
    }

    function minted(address _for, address gauge_addr) public view override returns(uint256) {
        return __minted[_for][gauge_addr];
    }

    function _mint_for(address gauge_addr, address _for)internal {
        ICurveFi_Gauge(gauge_addr).user_checkpoint(_for);
        uint total_mint = ICurveFi_Gauge(gauge_addr).integrate_fraction(_for);
        uint to_mint = total_mint - __minted[_for][gauge_addr];
        
        if(to_mint != 0){
            Stub_CRVToken(__token).mint(_for, to_mint);
            __minted[_for][gauge_addr] = total_mint;
        }
    }
    
 
    

    
}