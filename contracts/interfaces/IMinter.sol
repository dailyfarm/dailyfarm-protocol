pragma solidity 0.6.12;

interface IMinter {
    function mint(address to, uint256 amount) external;
}