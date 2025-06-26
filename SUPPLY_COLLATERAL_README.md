# Supply Collateral Script

This script allows you to supply any token as collateral to a Morpho Blue market.

## Prerequisites

1. **Collateral tokens** in your wallet on the target network
2. **ETH for gas** on the target network
3. **Private key** with access to the collateral tokens
4. **Environment variables** configured for your market

## Usage

### Basic Usage (Full Balance)
```bash
forge script scripts/SupplyMorphoCollateral.s.sol:SupplyCollateral \
    --rpc-url $ETH_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Custom Amount
```bash
# Supply specific amount (in token units with decimals)
export SUPPLY_AMOUNT=5000000000000000000

forge script scripts/SupplyMorphoCollateral.s.sol:SupplyCollateral \
    --rpc-url $ETH_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Dry Run (Simulation)
```bash
forge script scripts/SupplyMorphoCollateral.s.sol:SupplyCollateral \
    --rpc-url $ETH_RPC_URL \
    --private-key $PRIVATE_KEY
```

## What the Script Does

1. **Reads market configuration** from environment variables
2. **Checks your collateral token balance** to ensure you have enough tokens
3. **Checks current allowance** for the Morpho contract
4. **Approves the spend** if needed (only the amount being supplied)
5. **Shows your position before** supplying collateral
6. **Supplies the collateral** to the Morpho market
7. **Shows your position after** to confirm the supply
8. **Displays next steps** for borrowing

## Environment Variables

### Required (from .env file)
- `MORPHO_CONTRACT`: Morpho Blue contract address
- `LOAN_TOKEN`: Address of the token that can be borrowed
- `COLLATERAL_TOKEN`: Address of the token being supplied as collateral
- `ORACLE_ADDRESS`: Oracle contract address for the market
- `IRM_ADDRESS`: Interest Rate Model contract address
- `LLTV`: Loan-to-Value ratio in 18 decimals

### Optional
- `PRIVATE_KEY`: Your wallet's private key (required for execution)
- `SUPPLY_AMOUNT`: Amount to supply in token units with decimals (optional, defaults to full balance)

## Market Details

- **Market**: Configured via environment variables (any collateral/loan token pair)
- **LLTV**: Configured via LLTV environment variable
- **Oracle**: Uses oracle specified in ORACLE_ADDRESS
- **Network**: Any network (determined by RPC URL)

## Example Output

```
=== Supplying Collateral to Morpho ===
Chain ID: 8453
Morpho contract: 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
Market ID: 0x...
Collateral token: 0xC33dCb063E3D9Da00C3fa0a7Cbf9f6670cd7C132
Token symbol: wstUSR
User address: 0x...
Supply amount: 1000000000000000000
Token balance: 5000000000000000000
Current allowance: 0

Approving token spend...
Approval successful

=== Position Before Supply ===
Supply shares: 0
Borrow shares: 0
Collateral: 0

=== Supplying Collateral ===
Collateral supplied successfully!

=== Position After Supply ===
Supply shares: 0
Borrow shares: 0
Collateral: 1000000000000000000

=== Supply Summary ===
Collateral added: 1000000000000000000
Total collateral: 1000000000000000000
```

## After Supplying Collateral

Once you've supplied wstUSR collateral, you can:

1. **Borrow USDC** against your collateral (up to 91.5% LTV)
2. **Supply more collateral** to increase borrowing capacity
3. **Withdraw collateral** (if not being used for borrowing)
4. **Monitor your position** health

## Safety Notes

- **Start small** - test with a small amount first
- **Monitor LTV** - keep your loan-to-value ratio well below 91.5%
- **Watch oracle prices** - wstUSR price changes affect your borrowing capacity
- **Keep ETH for gas** - you'll need ETH for future transactions

## Troubleshooting

- **"Insufficient token balance"**: You don't have enough collateral tokens
- **"Approval failed"**: Check that your wallet has ETH for gas
- **"Supply failed"**: The market might not exist or have issues
- **"Environment variable not found"**: Ensure all required variables are set in .env
- **Network errors**: Ensure you're connected to the correct network

## Next Steps

After supplying collateral, you can:
1. Use the borrow script to borrow USDC
2. Monitor your position health
3. Manage your collateral as needed
