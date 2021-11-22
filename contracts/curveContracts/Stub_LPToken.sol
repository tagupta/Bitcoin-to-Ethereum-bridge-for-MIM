// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";


contract Stub_LPToken is Initializable, Context, ERC20, ERC20Detailed, ERC20Mintable, ERC20Burnable {

    function initialize() public initializer {
        ERC20Mintable.initialize(_msgSender());
        ERC20Detailed.initialize("Curve.fi renBTC/wBTC", "renDAI+wBTC", 18);
    }

    // function mint(address _to, uint _value) external {
    //    _mint(_to,_value);
    // }

    // function burn(address _from, uint _value) external{
    //     _burn(_from, _value);
    // }
}
