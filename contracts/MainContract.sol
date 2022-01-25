// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import './curvefi/ICurveFi_StableSwapRen.sol';
import './curvefi/ICurveFi_Gauge.sol';
import './curvefi/ICurveFi_Minter.sol';
import './curvefi/IRenERC20.sol';
import './InterfacesAbracadabra/IMasterContract.sol';
import './Decimal.sol';

interface IDeposit{
    struct PoolInfo {
        address lptoken;
        address token;
        address gauge;
        address crvRewards;
        address stash;
    }
   function deposit(uint256 _pid, uint256 _amount, bool _stake) external returns(bool);
   function withdraw(uint256 _pid, uint256 _amount) external returns(bool);
   function poolInfo(uint256 index) external returns(PoolInfo memory);
}

contract MainContract is Initializable, Ownable{
    using SafeMath for uint256;
    using Decimal for Decimal.D256;
    address public curveFi_Swap;
    address public curveFi_LPToken;
    address public curveFi_LPGauge;
    address public curveFi_CRVMinter;
    address public curveFi_CRVToken;
    address public convexFi_Booster;
    address public convexFi_Staker;
    address public abraFi_Cauldron;
    address public abraFi_BenToBox;
    address public abraFi_mim;
    
    struct BlockDeposit{
        uint blockNumber;
        uint depositBalance;
    }
    event CookCalling(address user, uint mimBorrowed, uint mimUserBalance);
    BlockDeposit[] public _deposits;
    mapping(address => uint[]) public depsoitIndex;
    mapping(address => mapping(uint  => bool)) public userdeposits;
    mapping(address => uint256) public rbtcDeposits;
    mapping(address => uint256) public cvxrencrvDeposits;
    mapping(address => uint256) public mimBorrowed; 
    mapping(address => uint256) public mimBalance;

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
                        address _lpContract,
                        address _booster,
                        address _staker,
                        address _cauldron,
                        address _benToBox,
                        address _mim,
                        bytes calldata data) 
                        external onlyOwner {
        require(_swapContract != address(0), "Incorrect StableSwap contract address");

        curveFi_Swap = _swapContract;
        curveFi_LPGauge = _gaugeContract;
        curveFi_LPToken = _lpContract;

        require(ICurveFi_Gauge(curveFi_LPGauge).lp_token() == address(curveFi_LPToken), "CurveFi LP tokens do not match");        

        curveFi_CRVMinter = _minterContract;
        curveFi_CRVToken = ICurveFi_Gauge(curveFi_LPGauge).crv_token();
        convexFi_Booster = _booster;
        convexFi_Staker = _staker;
        abraFi_Cauldron = _cauldron;
        abraFi_BenToBox = _benToBox;
        abraFi_mim = _mim;
        IMasterContract(abraFi_Cauldron).init.value(0)(data);
        IMasterContract(abraFi_Cauldron).registeringProtocol();
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
            IRenERC20(stablecoins[i]).transferFrom(_msgSender(), address(this), _amounts[i]);
            IRenERC20(stablecoins[i]).approve(curveFi_Swap, _amounts[i]);
        }

        //Step 1 - deposit stablecoins and get Curve.Fi LP tokens
        ICurveFi_StableSwapRen(curveFi_Swap).add_liquidity(_amounts, 0); 

        //Step 2 - stake Curve LP tokens into Gauge
        uint256 curveLPBalance = IERC20(curveFi_LPToken).balanceOf(address(this));

        IERC20(curveFi_LPToken).approve(convexFi_Booster, curveLPBalance);
        IDeposit(convexFi_Booster).deposit(0, curveLPBalance, false);       
        
        //keeping track of user balance for cvxrencrv
        address cvxrencrv = IDeposit(convexFi_Booster).poolInfo(0).token;
        uint cvxrencrvBalance = IERC20(cvxrencrv).balanceOf(address(this));
        cvxrencrvDeposits[msg.sender] += cvxrencrvBalance;

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
    
    function cookCalling(uint8[] calldata actions, 
                         uint256[] calldata values, 
                         bytes[] calldata datas, bool isRepay, uint256 payMim) external payable returns (uint256 value1, uint256 value2) {
        
        address cvxrencrv = IDeposit(convexFi_Booster).poolInfo(0).token;
        uint cvxrencrvBalance = cvxrencrvDeposits[msg.sender];
        IERC20(cvxrencrv).approve(abraFi_BenToBox, cvxrencrvBalance);

        uint preBorrowBalance = (IMasterContract(abraFi_Cauldron).userBorrowPart(address(this)));

        if(isRepay){
            require(payMim >= (mimBorrowed[msg.sender] + 1 * 10 ** 18),"Main Contract: mim inappropriate amount");
            IERC20(abraFi_mim).transferFrom(msg.sender, address(this), payMim);
            IERC20(abraFi_mim).approve(abraFi_BenToBox, payMim);
        }
      
        (value1,value2) = IMasterContract(abraFi_Cauldron).cook.value(msg.value)(actions,values,datas);
        uint256 mimBalance;
        if(!isRepay){
            if(mimBorrowed[msg.sender] > 0){
                mimBorrowed[msg.sender] += (IMasterContract(abraFi_Cauldron).userBorrowPart(address(this)) - preBorrowBalance);
            }
            else{
                mimBorrowed[msg.sender] = (IMasterContract(abraFi_Cauldron).userBorrowPart(address(this)) - preBorrowBalance);
            }
            mimBalance = IERC20(abraFi_mim).balanceOf(address(this));
            IERC20(abraFi_mim).transfer(msg.sender, mimBalance);
        }
        emit CookCalling(msg.sender, mimBorrowed[msg.sender],mimBalance);
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
        //ICurveFi_Gauge(curveFi_LPGauge).withdraw(withdrawShares);
        IDeposit(convexFi_Booster).withdraw(0, withdrawShares);

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

        cvxrencrvDeposits[msg.sender] = 0;

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
        return ICurveFi_Gauge(curveFi_LPGauge).balanceOf(convexFi_Staker);
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