# Supply wstUSR Collateral Script

This script allows you to supply wstUSR as collateral to the Morpho Blue market.

## Prerequisites

1. **wstUSR tokens** in your wallet on Base network
2. **ETH for gas** on Base network
3. **Private key** with access to the wstUSR tokens

## Usage

### Basic Usage (1 wstUSR)
```bash
forge script scripts/SupplyWstUsrCollateral.s.sol:SupplyWstUsrCollateral \
    --rpc-url https://mainnet.base.org \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Custom Amount
```bash
# Supply 5 wstUSR (5 * 10^18)
export SUPPLY_AMOUNT=5000000000000000000

forge script scripts/SupplyWstUsrCollateral.s.sol:SupplyWstUsrCollateral \
    --rpc-url https://mainnet.base.org \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Dry Run (Simulation)
```bash
forge script scripts/SupplyWstUsrCollateral.s.sol:SupplyWstUsrCollateral \
    --rpc-url https://mainnet.base.org \
    --private-key $PRIVATE_KEY
```

## What the Script Does

1. **Checks your wstUSR balance** to ensure you have enough tokens
2. **Checks current allowance** for the Morpho contract
3. **Approves the spend** if needed (only the amount being supplied)
4. **Shows your position before** supplying collateral
5. **Supplies the collateral** to the Morpho market
6. **Shows your position after** to confirm the supply
7. **Displays next steps** for borrowing

## Environment Variables

- `PRIVATE_KEY`: Your wallet's private key (required)
- `SUPPLY_AMOUNT`: Amount to supply in wei (optional, defaults to 1e18 = 1 wstUSR)

## Market Details

- **Market**: wstUSR (collateral) / USDC (loan)
- **LLTV**: 91.5% (you can borrow up to 91.5% of collateral value)
- **Oracle**: Uses your deployed oracle with Pyth + Chainlink feeds
- **Network**: Base mainnet

## Example Output

```
=== Supplying wstUSR Collateral to Morpho ===
Morpho contract: 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
Market ID: 0x...
wstUSR token: 0xC33dCb063E3D9Da00C3fa0a7Cbf9f6670cd7C132
Supply amount: 1000000000000000000
User address: 0x...
wstUSR balance: 5000000000000000000
Current allowance: 0

Approving wstUSR spend...
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

- **"Insufficient wstUSR balance"**: You don't have enough wstUSR tokens
- **"Approval failed"**: Check that your wallet has ETH for gas
- **"Supply failed"**: The market might not exist or have issues
- **Network errors**: Ensure you're connected to Base mainnet

## Next Steps

After supplying collateral, you can:
1. Use the borrow script to borrow USDC
2. Monitor your position health
3. Manage your collateral as needed
