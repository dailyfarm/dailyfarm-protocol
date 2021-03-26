pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

import "../interfaces/IMasterChef.sol";
import "../interfaces/IVault.sol";
import "../utils/TokenConverter.sol";


contract AlpacaWbnbLpVault is IVault, TokenConverter, ERC20("daily Alpaca_Wbnb_Lp", "d_ALPACA_WBNB_LP"), Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public lpToken;
    address public alpaca;
    address public wbnb;

    address public farmer;
    uint256 public farmerPid;

    address public dailyMasterChef;
    uint256 public stakePid;

    address public feeReceiver;

    address public emergencyOperator;
    bool public emergencyStop; 

    mapping(address => uint256) private _shareBalances;
    
    constructor(
        address _lpToken,
        address _alpaca,
        address _wbnb,
        address _factory,
        address _farmer,
        uint256 _farmerPid,
        address _dailyMasterChef,
        address _feeReceiver
    ) public TokenConverter(_factory) {
        lpToken = _lpToken;
        alpaca = _alpaca;
        wbnb = _wbnb;
        farmer = _farmer;
        farmerPid = _farmerPid;
        dailyMasterChef = _dailyMasterChef;
        feeReceiver = _feeReceiver;
        emergencyOperator = msg.sender;
        _approve(address(this), dailyMasterChef, 10**30);
        IERC20(lpToken).safeApprove(farmer, 10**30);
    }

    modifier onlyEmergencyOperator {
        require (msg.sender == emergencyOperator, "on operator");

        _;
    }

    function reinvest() external override {
        _harvest();
    }

    function deposit(uint256 amount) external override {
        require(!emergencyStop, "emergencyStop");
        _harvest();
        
        uint256 shareAmount = amount;
        if (totalSupply() > 0 && totalTokenBalance() > 0) {
            shareAmount = amount.mul(totalSupply()).div(totalTokenBalance());
        }
        
        _mint(address(this), shareAmount);
        IMasterChef(dailyMasterChef).deposit(msg.sender, stakePid, shareAmount);
        _shareBalances[msg.sender] = _shareBalances[msg.sender].add(shareAmount);
        
        IERC20(lpToken).safeTransferFrom(msg.sender, address(this), amount);
        IAlpacaMasterChef(farmer).deposit(address(this), farmerPid, IERC20(lpToken).balanceOf(address(this)));
    }

    function withdraw(uint256 amount) public override {
        _harvest();

        uint256 shareAmount = amount.mul(totalShareBalance()).div(totalTokenBalance());
        
        IMasterChef(dailyMasterChef).withdraw(msg.sender, stakePid, shareAmount);
        _shareBalances[msg.sender] = _shareBalances[msg.sender].sub(shareAmount);
        _burn(address(this), shareAmount);

        uint256 localBalance = IERC20(lpToken).balanceOf(address(this));
        if (amount > localBalance) {
            uint256 withdrawLpAmount = amount.sub(localBalance);
            IAlpacaMasterChef(farmer).withdraw(address(this), farmerPid, withdrawLpAmount);
        }
        IERC20(lpToken).safeTransfer(msg.sender, amount);
    }

    function withdrawAll() external override {
        withdraw(tokenBalanceOf(msg.sender));
    }

    function _harvest() internal {
        (uint256 stakeAmount, , ,) = IAlpacaMasterChef(farmer).userInfo(farmerPid, address(this));
        if (stakeAmount > 0) {
            IAlpacaMasterChef(farmer).harvest(farmerPid);
        }
        uint256 alpacaAmount = IERC20(alpaca).balanceOf(address(this));
        if (alpacaAmount > 0) {
            uint256 wbnbAmount = IERC20(wbnb).balanceOf(address(this));
            if (wbnbAmount > 0) {
                _addLp(alpaca, wbnb, alpacaAmount, wbnbAmount, address(this));
            }
            alpacaAmount = IERC20(alpaca).balanceOf(address(this));
            _swap(alpaca, wbnb, alpacaAmount.div(2), address(this));
            _addLp(alpaca, wbnb, IERC20(alpaca).balanceOf(address(this)), IERC20(wbnb).balanceOf(address(this)), address(this));
        }

        if (!emergencyStop) {
            uint256 lpAmount = IERC20(lpToken).balanceOf(address(this));
            if (lpAmount > 0) {
                IERC20(lpToken).safeTransfer(feeReceiver, lpAmount.div(10));
                IAlpacaMasterChef(farmer).deposit(address(this), farmerPid, IERC20(lpToken).balanceOf(address(this)));
            }
        }
    }

    function setStakePid(uint256 _stakePid) public onlyOwner {
        require(stakePid == 0, "already set");
        stakePid = _stakePid;
    }

    function setFeeReceiver(address _feeReceiver) public onlyOwner {
        feeReceiver = _feeReceiver;
    }

    function setEmergencyOperator(address _op) public onlyOwner {
        emergencyOperator = _op; 
    }

    function stop() public onlyEmergencyOperator {
        emergencyStop = true;
        IERC20(lpToken).safeApprove(farmer, 0);
    }

    function start() public onlyEmergencyOperator {
        emergencyStop = false;
        IERC20(lpToken).safeApprove(farmer, 10**30);
    }

    function tokenBalanceOf(address user) public view override returns (uint256) {
        return totalTokenBalance().mul(shareBalanceOf(user)).div(totalShareBalance());
    }

    function totalTokenBalance() public view override returns (uint256) {
        (uint256 stakeAmount, , ,) = IAlpacaMasterChef(farmer).userInfo(farmerPid, address(this));
        return stakeAmount.add(IERC20(lpToken).balanceOf(address(this))); 
    }

    function shareBalanceOf(address user) public view override returns (uint256) {
        return _shareBalances[user];
    }

    function totalShareBalance() public view override returns (uint256) {
        return totalSupply();
    }

}


interface IAlpacaMasterChef {
    function userInfo(uint256 pid, address user) external view returns (uint256, uint256, uint256, address); 
    function deposit(address _for, uint256 _pid, uint256 _amount) external;
    function withdraw(address _for, uint256 _pid, uint256 _amount) external;
    function withdrawAll(address _for, uint256 _pid) external;
    function harvest(uint256 _pid) external;
}