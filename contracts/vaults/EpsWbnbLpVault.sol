pragma solidity ^0.6.0;

import "../interfaces/IMasterChef.sol";
import "./BaseVault.sol";
import "../utils/TokenConverter.sol";


contract EpsWbnbLpVault is BaseVault, TokenConverter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant lpToken = 0xf9045866e7b372DeF1EFf3712CE55FAc1A98dAF0;
    address public constant eps = 0xA7f552078dcC247C2684336020c03648500C6d9F;
    address public constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address public constant epsMasterChef = 0xcce949De564fE60e7f96C85e55177F8B9E4CF61b;
    uint256 public constant epsMasterChefPid = 0;

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
            "daily Eps_Wbnb_Lp",
            "d_EPS_WBNB_LP",
            lpToken,
            _dailyMasterChef
        )
        TokenConverter(pancakeFactory) 
    {
        dailyToken = _dailyToken;
        feeReceiver = _feeReceiver;
        IERC20(lpToken).safeApprove(epsMasterChef, 10**60);
    }

    function _harvest() internal override {
        (uint256 stakeAmount, ) = IEpsMasterChef(epsMasterChef).userInfo(epsMasterChefPid, address(this));
        if (stakeAmount > 0) {
            IEpsMasterChef(epsMasterChef).withdraw(epsMasterChefPid, 0);
        }
        uint256 epsAmount = IERC20(eps).balanceOf(address(this));
        if (epsAmount > 0) {
            // 10% for xDaily stakers
            uint256 xReward = epsAmount.div(10);
            _swap(eps, wbnb, xReward, address(this));
            _swap(wbnb, dailyToken, IERC20(wbnb).balanceOf(address(this)), feeReceiver);

            epsAmount = epsAmount.sub(xReward);
            _swap(eps, wbnb, epsAmount.div(2), address(this));
            _addLp(eps, wbnb, epsAmount.div(2), IERC20(wbnb).balanceOf(address(this)), address(this));
        }
    }

    function _invest() internal override {
        uint256 lpAmount = IERC20(lpToken).balanceOf(address(this));
        if (lpAmount > 0) {
            IEpsMasterChef(epsMasterChef).deposit(epsMasterChefPid, lpAmount);
        }
    }

    function _exit() internal override {
        (uint256 stakeAmount, ) = IEpsMasterChef(epsMasterChef).userInfo(epsMasterChefPid, address(this));
        IEpsMasterChef(epsMasterChef).withdraw(epsMasterChefPid, stakeAmount);
    }

    function _exitSome(uint256 _amount) internal override {
        IEpsMasterChef(epsMasterChef).withdraw(epsMasterChefPid, _amount);
    }

    function _withdrawFee(uint256 _withdrawAmount, uint256 _lastDepositTime) internal override returns (uint256) {
        if (_lastDepositTime.add(2 days) <= block.timestamp) {
            return 0;
        } 
        uint256 feeAmount = _withdrawAmount.mul(2).div(1000);
        
        IERC20(lpToken).safeTransfer(lpToken, feeAmount);
        IUniswapV2Pair(lpToken).burn(address(this));

        _swap(eps, wbnb, IERC20(eps).balanceOf(address(this)), address(this));
        _swap(wbnb, dailyToken, IERC20(wbnb).balanceOf(address(this)), feeReceiver);
        return feeAmount;
    }

    function _totalTokenBalance() internal view override returns (uint256) {
        (uint256 stakeAmount, ) = IEpsMasterChef(epsMasterChef).userInfo(epsMasterChefPid, address(this));
        return IERC20(lpToken).balanceOf(address(this)).add(stakeAmount);
    }
    
}


interface IEpsMasterChef {
    function userInfo(uint256 pid, address user) external view returns (uint256, uint256); 
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
}