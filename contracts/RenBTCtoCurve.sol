// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
//import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import './curvefi/ICurveFi_StableSwapRen.sol';
import './curvefi/ICurveFi_Gauge.sol';
import './curvefi/ICurveFi_Minter.sol';
import './curvefi/IRenERC20.sol';
import './Decimal.sol';

contract RenBTCtoCurve is Initializable, Ownable{
    using SafeMath for uint256;
    using Decimal for Decimal.D256;
    //using SafeERC20 for IERC20;
    address public curveFi_Swap;
    address public curveFi_LPToken;
    address public curveFi_LPGauge;
    address public curveFi_CRVMinter;
    address public curveFi_CRVToken; 
    
    struct BlockDeposit{
        uint blockNumber;
        uint depositBalance;
    }

    BlockDeposit[] public _deposits;
    mapping(address => uint[]) public depsoitIndex;
    mapping(address => mapping(uint  => bool)) public userdeposits;
    mapping(address => uint256) public rbtcDeposits;

    function initialize() external initializer {
        Ownable.initialize(_msgSender());
    }

    /**
     * @notice Set CurveFi contracts addresses
     * @param _swapContract CurveFi Deposit contract for ren-pool
     * @param _gaugeContract CurveFi Gauge contract for ren-pool
     * @param _minterContract CurveFi CRV minter
     * @param _lpContract CurveFi LP token contract = CurveTokenV1
     */
        function setup( address _swapContract, 
                        address _gaugeContract, 
                        address _minterContract, 
                        address _lpContract ) 
                        external onlyOwner {
        require(_swapContract != address(0), "Incorrect StableSwap contract address");

        curveFi_Swap = _swapContract;
        curveFi_LPGauge = _gaugeContract;
        curveFi_LPToken = _lpContract;

        require(ICurveFi_Gauge(curveFi_LPGauge).lp_token() == address(curveFi_LPToken), "CurveFi LP tokens do not match");        

        curveFi_CRVMinter = _minterContract;
        curveFi_CRVToken = ICurveFi_Gauge(curveFi_LPGauge).crv_token();
    }

     /**
     * @notice Deposits 2 stablecoins (registered in Curve.Fi Y pool)
     * @param _amounts Array of amounts for CurveFI stablecoins in pool (denormalized to token decimals)
     */
    function multiStepDeposit(uint256[2] memory _amounts) public {
        address[2] memory stablecoins;
        
        for(uint256 i = 0 ; i < stablecoins.length ; i++){
            stablecoins[i] = ICurveFi_StableSwapRen(curveFi_Swap).coins(int128(uint128(i)));
        }
        
        for (uint256 i = 0; i < stablecoins.length; i++) {
            //IERC20(stablecoins[i]).safeTransferFrom(_msgSender(), address(this), _amounts[i]);
            //IERC20(stablecoins[i]).safeApprove(curveFi_Swap, _amounts[i]);
            IRenERC20(stablecoins[i]).transferFrom(_msgSender(), address(this), _amounts[i]);
            IRenERC20(stablecoins[i]).approve(curveFi_Swap, _amounts[i]);
        }

        //Step 1 - deposit stablecoins and get Curve.Fi LP tokens
        ICurveFi_StableSwapRen(curveFi_Swap).add_liquidity(_amounts, 0); 

        //Step 2 - stake Curve LP tokens into Gauge and get CRV rewards
        uint256 curveLPBalance = IERC20(curveFi_LPToken).balanceOf(address(this));

        IERC20(curveFi_LPToken).approve(curveFi_LPGauge, curveLPBalance);

        ICurveFi_Gauge(curveFi_LPGauge).deposit(curveLPBalance);

        //Step 3 - get all the rewards (and make whatever you need with them)
        crvTokenClaim();
      
       
       uint256 summ;
        for (uint256 i=0; i < stablecoins.length; i++){
            summ = summ.add(normalize(stablecoins[i], _amounts[i]));
        }
        _deposits.push(BlockDeposit(block.number,summ));
        depsoitIndex[msg.sender].push(_deposits.length-1);
        userdeposits[msg.sender][_deposits.length-1] = true;
        rbtcDeposits[msg.sender] += _amounts[0];
    }

     /**
     * @notice Claim CRV reward
     */
    function crvTokenClaim() public{
        ICurveFi_Minter(curveFi_CRVMinter).mint(curveFi_LPGauge);
        
    }

    function getClaimableTokens() public returns(uint256){
       return ICurveFi_Gauge(curveFi_LPGauge).claimable_tokens(address(this));
    }

    function multiStepWithdraw(uint256[2] memory _amounts)public {
        address[2] memory stablecoins;
        uint256 nWithdraw;
       
        for(uint256 i = 0 ; i < stablecoins.length ; i++){
            stablecoins[i] = ICurveFi_StableSwapRen(curveFi_Swap).coins(int128(uint128(i)));
        }
        
        //Step 1 - Calculate amount of Curve LP-tokens to unstake
        for(uint256 i = 0 ; i < stablecoins.length ; i++){
            nWithdraw = nWithdraw.add(normalize(stablecoins[i], _amounts[i]));
        }

        uint256 withdrawShares = calculateShares(nWithdraw);

        //Check if you can re-use unstaked LP tokens
        uint256 notStaked = curveLPTokenUnstaked();
        if (notStaked > 0) {
            withdrawShares = withdrawShares.sub(notStaked);
        }

        //Step 2 - Unstake Curve LP tokens from Gauge
        ICurveFi_Gauge(curveFi_LPGauge).withdraw(withdrawShares);

        //Step 3 - Withdraw stablecoins from CurveSwap
        IERC20(curveFi_LPToken).approve(curveFi_Swap, withdrawShares);
        ICurveFi_StableSwapRen(curveFi_Swap).remove_liquidity_imbalance(_amounts, withdrawShares);

        //Step 4 - Send stablecoins to the requestor
        for (uint256 i = 0; i <  stablecoins.length; i++){
            IRenERC20 _stablecoin = IRenERC20(stablecoins[i]);
            uint256 balance = _stablecoin.balanceOf(address(this));
            uint256 amount = (balance <= _amounts[i]) ? balance : _amounts[i]; //Safepoint for rounding
            _stablecoin.transfer(_msgSender(), amount);
        }

        crvTokenClaim();
        
        uint256 summ;
        for (uint256 i=0; i < stablecoins.length; i++){
            summ = summ.add(normalize(stablecoins[i], _amounts[i]));
        }

        uint256 noOfDeposits = depsoitIndex[_msgSender()].length;
        if(noOfDeposits > 0){

            while(summ > 0){
              uint256 [] storage userArray = depsoitIndex[_msgSender()];
              uint256 __deposit = _deposits[userArray[userArray.length-1]].depositBalance;
              if(__deposit > summ){
                  __deposit = __deposit.sub(summ);
                  summ = 0;
                  _deposits[userArray[userArray.length-1]].depositBalance = __deposit;
              }
              else if(__deposit <=  summ){
                  summ  = summ.sub(__deposit);
                  __deposit = 0;
                  _deposits[userArray[userArray.length-1]].depositBalance = __deposit;
                  userdeposits[_msgSender()][userArray[userArray.length-1]] = false;
                  userArray.pop();
              }
              
            }
        }
        
        rbtcDeposits[msg.sender] -= _amounts[0];
    }

    function fetchCRVShare() public view returns(Decimal.D256 memory, uint256){

        uint256 crvAmount = IERC20(curveFi_CRVToken).balanceOf(address(this));
        uint256 latestBlock = block.number;
        uint256 [] memory userArray = depsoitIndex[_msgSender()];
        uint256 numerator = 0;
        uint256 denominator = 0;
        for(uint i = 0; i < userArray.length ; i++){
           BlockDeposit memory _depositDetails = _deposits[userArray[i]];
           numerator += (latestBlock - _depositDetails.blockNumber)*_depositDetails.depositBalance;
        }
        
        for(uint i = 0 ; i < _deposits.length ; i++){
            if(userdeposits[_msgSender()][i] != true){
               denominator += (latestBlock - _deposits[i].blockNumber) * _deposits[i].depositBalance;
            }
        }

        return (Decimal.from(numerator).div(numerator + denominator), crvAmount);
    }

    function claimCRV() public{
        (Decimal.D256 memory result,uint256 crv) = fetchCRVShare();
        uint256 crvshare = Decimal.asUint256(result.mul(crv));
        IERC20(curveFi_CRVToken).transfer(_msgSender(), crvshare);
       
    }
    
    function calculateShares(uint256 normalizedWithdraw)public view returns(uint256){
        uint256 nBalance = normalizedBalance();
        uint256 poolShares = curveLPTokenBalance();
        
        return poolShares.mul(normalizedWithdraw).div(nBalance);
    }

    function normalizedBalance()public view returns(uint256){
        address[2] memory stablecoins;

        for(uint256 i = 0 ; i < stablecoins.length ; i++){
            stablecoins[i] = ICurveFi_StableSwapRen(curveFi_Swap).coins(int128(uint128(i)));
        }

        uint256[2] memory balances = balanceOfAll();
        uint256 summ;

        for (uint256 i=0; i < stablecoins.length; i++){
            summ = summ.add(normalize(stablecoins[i], balances[i]));
        }

        return summ;
    } 

    function balanceOfAll()public view returns(uint256[2] memory){
        address[2] memory stablecoins;
        uint256 [2] memory balances;

        for(uint256 i = 0 ; i < stablecoins.length ; i++){
            stablecoins[i] = ICurveFi_StableSwapRen(curveFi_Swap).coins(int128(uint128(i)));
        }

        uint256 curveLPBalance = curveLPTokenBalance();
        uint256 curveLPTokenSupply = IERC20(curveFi_LPToken).totalSupply();

        require(curveLPTokenSupply > 0, "No Curve LP tokens minted");

        for(uint256 i = 0 ; i < stablecoins.length ; i++){
            uint256 renLPTokenBalance = ICurveFi_StableSwapRen(curveFi_Swap).balances(int128(uint128(i)));
            address renCoin = ICurveFi_StableSwapRen(curveFi_Swap).coins(int128(uint128(i)));
            
            //Calculate user's share of ren tokens
            uint256 renShares = renLPTokenBalance.mul(curveLPBalance).div(curveLPTokenSupply);
            uint256 renPrice = IRenERC20(renCoin).exchangeRateCurrent();

            balances[i] = renPrice.mul(renShares).div(1e18);
        }
        return balances;
    }
  
     
     /**
     * @notice Get full amount of Curve LP tokens available for this contract
     */
    function curveLPTokenBalance() public view returns(uint256) {
        uint256 staked = curveLPTokenStaked();
        uint256 unstaked = curveLPTokenUnstaked();
        return unstaked.add(staked);
    }

    /**
     * @notice Get amount of unstaked CurveFi LP tokens (which lay on this contract)
     */
    function curveLPTokenUnstaked() public view returns(uint256) {
        return IERC20(curveFi_LPToken).balanceOf(address(this));
    }

    /**
     * @notice Get amount of CurveFi LP tokens staked in the Gauge
     */
    function curveLPTokenStaked() public view returns(uint256) {
        return ICurveFi_Gauge(curveFi_LPGauge).balanceOf(address(this));
       // return ICurveFi_Gauge(curveFi_LPGauge).balanceOf(_msgSender());
    }

    /**
     * @notice Util to normalize balance up to 18 decimals
     */
     //just for testing : internal => public
    function normalize(address coin, uint256 amount) public view returns(uint256) {
       uint8 decimal  = ERC20Detailed(coin).decimals();
        if(decimal == 18){
           return  amount; 
        }
        else if(decimal > 18){
           return amount.div(uint256(10)**(decimal-18));
        } 
        else if(decimal < 18){
           return amount.mul(uint256(10)**(18 - decimal));
        }
    }

}