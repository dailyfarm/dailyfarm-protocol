pragma solidity 0.6.12;

interface IFeeReceiver {
    function getDepositFeeRate(address user, uint256 amount) external view returns(uint256);
    function getWithdrawFeeRate(address user, uint256 amount) external view returns(uint256);
    function notifyFee(address token, uint256 amount) external;
}