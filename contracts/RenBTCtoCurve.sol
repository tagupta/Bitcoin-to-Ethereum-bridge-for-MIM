// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import './curvefi/ICurveFi_StableSwapRen.sol';
import './curvefi/ICurveFi_Gauge.sol';
import './curvefi/ICurveFi_Minter.sol';
import './curvefi/IRenERC20.sol';

contract RenBTCtoCurve is Initializable, Ownable{
    using SafeERC20 for IERC20;

    address public curveFi_Swap;
    address public curveFi_LPToken;
    address public curveFi_LPGauge;
    address public curveFi_CRVMinter;
    address public curveFi_CRVToken; 

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
    function multiStepDeposit(uint[2] memory _amounts) public {
        address stablecoinsRenBTC;
        address stablecoinsWBTC;
        address[2] memory stablecoins;

        stablecoinsRenBTC = ICurveFi_StableSwapRen(curveFi_Swap).coins(0);
        stablecoinsWBTC = ICurveFi_StableSwapRen(curveFi_Swap).coins(1);
        stablecoins = [stablecoinsRenBTC , stablecoinsWBTC];
        
        for (uint256 i = 0; i < stablecoins.length; i++) {
            IERC20(stablecoins[i]).safeTransferFrom(_msgSender(), address(this), _amounts[i]);
            IERC20(stablecoins[i]).safeApprove(curveFi_Swap, _amounts[i]);
        }

        //Step 1 - deposit stablecoins and get Curve.Fi LP tokens
        ICurveFi_StableSwapRen(curveFi_Swap).add_liquidity(_amounts, 0); 

        //Step 2 - stake Curve LP tokens into Gauge and get CRV rewards
        uint256 curveLPBalance = IERC20(curveFi_LPToken).balanceOf(address(this));

        IERC20(curveFi_LPToken).safeApprove(curveFi_LPGauge, curveLPBalance);
        ICurveFi_Gauge(curveFi_LPGauge).deposit(curveLPBalance);

        //Step 3 - get all the rewards (and make whatever you need with them)
        crvTokenClaim();
        uint256 crvAmount = IERC20(curveFi_CRVToken).balanceOf(address(this));
        IERC20(curveFi_CRVToken).safeTransfer(_msgSender(), crvAmount);

    }

     /**
     * @notice Claim CRV reward
     */
    function crvTokenClaim() internal {
        ICurveFi_Minter(curveFi_CRVMinter).mint(curveFi_LPGauge);
    }

}