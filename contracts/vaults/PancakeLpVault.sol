pragma solidity ^0.6.0;

import "../interfaces/IMasterChef.sol";
import "./BaseVault.sol";
import "../utils/TokenConverter.sol";


contract PancakeLpVault is BaseVault, TokenConverter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public lpToken;
    
    address public constant cake = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address public constant busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address public constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address public constant cakeMasterChef = 0x73feaa1eE314F8c655E354234017bE2193C9E24E;
    uint256 public cakeMasterChefPid;

    address public constant pancakeFactory = 0xBCfCcbde45cE874adCB698cC183deBcF17952812;
    
    address public dailyToken;
    address public feeReceiver;

    constructor(
        string memory _name,
        string memory _symbol,
        address _lpToken,
        uint256 _cakeMasterChefPid,
        address _dailyMasterChef,
        address _dailyToken,
        address _feeReceiver
    ) 
        public 
        BaseVault(
            _name,
            _symbol,
            _lpToken,
            _dailyMasterChef
        )
        TokenConverter(pancakeFactory) 
    {
        lpToken = _lpToken;
        address token0 = IUniswapV2Pair(lpToken).token0();
        address token1 = IUniswapV2Pair(lpToken).token1();
        require(token0 == wbnb || token1 == wbnb || token0 == busd || token1 == busd, "no valid lp");    
        cakeMasterChefPid = _cakeMasterChefPid;
        dailyToken = _dailyToken;
        feeReceiver = _feeReceiver;
        IERC20(lpToken).safeApprove(cakeMasterChef, 10**60);
    }

    function _harvest() internal override {
        (uint256 stakeAmount, ) = ICakeMasterChef(cakeMasterChef).userInfo(cakeMasterChefPid, address(this));
        if (stakeAmount > 0) {
            ICakeMasterChef(cakeMasterChef).withdraw(cakeMasterChefPid, 0);
        }
        uint256 cakeAmount = IERC20(cake).balanceOf(address(this));
        if (cakeAmount > 0) {
            // 10% for xDaily stakers
            uint256 xReward = cakeAmount.div(10);
            _swap(cake, wbnb, xReward, address(this));
            _swap(wbnb, dailyToken, IERC20(wbnb).balanceOf(address(this)), feeReceiver);

            cakeAmount = cakeAmount.sub(xReward);
            
            address token0 = IUniswapV2Pair(lpToken).token0();
            address token1 = IUniswapV2Pair(lpToken).token1();
            address fromToken = token0 == wbnb || token0 == busd ? token0 : token1;
            address toToken = fromToken == token0 ? token1 : token0;


            if (toToken == cake) {
                _swap(cake, fromToken, cakeAmount.div(2), address(this));
            } else {
                _swap(cake, fromToken, cakeAmount, address(this));
                _swap(fromToken, toToken, IERC20(fromToken).balanceOf(address(this)).div(2), address(this));    
            }
            _addLp(
                token0, 
                token1, 
                IERC20(token0).balanceOf(address(this)),
                IERC20(token1).balanceOf(address(this)),
                address(this)
            );
        }
    }

    function _invest() internal override {
        uint256 lpAmount = IERC20(lpToken).balanceOf(address(this));
        if (lpAmount > 0) {
            ICakeMasterChef(cakeMasterChef).deposit(cakeMasterChefPid, lpAmount);
        }
    }

    function _exit() internal override {
        (uint256 stakeAmount, ) = ICakeMasterChef(cakeMasterChef).userInfo(cakeMasterChefPid, address(this));
        ICakeMasterChef(cakeMasterChef).withdraw(cakeMasterChefPid, stakeAmount);
    }

    function _exitSome(uint256 _amount) internal override {
        ICakeMasterChef(cakeMasterChef).withdraw(cakeMasterChefPid, _amount);
    }

    function _withdrawFee(uint256 _withdrawAmount, uint256 _lastDepositTime) internal override returns (uint256) {
        if (_lastDepositTime.add(2 days) <= block.timestamp) {
            return 0;
        } 
        uint256 feeAmount = _withdrawAmount.mul(2).div(1000);
        
        IERC20(lpToken).safeTransfer(lpToken, feeAmount);
        IUniswapV2Pair(lpToken).burn(address(this));

        address token0 = IUniswapV2Pair(lpToken).token0();
        address token1 = IUniswapV2Pair(lpToken).token1();

        address fromToken = token0 == wbnb || token0 == busd ? token0 : token1;
        address toToken = fromToken == token0 ? token1 : token0;

        _swap(toToken, fromToken, IERC20(toToken).balanceOf(address(this)), address(this));
        _swap(fromToken, dailyToken, IERC20(fromToken).balanceOf(address(this)), feeReceiver);
        return feeAmount;
    }

    function _totalTokenBalance() internal view override returns (uint256) {
        (uint256 stakeAmount, ) = ICakeMasterChef(cakeMasterChef).userInfo(cakeMasterChefPid, address(this));
        return IERC20(lpToken).balanceOf(address(this)).add(stakeAmount);
    }
    
}


interface ICakeMasterChef {
    function userInfo(uint256 pid, address user) external view returns (uint256, uint256); 
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
}