// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract AMM is ERC20("AMM v1", "AMM") {
  IERC20 public immutable token0;

  IERC20 public immutable token1;

  uint256 public reserve0;

  uint256 public reserve1;

  constructor(address _token0, address _token1) {
    token0 = IERC20(_token0);
    token1 = IERC20(_token1);
  }

  function swap(address tokenIn, uint256 amountIn) external returns (uint256 amountOut) {
    require(tokenIn == address(token0) || tokenIn == address(token1), "invalid tokenIn");
    require(amountIn > 0, "amountIn == 0");

    bool isToken0 = tokenIn == address(token0);
    (IERC20 tokenOut, uint256 reserveIn, uint256 reserveOut) = isToken0
      ? (token1, reserve0, reserve1)
      : (token0, reserve1, reserve0);

    IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

    amountOut = (reserveOut * amountIn) / (reserveIn + amountIn);

    tokenOut.transfer(msg.sender, amountOut);

    _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
  }

  function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 shares) {
    token0.transferFrom(msg.sender, address(this), amount0);
    token1.transferFrom(msg.sender, address(this), amount1);

    if (reserve0 > 0 || reserve1 > 0) require(reserve0 * amount1 == reserve1 * amount0, "x / y != dx / dy");

    if (super.totalSupply() == 0) shares = _sqrt(amount0 * amount1);
    else shares = _min((amount0 * super.totalSupply()) / reserve0, (amount1 * super.totalSupply()) / reserve1);

    require(shares > 0, "shares == 0");

    super._mint(msg.sender, shares);

    _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
  }

  function removeLiquidity(uint256 shares) external returns (uint256 amount0, uint256 amount1) {
    require(super.totalSupply() > 0, "totalSupply == 0");

    uint256 bal0 = token0.balanceOf(address(this));
    uint256 bal1 = token1.balanceOf(address(this));

    amount0 = (shares * bal0) / super.totalSupply();
    amount1 = (shares * bal1) / super.totalSupply();
    require(amount0 > 0 && amount1 > 0, "amount0 or amount1 == 0");

    super._burn(msg.sender, shares);
    _update(bal0 - amount0, bal1 - amount1);

    token0.transfer(msg.sender, amount0);
    token1.transfer(msg.sender, amount1);
  }

  function _update(uint256 _reserve0, uint256 _reserve1) internal {
    reserve0 = _reserve0;
    reserve1 = _reserve1;
  }

  function _sqrt(uint256 x) internal pure returns (uint256 y) {
    uint256 z = (x + 1) / 2;
    y = x;
    while (z < y) {
      y = z;
      z = (x / z + z) / 2;
    }
  }

  function _min(uint256 x, uint256 y) internal pure returns (uint256) {
    return x < y ? x : y;
  }
}
