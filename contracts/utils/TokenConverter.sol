pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";

contract TokenConverter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IUniswapV2Factory public factory;

    constructor(address _factory) public {
        factory = IUniswapV2Factory(_factory);
    }

    function _addLp(
        address token0,
        address token1,
        uint256 amountIn0,
        uint256 amountIn1,
        address to
    ) internal returns (uint256 amount0, uint256 amount1) {
        IUniswapV2Pair pair =
            IUniswapV2Pair(factory.getPair(token0, token1));
        require(address(pair) != address(0), "TokenConverter: Cannot convert");

        (uint256 _reserve0, uint256 _reserve1, ) = pair.getReserves();
        (uint256 reserve0, uint256 reserve1) = pair.token0() == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        if (amountIn0.mul(reserve1) < amountIn1.mul(reserve0)) {
            amount0 = amountIn0;
            amount1 = amountIn0.mul(reserve1).div(reserve0);
        } else {
            amount0 = amountIn1.mul(reserve0).div(reserve1);
            amount1 = amountIn1;
        }
        IERC20(token0).safeTransfer(address(pair), amount0);
        IERC20(token1).safeTransfer(address(pair), amount1);
        pair.mint(to);
    }

    function _swap(
        address fromToken,
        address toToken,
        uint256 amountIn,
        address to
    ) internal returns (uint256 amountOut) {
        if (amountIn == 0) {
            return 0;
        }
        IUniswapV2Pair pair =
            IUniswapV2Pair(factory.getPair(fromToken, toToken));
        require(address(pair) != address(0), "TokenConverter: Cannot convert");

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 amountInWithFee = amountIn.mul(997);
        if (fromToken == pair.token0()) {
            amountOut =
                amountIn.mul(997).mul(reserve1) /
                reserve0.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(0, amountOut, to, new bytes(0));
            // TODO: Add maximum slippage?
        } else {
            amountOut =
                amountIn.mul(997).mul(reserve0) /
                reserve1.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(amountOut, 0, to, new bytes(0));
            // TODO: Add maximum slippage?
        }
    }
}