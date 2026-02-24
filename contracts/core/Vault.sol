// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

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
error NotGovernance();

contract Vault is ReentrancyGuard {

    Stablecoin public immutable stablecoin;

    uint256 public collateralRatio = 150; // 150%
    AggregatorV3Interface public priceFeed;
    uint256 public constant ORACLE_TIMEOUT = 3 hours;
    uint256 public constant PRECISION = 1e18;
    uint256 public liquidationBonus = 5;
    address public governance;

    mapping(address => uint256) public collateralETH;
    mapping(address => uint256) public debt;

    event Deposited(address indexed user, uint256 amount);
    event Minted(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    modifier onlyGovernance() {
        if (msg.sender != governance) revert NotGovernance();
        _;
    }

    constructor(address _priceFeed, address _governance) {
    priceFeed = AggregatorV3Interface(_priceFeed);
    stablecoin = new Stablecoin(address(this));
    governance = _governance;
    }

    function _getETHPrice() internal view returns (uint256) {
    (
        ,
        int256 price,
        ,
        uint256 updatedAt,
        
    ) = priceFeed.latestRoundData();

    require(price > 0, "Invalid price");
    require(
        block.timestamp - updatedAt <= ORACLE_TIMEOUT,
        "Stale price"
    );

    // Chainlink returns 8 decimals
    // Normalize to 18 decimals
    return uint256(price) * 1e10;
    }

    function setCollateralRatio(uint256 newRatio) external onlyGovernance
    {
        require(newRatio >= 110, "Too low");
        collateralRatio = newRatio;
    }

    function setLiquidationBonus(uint256 newBonus) external onlyGovernance
    {
        require(newBonus <= 20, "Too high");
        liquidationBonus = newBonus;
    }

    // Deposit ETH
    // -------------------------

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();

        collateralETH[msg.sender] += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    // Mint PVUSD
    // -------------------------

    function mint(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 newDebt = debt[msg.sender] + amount;

        if (!_isHealthy(msg.sender, newDebt))
            revert Undercollateralized();

        debt[msg.sender] = newDebt;

        stablecoin.mint(msg.sender, amount);

        emit Minted(msg.sender, amount);
    }

    // Burn (Repay)
    // -------------------------

    function burn(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        stablecoin.transferFrom(msg.sender, address(this), amount);

        debt[msg.sender] -= amount;

        stablecoin.burn(address(this), amount);

        emit Burned(msg.sender, amount);
    }

    // Withdraw ETH
    // -------------------------

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (collateralETH[msg.sender] < amount)
            revert InsufficientCollateral();

        collateralETH[msg.sender] -= amount;

        if (!_isHealthy(msg.sender, debt[msg.sender]))
            revert Undercollateralized();

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function liquidate(address user, uint256 debtToCover) external nonReentrant {
    require(healthFactor(user) < 1e18, "User is healthy");
    require(debtToCover > 0, "Zero amount");
    require(debt[user] >= debtToCover, "Too much debt");

    uint256 ethPrice = _getETHPrice();

    // Calculate ETH equivalent of debt
    uint256 collateralEquivalent =
        (debtToCover * PRECISION) / ethPrice;

    // Add liquidation bonus
    uint256 bonus =
        (collateralEquivalent * liquidationBonus) / 100;

    uint256 totalCollateralToSeize =
        collateralEquivalent + bonus;

    require(
        collateralETH[user] >= totalCollateralToSeize,
        "Not enough collateral"
    );

    // Transfer stablecoin from liquidator
    stablecoin.transferFrom(
        msg.sender,
        address(this),
        debtToCover
    );

    // Burn the repaid stablecoin
    stablecoin.burn(address(this), debtToCover);

    // Update debt
    debt[user] -= debtToCover;

    // Reduce collateral
    collateralETH[user] -= totalCollateralToSeize;

    // Send ETH to liquidator
    (bool success, ) = payable(msg.sender).call{
        value: totalCollateralToSeize
    }("");

    if (!success) revert TransferFailed();
    
    }

    // Health Factor
    // -------------------------

    function healthFactor(address user) public view returns (uint256) {
        if (debt[user] == 0) return type(uint256).max;

        uint256 ethPrice = _getETHPrice();

        uint256 collateralValue = (collateralETH[user] * ethPrice) / PRECISION;

        uint256 requiredCollateral = (debt[user] * collateralRatio) / 100;

        return (collateralValue * PRECISION) / requiredCollateral;       
    }

    function _isHealthy(address user, uint256 newDebt)
        internal
        view
        returns (bool)
    {
        if (newDebt == 0) return true;

        uint256 collateralValue =
            (collateralETH[user] * _getETHPrice()) / PRECISION;

        return
            (collateralValue * 100) >=
            (newDebt * collateralRatio);
    }

    receive() external payable {}
}