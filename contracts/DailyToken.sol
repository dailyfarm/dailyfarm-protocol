pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


contract DailyToken is ERC20, Ownable {

    mapping (address => bool) public minters;
    uint256 public mintersCount;

    constructor(
        string memory name, 
        string memory symbol,
        uint256 mintAmount
    ) public ERC20(name, symbol) {
        _mint(msg.sender, mintAmount);
    }

    // =============== MODIFIER ======================
    modifier onlyMinter {
        require(minters[msg.sender], "no minter");

        _;
    }


    // BEP20
    function getOwner() external view returns (address) {
        return owner();
    }

    
    // ================ GOVERNANCE ====================
    function mint(address recipient_, uint256 amount_)
        public
        onlyMinter
    {
        _mint(recipient_, amount_);
    }

    function burn(address account, uint256 amount)
        public
        onlyMinter
    {
        _burn(account, amount);
    }

    
    function setMinter(address _minter, bool _set) public onlyOwner {
        if (!minters[_minter] && _set) {
            mintersCount = mintersCount.add(1);
        }
        if (minters[_minter] && !_set) {
            mintersCount = mintersCount.sub(1);
        }
        minters[_minter] = _set;
    }

    

}



