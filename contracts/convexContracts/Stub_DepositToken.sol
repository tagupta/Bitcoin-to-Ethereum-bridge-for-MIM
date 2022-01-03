// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
// import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
// import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";

contract Stub_DepositToken is ERC20, ERC20Detailed{
    address public operator;
    function initialize(address _operator, address _lptoken) public initializer {
        //ERC20Mintable.initialize(_operator);
        ERC20Detailed.initialize(string(abi.encodePacked(ERC20Detailed(_lptoken).name()," Convex Deposit")),
                                 string(abi.encodePacked("cvx", ERC20Detailed(_lptoken).symbol())),18);
        operator = _operator;         
    }

    function mint(address _to, uint256 _amount) external {
        require(msg.sender == operator, "!authorized");
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        require(msg.sender == operator, "Stub_DepositToken: !authorized");
        _burn(_from, _amount);
    }
}