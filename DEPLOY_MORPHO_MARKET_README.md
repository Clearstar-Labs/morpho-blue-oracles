# Generic Morpho Market Deployment Script

This script allows you to deploy a Morpho Blue market on any supported network using environment variables for configuration.

## Setup

1. **Copy environment variables**:
   ```bash
   cp .env.example .env
   ```

2. **Configure your .env file** with the required variables (see below)

3. **Set your private key** and RPC URL for the target network

## Required Environment Variables

### Core Deployment Variables
```bash
# Morpho Blue contract address (network-specific)
MORPHO_CONTRACT=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb

# Token addresses
LOAN_TOKEN=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913      # Token that will be borrowed
COLLATERAL_TOKEN=0xB67675158B412D53fe6B68946483ba920b135bA1  # Token used as collateral

# Oracle address (must be Morpho-compatible)
ORACLE_ADDRESS=0x31fB76310E7AA59f4994af8cb6a420c39669604A

# Interest Rate Model address
IRM_ADDRESS=0x46415998764C29aB2a25CbeA6254146D50D22687

# Loan-to-Value ratio in 18 decimals (915000000000000000 = 91.5%)
LLTV=915000000000000000
```

### Network Configuration
```bash
# Private key (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# RPC URL for target network
ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/your-api-key     # Ethereum
BASE_RPC_URL=https://mainnet.base.org                              # Base
```

## Usage

### Deploy on Ethereum
```bash
# Configure .env for Ethereum
MORPHO_CONTRACT=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
# ... other Ethereum-specific addresses

forge script scripts/DeployMorphoMarket.s.sol:DeployMorphoMarket \
    --rpc-url $ETH_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Deploy on Base
```bash
# Configure .env for Base
MORPHO_CONTRACT=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
# ... other Base-specific addresses

forge script scripts/DeployMorphoMarket.s.sol:DeployMorphoMarket \
    --rpc-url $BASE_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Deploy on Any Network
```bash
# Configure .env for your target network

forge script scripts/DeployMorphoMarket.s.sol:DeployMorphoMarket \
    --rpc-url $YOUR_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

## Network-Specific Addresses

### Ethereum Mainnet
```bash
MORPHO_CONTRACT=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
# Add your specific token and oracle addresses
```

### Base
```bash
MORPHO_CONTRACT=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
LOAN_TOKEN=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913      # USDC
COLLATERAL_TOKEN=0xB67675158B412D53fe6B68946483ba920b135bA1  # wstUSR
```

### Arbitrum
```bash
MORPHO_CONTRACT=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
# Add your specific token and oracle addresses
```

## LLTV Values

Common Loan-to-Value ratios in 18 decimals:
- **50%**: `500000000000000000`
- **70%**: `700000000000000000`
- **80%**: `800000000000000000`
- **85%**: `850000000000000000`
- **90%**: `900000000000000000`
- **91.5%**: `915000000000000000`
- **95%**: `950000000000000000`

## What the Script Does

1. **Validates environment variables** are set correctly
2. **Checks chain ID** (if EXPECTED_CHAIN_ID is set)
3. **Calculates market ID** from parameters
4. **Creates the market** on Morpho Blue
5. **Verifies deployment** by checking parameters
6. **Displays market information** for integration

## Example Output

```
=== Deploying Morpho Market ===
Chain ID: 8453
Morpho contract: 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
Loan token: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
Collateral token: 0xB67675158B412D53fe6B68946483ba920b135bA1
Oracle: 0x31fB76310E7AA59f4994af8cb6a420c39669604A
IRM: 0x46415998764C29aB2a25CbeA6254146D50D22687
LLTV value: 915000000000000000
Calculated Market ID: 0x5a24250884b607439e8eb2a5bf7e4f6647af665936f47d0a8509ff783b3916ec

=== Creating Market ===
Market created successfully!

=== Verifying Market Parameters ===
Market parameters retrieved successfully

[SUCCESS] All parameters verified successfully!

=== Market Summary ===
Market ID: 0x5a24250884b607439e8eb2a5bf7e4f6647af665936f47d0a8509ff783b3916ec
Loan-to-Value Ratio: 91 %
```

## Troubleshooting

- **"Environment variable not found"**: Ensure all required variables are set in .env
- **"Market creation failed"**: Check that all addresses are valid and oracle is compatible
- **"Address has invalid checksum"**: Ensure addresses use proper checksumming
- **Wrong network**: Ensure your RPC URL matches the intended network

## Security Notes

- **Test first**: Always test on testnets before mainnet deployment
- **Verify addresses**: Double-check all token and contract addresses
- **Oracle compatibility**: Ensure oracle follows Morpho's interface requirements
- **LLTV safety**: Choose appropriate loan-to-value ratios for your risk tolerance

## Next Steps

After successful deployment:
1. Note the Market ID for your applications
2. Test market operations with small amounts
3. Monitor oracle price feeds
4. Set up liquidation monitoring if needed
