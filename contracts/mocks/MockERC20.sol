// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20("Mock ERC20", "MOCK") {
  constructor() {
    super._mint(msg.sender, 100);
  }

  function mint(uint256 amount) external {
    super._mint(msg.sender, amount);
  }
}
