pragma solidity ^0.6.0;

import "../interfaces/IMasterChef.sol";
import "./BaseVault.sol";
import "../utils/TokenConverter.sol";


contract AlpacaWbnbLpVault is BaseVault, TokenConverter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant lpToken = 0xF3CE6Aac24980E6B657926dfC79502Ae414d3083;
    address public constant alpaca = 0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F;
    address public constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address public constant alpacaMasterChef = 0xA625AB01B08ce023B2a342Dbb12a16f2C8489A8F;
    uint256 public constant alpacaMasterChefPid = 4;

    address public constant pancakeFactory = 0xBCfCcbde45cE874adCB698cC183deBcF17952812;
    
    address public dailyToken;
    address public feeReceiver;

    constructor(
        address _dailyMasterChef,
        address _dailyToken,
        address _feeReceiver
    ) 
        public 
        BaseVault(
            "daily Alpaca_Wbnb_Lp",
            "d_ALPACA_WBNB_LP",
            lpToken,
            _dailyMasterChef
        )
        TokenConverter(pancakeFactory) 
    {
        dailyToken = _dailyToken;
        feeReceiver = _feeReceiver;
        IERC20(lpToken).safeApprove(alpacaMasterChef, 10**60);
    }

    function _harvest() internal override {
        (uint256 stakeAmount, , ,) = IAlpacaMasterChef(alpacaMasterChef).userInfo(alpacaMasterChefPid, address(this));
        if (stakeAmount > 0) {
            IAlpacaMasterChef(alpacaMasterChef).harvest(alpacaMasterChefPid);
        }
        uint256 alpacaAmount = IERC20(alpaca).balanceOf(address(this));
        if (alpacaAmount > 0) {
            // 10% for xDaily stakers
            uint256 xReward = alpacaAmount.div(10);
            _swap(alpaca, wbnb, xReward, address(this));
            _swap(wbnb, dailyToken, IERC20(wbnb).balanceOf(address(this)), feeReceiver);

            alpacaAmount = alpacaAmount.sub(xReward);
            _swap(alpaca, wbnb, alpacaAmount.div(2), address(this));
            _addLp(alpaca, wbnb, alpacaAmount.div(2), IERC20(wbnb).balanceOf(address(this)), address(this));
        }
    }

    function _invest() internal override {
        uint256 lpAmount = IERC20(lpToken).balanceOf(address(this));
        if (lpAmount > 0) {
            IAlpacaMasterChef(alpacaMasterChef).deposit(address(this), alpacaMasterChefPid, lpAmount);
        }
    }

    function _exit() internal override {
        IAlpacaMasterChef(alpacaMasterChef).withdrawAll(address(this), alpacaMasterChefPid);
    }

    function _exitSome(uint256 _amount) internal override {
        IAlpacaMasterChef(alpacaMasterChef).withdraw(address(this), alpacaMasterChefPid, _amount);
    }

    function _withdrawFee(uint256 _withdrawAmount, uint256 _lastDepositTime) internal override returns (uint256) {
        if (_lastDepositTime.add(2 days) <= block.timestamp) {
            return 0;
        } 
        uint256 feeAmount = _withdrawAmount.mul(2).div(1000);
        
        IERC20(lpToken).safeTransfer(lpToken, feeAmount);
        IUniswapV2Pair(lpToken).burn(address(this));

        _swap(alpaca, wbnb, IERC20(alpaca).balanceOf(address(this)), address(this));
        _swap(wbnb, dailyToken, IERC20(wbnb).balanceOf(address(this)), feeReceiver);
    }

    function _totalTokenBalance() internal view override returns (uint256) {
        (uint256 stakeAmount, , ,) = IAlpacaMasterChef(alpacaMasterChef).userInfo(alpacaMasterChefPid, address(this));
        return IERC20(lpToken).balanceOf(address(this)).add(stakeAmount);
    }
    
}


interface IAlpacaMasterChef {
    function userInfo(uint256 pid, address user) external view returns (uint256, uint256, uint256, address); 
    function deposit(address _for, uint256 _pid, uint256 _amount) external;
    function withdraw(address _for, uint256 _pid, uint256 _amount) external;
    function withdrawAll(address _for, uint256 _pid) external;
    function harvest(uint256 _pid) external;
}