# Deploy MorphoChainlinkOracleV2 Script

This script deploys a MorphoChainlinkOracleV2 oracle using the official Morpho factory on Ethereum.

## Prerequisites

1. **Ethereum mainnet access** (factory is deployed on Ethereum)
2. **ETH for gas** on Ethereum
3. **Private key** with deployment permissions
4. **Chainlink price feeds** for your token pairs
5. **Vault contracts** (ERC4626) for base and quote tokens

## Factory Details

- **Default Factory**: `0x3A7bB36Ee3f3eE32A60e9f2b33c1e5f2E83ad766` (Ethereum Mainnet)
- **Configurable**: Factory address can be set via environment variable
- **Verified Contract**: [View on Etherscan](https://etherscan.io/address/0x3A7bB36Ee3f3eE32A60e9f2b33c1e5f2E83ad766#code)

## Environment Variables Required

### Core Parameters
```bash
# Factory address (configurable for different networks)
MORPHO_CHAINLINK_ORACLE_V2_FACTORY=0x3A7bB36Ee3f3eE32A60e9f2b33c1e5f2E83ad766

# Vault contracts (ERC4626) - OPTIONAL: use address(0) to omit
BASE_VAULT=0x...                    # Base token vault (e.g., wstETH vault) or 0x0
QUOTE_VAULT=0x...                   # Quote token vault (e.g., USDC vault) or 0x0

# Conversion samples - OPTIONAL: defaults to 1 if not set
BASE_VAULT_CONVERSION_SAMPLE=1000000000000000000    # Vault sample amount, or 1 for non-vault
QUOTE_VAULT_CONVERSION_SAMPLE=1000000               # Vault sample amount, or 1 for non-vault

# Chainlink price feeds - OPTIONAL: use address(0) if price = 1
BASE_FEED_1=0x...                   # Primary base token feed or 0x0
QUOTE_FEED_1=0x...                  # Primary quote token feed or 0x0

# Secondary feeds - OPTIONAL: use address(0) if price = 1 or not needed
BASE_FEED_2=0x0000000000000000000000000000000000000000
QUOTE_FEED_2=0x0000000000000000000000000000000000000000

# Token decimals - REQUIRED
BASE_TOKEN_DECIMALS=18              # Decimals of base token
QUOTE_TOKEN_DECIMALS=6              # Decimals of quote token

# Optional salt for deterministic deployment
SALT=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

### Deployment Variables
```bash
PRIVATE_KEY=your_private_key_here
ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/your-api-key
```

## Usage

### Basic Deployment
```bash
forge script scripts/DeployMorphoChainlinkOracleV2.s.sol:DeployMorphoChainlinkOracleV2 \
    --rpc-url $ETH_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Hemi Deployment

If deploying on Hemi, set `HEMI_RPC_URL` and use it for `--rpc-url`. Ensure you have deployed or set the factory address for Hemi.

```bash
forge script scripts/DeployMorphoChainlinkOracleV2.s.sol:DeployMorphoChainlinkOracleV2 \
    --rpc-url $HEMI_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Dry Run (Simulation)
```bash
forge script scripts/DeployMorphoChainlinkOracleV2.s.sol:DeployMorphoChainlinkOracleV2 \
    --rpc-url $ETH_RPC_URL \
    --private-key $PRIVATE_KEY
```

## Example Configurations

### wstETH/USDC Oracle
```bash
MORPHO_CHAINLINK_ORACLE_V2_FACTORY=0x3A7bB36Ee3f3eE32A60e9f2b33c1e5f2E83ad766

BASE_VAULT=0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0      # wstETH
BASE_VAULT_CONVERSION_SAMPLE=1000000000000000000
BASE_FEED_1=0x86392dC19c0b719886221c78AB11eb8Cf5c52812      # stETH/ETH feed
BASE_FEED_2=0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419      # ETH/USD feed
BASE_TOKEN_DECIMALS=18

QUOTE_VAULT=0xA0b86a33E6441E6C8C07C1B0B4C8C5C0E6C8C5C0    # USDC vault
QUOTE_VAULT_CONVERSION_SAMPLE=1000000
QUOTE_FEED_1=0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6      # USDC/USD feed
QUOTE_FEED_2=0x0000000000000000000000000000000000000000
QUOTE_TOKEN_DECIMALS=6
```

### BOLD/sBOLD Oracle
```bash
MORPHO_CHAINLINK_ORACLE_V2_FACTORY=0x3A7bB36Ee3f3eE32A60e9f2b33c1e5f2E83ad766

BASE_VAULT=0x50Bd66D59911F5e086Ec87aE43C811e0D059DD11      # sBOLD vault
BASE_VAULT_CONVERSION_SAMPLE=1000000000000000000
BASE_FEED_1=0x...                                           # BOLD price feed
BASE_FEED_2=0x0000000000000000000000000000000000000000
BASE_TOKEN_DECIMALS=18

QUOTE_VAULT=0x6440f144b7e50D6a8439336510312d2F54beB01D      # BOLD vault
QUOTE_VAULT_CONVERSION_SAMPLE=1000000000000000000
QUOTE_FEED_1=0x...                                           # BOLD price feed
QUOTE_FEED_2=0x0000000000000000000000000000000000000000
QUOTE_TOKEN_DECIMALS=18
```

## What the Script Does

1. **Validates environment variables** are set correctly
2. **Displays configuration** for review before deployment
3. **Calls factory contract** to deploy oracle
4. **Verifies deployment** using factory's verification function
5. **Displays oracle address** and integration details

## Example Output

```
=== Deploying MorphoChainlinkOracleV2 ===
Chain ID: 1
Factory: 0x3A7bB36Ee3f3eE32A60e9f2b33c1e5f2E83ad766
Base Vault: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
Base Symbol: wstETH
Quote Vault: 0xA0b86a33E6441E6C8C07C1B0B4C8C5C0E6C8C5C0
Quote Symbol: USDC

=== Creating Oracle ===
Oracle deployed successfully!
Oracle address: 0x1234567890abcdef1234567890abcdef12345678

=== Deployment Summary ===
Oracle Address: 0x1234567890abcdef1234567890abcdef12345678
Oracle Type: MorphoChainlinkOracleV2
Base Token: wstETH
Quote Token: USDC
Factory Verified: true

=== Integration Details ===
Use this oracle address in your Morpho market:
ORACLE_ADDRESS= 0x1234567890abcdef1234567890abcdef12345678
```

## Oracle Parameters Explained

### Parameter Usage Patterns

#### When to use address(0):
- **Vaults**: Set to `address(0)` when token is not a vault (direct token)
- **Feeds**: Set to `address(0)` when price = 1 (no conversion needed)

#### Conversion Samples:
- **With Vault**: Use appropriate sample amount (e.g., `1e18` for 18-decimal vault)
- **Without Vault**: Defaults to `1` (no conversion needed)
- **Purpose**: Amount of vault shares to convert to underlying assets for rate calculation

#### Common Configurations:

**Direct Token Pair (no vaults)**:
```bash
BASE_VAULT=0x0000000000000000000000000000000000000000
BASE_VAULT_CONVERSION_SAMPLE=1
QUOTE_VAULT=0x0000000000000000000000000000000000000000
QUOTE_VAULT_CONVERSION_SAMPLE=1
```

**Vault-based Token**:
```bash
BASE_VAULT=0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0  # wstETH vault
BASE_VAULT_CONVERSION_SAMPLE=1000000000000000000        # 1e18
```

**Price = 1 (no feed needed)**:
```bash
BASE_FEED_1=0x0000000000000000000000000000000000000000  # Price = 1
BASE_FEED_2=0x0000000000000000000000000000000000000000  # Not needed
```

### Price Feed Combinations
- **Single Feed**: Token/USD direct feed
- **Dual Feed**: Token/ETH + ETH/USD for tokens without direct USD feeds
- **No Feed**: Use address(0) when price = 1

## Testing the Oracle

After deployment, test the oracle:

```bash
# Test oracle price function
cast call $ORACLE_ADDRESS "price()(uint256)" --rpc-url $ETH_RPC_URL
```

## Troubleshooting

- **"Environment variable not found"**: Ensure all required variables are set
- **"Oracle deployment failed"**: Check that all feed addresses are valid
- **"Oracle verification failed"**: Factory couldn't verify the deployment
- **"Vault conversion sample is zero"**: Conversion samples must be > 0

## Integration

Use the deployed oracle address in your Morpho market deployment:

```bash
# Add to your .env for market deployment
ORACLE_ADDRESS=0x1234567890abcdef1234567890abcdef12345678
```

## Security Notes

- **Verify feeds**: Ensure Chainlink feeds are active and reliable
- **Test thoroughly**: Always test oracle prices before using in production
- **Monitor feeds**: Set up monitoring for feed health and price deviations
- **Understand risks**: Oracle failures can affect market operations

## Next Steps

1. **Test oracle functionality** with price calls
2. **Verify price accuracy** against expected values
3. **Use in market deployment** with DeployMorphoMarket.s.sol
4. **Set up monitoring** for oracle health
5. **Document configuration** for future reference
