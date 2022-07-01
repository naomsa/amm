// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./lib/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AMM is ERC20("AMM v1", "AMM") {
  IERC20 public immutable token0;

  IERC20 public immutable token1;

  uint256 public reserve0;

  uint256 public reserve1;

  constructor(address _token0, address _token1) {
    token0 = IERC20(_token0);
    token1 = IERC20(_token1);
  }

  function swap(address _tokenIn, uint256 amountIn) external returns (uint256 amountOut) {
    require(_tokenIn == address(token0) || _tokenIn == address(token1), "invalid tokenIn");
    require(amountIn > 0, "amountIn == 0");

    (IERC20 tokenIn, IERC20 tokenOut, uint256 reserveIn, uint256 reserveOut) = _sort(_tokenIn);

    tokenIn.transferFrom(msg.sender, address(this), amountIn);

    tokenOut.transfer(msg.sender, (amountOut = (reserveOut * amountIn) / (reserveIn + amountIn)));

    _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
  }

  function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 shares) {
    token0.transferFrom(msg.sender, address(this), amount0);
    token1.transferFrom(msg.sender, address(this), amount1);

    if (super.totalSupply() == 0) {
      shares = Math.sqrt(amount0 * amount1);
    } else {
      require(reserve0 / reserve1 == amount0 * amount1, "x / y != dx / dy");
      shares = Math.min((amount0 * super.totalSupply()) / reserve0, (amount1 * super.totalSupply()) / reserve1);
    }

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

  function _sort(address _tokenIn)
    internal
    view
    returns (
      IERC20 tokenIn,
      IERC20 tokenOut,
      uint256 reserveIn,
      uint256 reserveOut
    )
  {
    return _tokenIn == address(token0) ? (token0, token1, reserve0, reserve1) : (token1, token0, reserve1, reserve0);
  }
}
