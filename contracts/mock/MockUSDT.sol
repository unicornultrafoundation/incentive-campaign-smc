// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token to represent pUSDT
contract MockERC20 is ERC20 {
    
    constructor() ERC20("pUSDT", "pUSDT") {
        _mint(msg.sender, 1000000*1e6);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}