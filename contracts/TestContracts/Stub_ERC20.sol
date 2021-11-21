// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";

contract Stub_ERC20 is ERC20, ERC20Detailed, ERC20Mintable {
    function initialize(string memory _name, string memory _symbol, uint8 _decimals) public initializer {
        ERC20Detailed.initialize(_name, _symbol, _decimals);
        ERC20Mintable.initialize(_msgSender());
    }

}