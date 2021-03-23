pragma solidity 0.6.12;

interface IRewardLocker {
    function getLockAmount(address user, uint256 rewardTime, uint256 amount) external view returns(uint256);
    function lock(address user, uint256 rewardTime, uint256 amount) external;
}