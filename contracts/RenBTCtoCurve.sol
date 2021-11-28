// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

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

contract RenBTCtoCurve is Initializable, Ownable{
    using SafeMath for uint256;
    //using SafeERC20 for IERC20;

    address public curveFi_Swap;
    address public curveFi_LPToken;
    address public curveFi_LPGauge;
    address public curveFi_CRVMinter;
    address public curveFi_CRVToken; 

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
        uint256 crvAmount = IERC20(curveFi_CRVToken).balanceOf(address(this));
        IERC20(curveFi_CRVToken).transfer(_msgSender(), crvAmount);

    }

     /**
     * @notice Claim CRV reward
     */
    function crvTokenClaim() internal {
        ICurveFi_Minter(curveFi_CRVMinter).mint(curveFi_LPGauge);
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