pragma solidity ^0.6.0;

import "../interfaces/IMasterChef.sol";
import "./BaseVault.sol";
import "../utils/TokenConverter.sol";


contract BeltWbnbLpVault is BaseVault, TokenConverter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant lpToken = 0x83B92D283cd279fF2e057BD86a95BdEfffED6faa;
    address public constant belt = 0xE0e514c71282b6f4e823703a39374Cf58dc3eA4f;
    address public constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address public constant beltMasterChef = 0xD4BbC80b9B102b77B21A06cb77E954049605E6c1;
    uint256 public constant beltMasterChefPid = 2;

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
            "daily Belt_Wbnb_Lp",
            "d_BELT_WBNB_LP",
            lpToken,
            _dailyMasterChef
        )
        TokenConverter(pancakeFactory) 
    {
        dailyToken = _dailyToken;
        feeReceiver = _feeReceiver;
        IERC20(lpToken).safeApprove(beltMasterChef, 10**60);
    }

    function _harvest() internal override {
        (uint256 stakeAmount, ) = IBeltMasterChef(beltMasterChef).userInfo(beltMasterChefPid, address(this));
        if (stakeAmount > 0) {
            IBeltMasterChef(beltMasterChef).withdraw(beltMasterChefPid, 0);
        }
        uint256 beltAmount = IERC20(belt).balanceOf(address(this));
        if (beltAmount > 0) {
            // 10% for xDaily stakers
            uint256 xReward = beltAmount.div(10);
            _swap(belt, wbnb, xReward, address(this));
            _swap(wbnb, dailyToken, IERC20(wbnb).balanceOf(address(this)), feeReceiver);

            beltAmount = beltAmount.sub(xReward);
            _swap(belt, wbnb, beltAmount.div(2), address(this));
            _addLp(belt, wbnb, beltAmount.div(2), IERC20(wbnb).balanceOf(address(this)), address(this));
        }
    }

    function _invest() internal override {
        uint256 lpAmount = IERC20(lpToken).balanceOf(address(this));
        if (lpAmount > 0) {
            IBeltMasterChef(beltMasterChef).deposit(beltMasterChefPid, lpAmount);
        }
    }

    function _exit() internal override {
        IBeltMasterChef(beltMasterChef).withdrawAll(beltMasterChefPid);
    }

    function _exitSome(uint256 _amount) internal override {
        IBeltMasterChef(beltMasterChef).withdraw(beltMasterChefPid, _amount);
    }

    function _withdrawFee(uint256 _withdrawAmount, uint256 _lastDepositTime) internal override returns (uint256) {
        if (_lastDepositTime.add(2 days) <= block.timestamp) {
            return 0;
        } 
        uint256 feeAmount = _withdrawAmount.mul(2).div(1000);
        
        IERC20(lpToken).safeTransfer(lpToken, feeAmount);
        IUniswapV2Pair(lpToken).burn(address(this));

        _swap(belt, wbnb, IERC20(belt).balanceOf(address(this)), address(this));
        _swap(wbnb, dailyToken, IERC20(wbnb).balanceOf(address(this)), feeReceiver);
    }

    function _totalTokenBalance() internal view override returns (uint256) {
        (uint256 stakeAmount, ) = IBeltMasterChef(beltMasterChef).userInfo(beltMasterChefPid, address(this));
        return IERC20(lpToken).balanceOf(address(this)).add(stakeAmount);
    }
    
}


interface IBeltMasterChef {
    function userInfo(uint256 pid, address user) external view returns (uint256, uint256); 
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function withdrawAll(uint256 _pid) external;
}