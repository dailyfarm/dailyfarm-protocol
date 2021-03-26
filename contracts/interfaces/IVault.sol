pragma solidity 0.6.12;

interface IVault {
    function reinvest() external;

    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function withdrawAll() external;

    function tokenBalanceOf(address user) external view returns (uint256);
    function totalTokenBalance() external view returns (uint256);
    function shareBalanceOf(address user) external view returns (uint256);
    function totalShareBalance() external view returns (uint256);
    
}