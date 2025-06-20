# Contract Verification Setup

The deployment script now includes automatic contract verification on Basescan.

## Setup Instructions

### 1. Get a Basescan API Key
1. Go to [Basescan.org](https://basescan.org/)
2. Create an account
3. Navigate to "API Keys" section
4. Generate a new API key

### 2. Set Environment Variable
```bash
export BASESCAN_API_KEY="your_api_key_here"
```

### 3. Alternative: Add to foundry.toml
You can also add the API key to your `foundry.toml` file:

```toml
[etherscan]
base = { key = "your_api_key_here" }
```

## Deployment with Verification

Now when you deploy, verification will happen automatically:

```bash
forge script scripts/DeployBaseWstUsrUsdcOracle.s.sol:DeployBaseWstUsrUsdcOracle \
    --rpc-url https://mainnet.base.org \
    --private-key $PRIVATE_KEY \
    --broadcast
```

## What the Script Does

1. **Deploys the oracle** using the existing factory
2. **Automatically verifies** the contract on Basescan if API key is available
3. **Provides manual verification instructions** if API key is not set
4. **Logs all configuration details** for easy reference

## Manual Verification (if automatic fails)

If automatic verification fails, the script will provide the exact command to run manually:

```bash
forge verify-contract <ORACLE_ADDRESS> \
    src/morpho-chainlink/MorphoChainlinkOracleV2.sol:MorphoChainlinkOracleV2 \
    --chain-id 8453 \
    --etherscan-api-key $BASESCAN_API_KEY \
    --constructor-args <ENCODED_ARGS>
```

## Benefits

- **Transparency**: Users can view the contract source code on Basescan
- **Trust**: Verified contracts show they match the claimed source code
- **Integration**: Other tools and interfaces can interact with verified contracts more easily
- **Debugging**: Easier to debug transactions and view contract state on Basescan

## Troubleshooting

- **"API key not found"**: Set the `BASESCAN_API_KEY` environment variable
- **"Verification failed"**: Check that the API key is valid and has sufficient quota
- **"Contract already verified"**: This is normal if the contract was previously verified
- **"Constructor args mismatch"**: The script automatically encodes the correct constructor arguments
