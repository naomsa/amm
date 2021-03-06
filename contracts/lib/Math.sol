// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

library Math {
  function sqrt(uint256 x) internal pure returns (uint256 y) {
    uint256 z = (x + 1) / 2;
    y = x;
    while (z < y) {
      y = z;
      z = (x / z + z) / 2;
    }
  }

  function min(uint256 x, uint256 y) internal pure returns (uint256) {
    return x < y ? x : y;
  }
}
