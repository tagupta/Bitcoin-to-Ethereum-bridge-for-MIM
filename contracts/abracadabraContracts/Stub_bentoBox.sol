// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import {BoringMath, BoringMath128} from './Stub_Boringcrypto.sol';
import {RebaseLibrary} from './Stub_RebaseLibrary.sol';
import {BoringERC20} from './Stub_BoringERC20.sol';
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import './Stub_BoringOwnable.sol';
import './Stub_BoringFactory.sol';
import './Stub_MasterContractManager.sol';

contract Stub_bentoBox is Stub_MasterContractManager{
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using SafeERC20 for IERC20;
    using RebaseLibrary for RebaseLibrary.Rebase;
    
    struct StrategyData {
        uint64 strategyStartDate;
        uint64 targetPercentage;
        uint128 balance; // the balance of the strategy that BentoBox thinks is in there
    }

    mapping(address => mapping(address => uint256)) public balanceOf;
    mapping(address => RebaseLibrary.Rebase) public totals;
    address private wethToken; //for our dapp, the collateral will always be cvxrencrv that's why we are not using this variable
    mapping(address => StrategyData) public strategyData;

    address private constant USE_ETHEREUM = address(0);
    uint256 private constant FLASH_LOAN_FEE = 50; // 0.05%
    uint256 private constant FLASH_LOAN_FEE_PRECISION = 1e5;
    uint256 private constant STRATEGY_DELAY = 2 weeks;
    uint256 private constant MAX_TARGET_PERCENTAGE = 95; // 95%
    uint256 private constant MINIMUM_SHARE_BALANCE = 1000; // To prevent the ratio going off

    modifier allowed(address from) {
        if (from != msg.sender && from != address(this)) {
            // From is sender or you are skimming
            address masterContract = masterContractOf[msg.sender];
            require(masterContract != address(0), "BentoBox: no masterContract");
            require(masterContractApproved[masterContract][from], "BentoBox: Transfer not approved");
        }
        _;
    }
    
    function _tokenBalanceOf(address token) internal view returns (uint256 amount) {
        amount = IERC20(token).balanceOf(address(this)).add(strategyData[token].balance);
    }
    
    /// @notice Transfer shares from a user account to multiple other ones.
    function transfer(address token, address from, address to, uint256 share) public allowed(from) {
        // Checks
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds
        // Effects
        balanceOf[token][from] = balanceOf[token][from].sub(share);
        balanceOf[token][to] = balanceOf[token][to].add(share);
    }

    function toShare(address token, uint256 amount,bool roundUp) external view returns (uint256 share) {   
        share = totals[token].toBase(amount, roundUp);
    }

    function toAmount(address token, uint256 share,bool roundUp) external view returns (uint256 amount) {
        amount = totals[token].toElastic(share, roundUp);
    }

    /// @notice Deposit an amount of `token` represented in either `amount` or `share`.
    function deposit(address token_,address from,address to,uint256 amount,uint256 share) public payable allowed(from) returns (uint256 amountOut, uint256 shareOut) {
        // Checks
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds

        // Effects
        address token = token_;
        RebaseLibrary.Rebase memory total = totals[token];

        // If a new token gets added, the tokenSupply call checks that this is a deployed contract. Needed for security.
        require(total.elastic != 0 || IERC20(token).totalSupply() > 0, "BentoBox: No tokens");
        if (share == 0) {
            // value of the share may be lower than the amount due to rounding, that's ok
            share = total.toBase(amount, false);
            // Any deposit should lead to at least the minimum share balance, otherwise it's ignored (no amount taken)
            if (total.base.add(share.to128()) < MINIMUM_SHARE_BALANCE) {
                return (0, 0);
            }
        } else {
            // amount may be lower than the value of share due to rounding, in that case, add 1 to amount (Always round up)
            amount = total.toElastic(share, true);
        }

        // In case of skimming, check that only the skimmable amount is taken.
        // For ETH, the full balance is available, so no need to check.
        // During flashloans the _tokenBalanceOf is lower than 'reality', so skimming deposits will mostly fail during a flashloan.
        require(
            from != address(this) || token_ == USE_ETHEREUM || amount <= _tokenBalanceOf(token).sub(total.elastic),
            "BentoBox: Skim too much"
        );

        balanceOf[token][to] = balanceOf[token][to].add(share);
        total.base = total.base.add(share.to128());
        total.elastic = total.elastic.add(amount.to128());
        totals[token] = total;

        // Interactions
        if (from != address(this)) {
            IERC20(token).safeTransferFrom(from, address(this), amount);
        }
        amountOut = amount;
        shareOut = share;
    }

    /// @notice Withdraws an amount of `token` from a user account.
    function withdraw(address token_,address from,address to,uint256 amount,uint256 share) public allowed(from) returns (uint256 amountOut, uint256 shareOut) {
        // Checks
        require(to != address(0), "BentoBox: to not set"); // To avoid a bad UI from burning funds

        // Effects
        address token = token_;
        RebaseLibrary.Rebase memory total = totals[token];
        if (share == 0) {
            // value of the share paid could be lower than the amount paid due to rounding, in that case, add a share (Always round up)
            share = total.toBase(amount, true);
        } else {
            // amount may be lower than the value of share due to rounding, that's ok
            amount = total.toElastic(share, false);
        }

        balanceOf[token][from] = balanceOf[token][from].sub(share);
        total.elastic = total.elastic.sub(amount.to128());
        total.base = total.base.sub(share.to128());
        // There have to be at least 1000 shares left to prevent reseting the share/amount ratio (unless it's fully emptied)
        require(total.base >= MINIMUM_SHARE_BALANCE || total.base == 0, "BentoBox: cannot empty");
        totals[token] = total;

        // Interactions
        IERC20(token).safeTransfer(to, amount);
        amountOut = amount;
        shareOut = share;
    }

}