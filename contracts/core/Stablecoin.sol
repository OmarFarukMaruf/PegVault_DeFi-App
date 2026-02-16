// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// This contract must be:
    // Be ERC20 compliant
    // Allow minting ONLY by Vault
    // Allow burning ONLY by Vaul
    // Use custom errors
    // Emit proper events

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

error NotVault();
error ZeroAddress();

contract Stablecoin is ERC20 {
    address public immutable vault;

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault();
        _;
    }

    constructor(address _vault)
        ERC20("PegVault USD", "PVUSD")
    {
        if (_vault == address(0)) revert ZeroAddress();
        vault = _vault;
    }

    function mint(address to, uint256 amount) external onlyVault {
        _mint(to, amount);
        emit Mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyVault {
        _burn(from, amount);
        emit Burn(from, amount);
    }
    
}