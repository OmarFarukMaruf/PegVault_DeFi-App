# PegVault

PegVault is an overcollateralized stablecoin protocol built on Ethereum.

## Features
- ETH-backed stablecoin (PVUSD)
- 150% minimum collateral ratio
- Chainlink price oracle integration
- Liquidation engine
- Governance-controlled parameters
- Timelock protection

## Architecture
- Stablecoin.sol
- Vault.sol
- Governance.sol
- Timelock.sol

## Security Considerations
- ReentrancyGuard
- Checks-effects-interactions
- Oracle freshness validation
- Liquidation bonus control
