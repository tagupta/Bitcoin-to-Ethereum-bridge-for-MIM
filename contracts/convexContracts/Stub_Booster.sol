// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
import "./Stub_DepositToken.sol";

interface IRegistry{ 
    function get_registry() external view returns(address);
    function get_lp_token(address) external view returns(address);
    function get_gauges(address) external view returns(address[10] memory);
}

interface ITokenFactory{
    function CreateDepositToken(address) external returns(address);
}

interface IStaker{
    function deposit(address, address) external;
    function withdraw(address, address, uint256) external;
    function withdrawAll(address, address) external;
    function balanceOfPool(address) external view returns (uint256);
    function operator() external view returns (address);
}

interface IRewards{
    function stake(address, uint256) external;
    function stakeFor(address, uint256) external;
    function withdraw(address, uint256) external;
    function exit(address) external;
    function getReward(address) external;
    function queueNewRewards(uint256) external;
    function notifyRewardAmount(uint256) external;
    function addExtraReward(address) external;
}

interface ITokenMinter{
    function mint(address,uint256) external;
    function burn(address,uint256) external;
}

contract Stub_Booster is Initializable{
    
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public owner;
    address public staker;
    address public tokenFactory;
    address public registry; // address provider
    bool public isShutdown;

    struct PoolInfo {
        address lptoken;
        address token;
        address gauge;
        address crvRewards;
        address stash;
    }
    PoolInfo[] public poolInfo;

    function initialize(address _staker,address _registry)public initializer{
        isShutdown = false;
        staker = _staker;
        owner = msg.sender;
        registry = _registry;
    }

    function setFactories(address _tfactory) external {
        require(msg.sender == owner, "Stub_Booster: !auth");
        tokenFactory = _tfactory;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function addPool(address _swap, address _gauge, uint256 _stashVersion) external{
        address mainReg = IRegistry(registry).get_registry();
        //get lp token and gauge list from swap address
        address lptoken = IRegistry(mainReg).get_lp_token(_swap);
        address[10] memory gaugeList = IRegistry(mainReg).get_gauges(_swap);
       
        bool found = false;
        for(uint256 i = 0; i < gaugeList.length; i++){
            if(gaugeList[i] == _gauge){
                found = true;
                break;
            }
        }
        require(found, "Stub_Booster: !registry");
        
        //now make sure this pool/gauge hasn't been added before
        found = false;
        for(uint256 i = 0; i < poolInfo.length; i++){
            if(poolInfo[i].gauge == _gauge){
                found = true;
                break;
            }
        }
        require(!found, "Stub_Booster: pool already registered");

        // uint256 pid = poolInfo.length;

        //create a tokenized deposit
        address token = ITokenFactory(tokenFactory).CreateDepositToken(lptoken);

        //add the new pool
        poolInfo.push( PoolInfo({lptoken: lptoken,
                                 token: token,
                                 gauge: _gauge,
                                 crvRewards: address(0),
                                 stash: address(0)}));
        _stashVersion += 1;
    }

    //stake coins on curve's gauge contracts via the staker account
    function sendTokensToGauge(uint256 _pid) private {
        address token = poolInfo[_pid].lptoken;
        uint256 bal = IERC20(token).balanceOf(address(this));

        //send to proxy to stake
        IERC20(token).safeTransfer(staker, bal);

        //stake
        address gauge = poolInfo[_pid].gauge;
        require(gauge != address(0),"Stub_Booster: !gauge setting");
        IStaker(staker).deposit(token,gauge);
    }

     //deposit lp tokens and stake
    function deposit(uint256 _pid, uint256 _amount, bool _stake) public returns(bool){
        require(!isShutdown,"shutdown");
        address lptoken = poolInfo[_pid].lptoken;
        IERC20(lptoken).safeTransferFrom(msg.sender, address(this), _amount);

        //move to curve gauge
        sendTokensToGauge(_pid);

        address token = poolInfo[_pid].token;
        //uint256 balance;
        if(_stake){
            //mint here and send to rewards on user behalf
            ITokenMinter(token).mint(address(this),_amount);
            address rewardContract = poolInfo[_pid].crvRewards;
            IERC20(token).approve(rewardContract,_amount);
            IRewards(rewardContract).stakeFor(msg.sender,_amount);
        }else{
            //add user balance directly
            ITokenMinter(token).mint(msg.sender,_amount);
        }
        return true;
    }

    //deposit all lp tokens and stake
    function depositAll(uint256 _pid, bool _stake) external returns(bool){
        address lptoken = poolInfo[_pid].lptoken;
        uint256 balance = IERC20(lptoken).balanceOf(msg.sender);
        deposit(_pid,balance,_stake);
        return true;
    }

    //withdraw lp tokens
    function _withdraw(uint256 _pid, uint256 _amount, address _from, address _to) internal {
        address lptoken = poolInfo[_pid].lptoken;
        address gauge = poolInfo[_pid].gauge;
        uint256 before = IERC20(lptoken).balanceOf(address(this));

        //pull whats needed from gauge
        //  should always be full amount unless we withdrew everything to shutdown this contract
        if (before < _amount) {
            IStaker(staker).withdraw(lptoken,gauge, _amount.sub(before));
        }
        //remove lp balance
        address token = poolInfo[_pid].token;

        ITokenMinter(token).burn(_from,_amount);
        //return lp tokens
        IERC20(lptoken).safeTransfer(_to, _amount);
    }

    //withdraw lp tokens
    function withdraw(uint256 _pid, uint256 _amount) public returns(bool){
        _withdraw(_pid,_amount,msg.sender,msg.sender);
        return true;
    }

    //withdraw all lp tokens
    function withdrawAll(uint256 _pid) public returns(bool){
        address token = poolInfo[_pid].token;
        uint256 userBal = IERC20(token).balanceOf(msg.sender);
        withdraw(_pid, userBal);
        return true;
    }

}