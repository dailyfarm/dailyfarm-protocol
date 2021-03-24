// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// DailyBar is the coolest bar in town. You come in with some Daily, and leave with more! The longer you stay, the more Daily you get.
//
// This contract handles swapping to and from xDaily, DailySwap's staking token.
contract DailyBar is ERC20{
    using SafeMath for uint256;
    IERC20 public daily;

    // Define the Daily token contract
    constructor(
        IERC20 _daily, 
        string memory _name, 
        string memory _symbol
    ) public ERC20(_name, _symbol) {
        daily = _daily;
    }

    // Enter the bar. Pay some DAILYs. Earn some shares.
    // Locks Daily and mints xDaily
    function enter(uint256 _amount) public {
        // Gets the amount of Daily locked in the contract
        uint256 totalDaily = daily.balanceOf(address(this));
        // Gets the amount of xDaily in existence
        uint256 totalShares = totalSupply();
        // If no xDaily exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalDaily == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of xDaily the Daily is worth. The ratio will change overtime, as xDaily is burned/minted and Daily deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalDaily);
            _mint(msg.sender, what);
        }
        // Lock the Daily in the contract
        daily.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your DAILYs.
    // Unlocks the staked + gained Daily and burns xDaily
    function leave(uint256 _share) public {
        // Gets the amount of xDaily in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Daily the xDaily is worth
        uint256 what = _share.mul(daily.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        daily.transfer(msg.sender, what);
    }
}