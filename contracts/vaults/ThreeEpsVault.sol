pragma solidity ^0.6.0;

import "../interfaces/IMasterChef.sol";
import "./BaseVault.sol";
import "../utils/TokenConverter.sol";


contract ThreeEpsVault is BaseVault, TokenConverter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant lpToken = 0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452;
    address public constant eps = 0xA7f552078dcC247C2684336020c03648500C6d9F;
    address public constant epsStableSwap = 0x160CAed03795365F3A589f10C379FfA7d75d4E76;
    address public constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address public constant busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;  // idx: 0
    address public constant usdc = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;  // idx: 1
    address public constant usdt = 0x55d398326f99059fF775485246999027B3197955;  // idx: 2

    address public constant epsMasterChef = 0xcce949De564fE60e7f96C85e55177F8B9E4CF61b;
    uint256 public constant epsMasterChefPid = 1;

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
        IERC20(lpToken).safeApprove(epsStableSwap, 10**60);
        IERC20(busd).safeApprove(epsStableSwap, 10**60);
        IERC20(usdt).safeApprove(epsStableSwap, 10**60);
        IERC20(usdc).safeApprove(epsStableSwap, 10**60);
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
            _swap(eps, wbnb, epsAmount, address(this));
            uint256 wbnbAmount = IERC20(wbnb).balanceOf(address(this));
            
            _swap(wbnb, busd, wbnbAmount.div(3), address(this));
            _swap(wbnb, usdt, wbnbAmount.div(3), address(this));
            _swap(wbnb, usdc, wbnbAmount.div(3), address(this));
            
            uint256[] memory inAmounts = new uint256[](3);
            inAmounts[0] = IERC20(busd).balanceOf(address(this));
            inAmounts[1] = IERC20(usdc).balanceOf(address(this));
            inAmounts[2] = IERC20(usdt).balanceOf(address(this));
            IEpsStableSwap(epsStableSwap).add_liquidity(inAmounts, 1);
            
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
        
        IEpsStableSwap(epsStableSwap).remove_liquidity_one_coin(feeAmount, 0, 1);
        _swap(busd, dailyToken, IERC20(busd).balanceOf(address(this)), feeReceiver);
        
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

interface IEpsStableSwap {
    function add_liquidity(uint256[] calldata _amounts, uint256 _min_mint_amount) external;
    function remove_liquidity(uint256 _amount, uint256[] calldata _min_amount) external;
    function remove_liquidity_one_coin(uint256 _amount, int128 i, uint256 _min_amount) external;
}