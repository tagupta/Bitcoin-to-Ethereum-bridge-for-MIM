// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "./Stub_BoringOwnable.sol";
import {BoringMath} from "./Stub_Boringcrypto.sol";
import "../InterfacesAbracadabra/IBentoBoxV1.sol";

contract Stub_MagicInternetMoney is ERC20, Stub_BoringOwnable {
    using BoringMath for uint256;
    // ERC20 'variables'
    string public constant symbol = "MIM";
    string public constant name = "Magic Internet Money";
    uint8 public constant decimals = 18;

    struct Minting {
        uint128 time;
        uint128 amount;
    }

    Minting public lastMint;
   // mapping(address => uint) public _balanceOf;
    uint256 private constant MINTING_PERIOD = 24 hours;
    uint256 private constant MINTING_INCREASE = 15000;
    uint256 private constant MINTING_PRECISION = 1e5;

    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "MIM: no mint to zero address");

        // Limits the amount minted per period to a convergence function, with the period duration restarting on every mint
        uint256 totalMintedAmount = BoringMath.add(uint256(lastMint.time < block.timestamp - MINTING_PERIOD ? 0 : lastMint.amount), amount);
        require(totalSupply() == 0 || BoringMath.mul(totalSupply(), MINTING_INCREASE)/ MINTING_PRECISION >= totalMintedAmount);

        lastMint.time = block.timestamp.to128();
        lastMint.amount = totalMintedAmount.to128();
        _mint(to, amount);
    }

    function mintToBentoBox(address clone, uint256 amount, IBentoBoxV1 bentoBox) public onlyOwner {
        mint(address(bentoBox), amount);
        bentoBox.deposit(IERC20(address(this)), address(bentoBox), clone, amount, 0);
    }

    function burn(uint256 amount) public {
        require(amount <= balanceOf(msg.sender), "MIM: not enough");
        _burn(msg.sender, amount);
    }
}
