pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

import "../interfaces/IMasterChef.sol";
import "../interfaces/IVault.sol";
import "../utils/TokenConverter.sol";


abstract contract BaseVault is IVault, ERC20, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public wantToken;

    address public dailyMasterChef;
    uint256 public dailyStakePid;

    address public emergencyOperator;
    bool public emergencyStop;  // stop deposit and invest, can only withdraw

    mapping(address => uint256) private _shareBalances;
    mapping(address => uint256) public lastDepositTimes;
    
    constructor(
        string memory _name,
        string memory _symbol,
        address _wantToken,
        address _dailyMasterChef
    ) public ERC20(_name, _symbol) {
        wantToken = _wantToken;
        dailyMasterChef = _dailyMasterChef;
        emergencyOperator = msg.sender;
        _approve(address(this), dailyMasterChef, 10**60);
    }

    modifier onlyEmergencyOperator {
        require (msg.sender == emergencyOperator, "no operator");

        _;
    }

    modifier onlyEOA {
        require (msg.sender == tx.origin, "no user");

        _;
    }

    // ==============  VIRTUAL FUNCTIONS ===============
    
    function _harvest() internal virtual;
    function _invest() internal virtual;
    function _exit() internal virtual;
    function _exitSome(uint256 _amount) internal virtual;
    function _withdrawFee(uint256 _withdrawAmount, uint256 _lastDepositTime) internal virtual returns (uint256);
    function _totalTokenBalance() internal view virtual returns (uint256);

    // =================  PUBLIC FUNCTIONs ===============

    function reinvest() external override {
        _harvest();
        if (!emergencyStop) {
            _invest();
        }
    }

    function deposit(uint256 amount) external override onlyEOA {
        require(!emergencyStop, "emergencyStop");
        _harvest();
        
        uint256 shareAmount = amount;
        if (totalSupply() > 0 && _totalTokenBalance() > 0) {
            shareAmount = amount.mul(totalSupply()).div(_totalTokenBalance());
        }
        
        _mint(address(this), shareAmount);
        IMasterChef(dailyMasterChef).deposit(msg.sender, dailyStakePid, shareAmount);
        _shareBalances[msg.sender] = _shareBalances[msg.sender].add(shareAmount);
        lastDepositTimes[msg.sender] = block.timestamp;
        
        IERC20(wantToken).safeTransferFrom(msg.sender, address(this), amount);
        _invest();
    }

    function withdraw(uint256 amount) public override onlyEOA {
        uint256 shareAmount = amount.mul(totalShareBalance()).div(_totalTokenBalance());
        
        IMasterChef(dailyMasterChef).withdraw(msg.sender, dailyStakePid, shareAmount);
        _shareBalances[msg.sender] = _shareBalances[msg.sender].sub(shareAmount);
        _burn(address(this), shareAmount);

        uint256 localBalance = IERC20(wantToken).balanceOf(address(this));
        if (amount > localBalance) {
            uint256 withdrawAmount = amount.sub(localBalance);
            _exitSome(withdrawAmount);
        }
            
        uint256 withdrawFee = _withdrawFee(amount, lastDepositTimes[msg.sender]);
        IERC20(wantToken).safeTransfer(msg.sender, amount.sub(withdrawFee));        
    }

    function withdrawAll() external override onlyEOA {
        withdraw(tokenBalanceOf(msg.sender));
    }

    // ============= GOV ===============================

    function setDailyStakePid(uint256 _stakePid) public onlyOwner {
        dailyStakePid = _stakePid;
    }

    function setEmergencyOperator(address _op) public onlyOwner {
        emergencyOperator = _op; 
    }

    // ============  EMERGENCY GOV =======================

    function stop() public virtual onlyEmergencyOperator {
        emergencyStop = true;
        _exit();
    }

    function start() public virtual onlyEmergencyOperator {
        emergencyStop = false;
    }

    // ===================== VIEW ========================== 
    function tokenBalanceOf(address user) public view override returns (uint256) {
        if (totalSupply() == 0) {
            return 0;
        }
        return _totalTokenBalance().mul(shareBalanceOf(user)).div(totalShareBalance());
    }

    function totalTokenBalance() public view override returns (uint256) {
        return _totalTokenBalance(); 
    }

    function shareBalanceOf(address user) public view override returns (uint256) {
        return _shareBalances[user];
    }

    function totalShareBalance() public view override returns (uint256) {
        return totalSupply();
    }

}


