// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

interface ICurveGauge{
    function balanceOf(address arg0) external view returns (uint256);
    function deposit(uint256 _value) external;
    function withdraw(uint256 _value) external;
}

interface IDeposit{
 function isShutdown() external view returns(bool);
}

contract Stub_CurveVoterProxy is Initializable{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public owner;
    address public operator;
    
    function initialize() public initializer{
        owner = msg.sender;
    }
    
    function setOperator(address _operator) external {
        require(msg.sender == owner, "!auth");
        require(operator == address(0) || IDeposit(operator).isShutdown() == true, "needs shutdown");
        
        operator = _operator;
    }

    function deposit(address _token, address _gauge) external returns(bool){
        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(_token).safeApprove(_gauge, 0);
            IERC20(_token).safeApprove(_gauge, balance);
            ICurveGauge(_gauge).deposit(balance);
        }
        return true;
    }

    function withdraw(address _token, address _gauge, uint256 _amount) public returns(bool){
        require(msg.sender == operator, "!auth");
        uint256 _balance = IERC20(_token).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_gauge, _amount.sub(_balance));
            _amount = _amount.add(_balance);
        }
        IERC20(_token).safeTransfer(msg.sender, _amount);
        return true;
    }

    function withdrawAll(address _token, address _gauge) external returns(bool){
        require(msg.sender == operator, "!auth");
        uint256 amount = balanceOfPool(_gauge);
        withdraw(_token, _gauge, amount);
        return true;
    }

    function _withdrawSome(address _gauge, uint256 _amount) internal returns (uint256) {
        ICurveGauge(_gauge).withdraw(_amount);
        return _amount;
    }

    function balanceOfPool(address _gauge) public view returns (uint256){
        return ICurveGauge(_gauge).balanceOf(address(this));
    }

}

