// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// Deposit ETH
// Track collateral
// Track debt
// Health factor Calculation
// MintPVUSD
// BurnPVUSD (repay)
// Withdraw collateral

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Stablecoin.sol";

error ZeroAmount();
error TransferFailed();
error Undercollateralized();
error InsufficientCollateral();

contract Vault is ReentrancyGuard {

    Stablecoin public immutable stablecoin;

    uint256 public collateralRatio = 150; // 150%
    uint256 public constant PRECISION = 1e18;

    // TEMP price (mocked, replace with oracle tomorrow)
    uint256 public ethPrice = 2000e18; // $2000

    mapping(address => uint256) public collateralETH;
    mapping(address => uint256) public debt;

    event Deposited(address indexed user, uint256 amount);
    event Minted(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor() {
        stablecoin = new Stablecoin(address(this));
    }
}