# Supply USDC Script

This script allows you to supply USDC to the Morpho Blue market, making it available for borrowers with wstUSR collateral.

## Prerequisites

1. **USDC tokens** in your wallet on Base network
2. **ETH for gas** on Base network
3. **Private key** with access to the USDC tokens

## Usage

### Basic Usage (1000 USDC)
```bash
forge script scripts/SupplyUsdc.s.sol:SupplyUsdc \
    --rpc-url https://mainnet.base.org \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Custom Amount
```bash
# Supply 5000 USDC (5000 * 10^6 since USDC has 6 decimals)
export SUPPLY_AMOUNT=5000000000

forge script scripts/SupplyUsdc.s.sol:SupplyUsdc \
    --rpc-url https://mainnet.base.org \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Dry Run (Simulation)
```bash
forge script scripts/SupplyUsdc.s.sol:SupplyUsdc \
    --rpc-url https://mainnet.base.org \
    --private-key $PRIVATE_KEY
```

## What the Script Does

1. **Checks your USDC balance** to ensure you have enough tokens
2. **Checks current allowance** for the Morpho contract
3. **Approves the spend** if needed (only the amount being supplied)
4. **Shows your position before** supplying USDC
5. **Supplies the USDC** to the Morpho market
6. **Shows your position after** to confirm the supply
7. **Displays next steps** for earning interest

## Environment Variables

- `PRIVATE_KEY`: Your wallet's private key (required)
- `SUPPLY_AMOUNT`: Amount to supply in USDC units with 6 decimals (optional, defaults to 1000000000 = 1000 USDC)

## Market Details

- **Market**: wstUSR (collateral) / USDC (loan)
- **Your Role**: USDC Lender (you earn interest from borrowers)
- **Borrowers**: Users with wstUSR collateral who borrow your USDC
- **Interest**: Earned based on market utilization and Adaptive Curve IRM
- **Network**: Base mainnet

## Example Output

```
=== Supplying USDC to Morpho Market ===
Morpho contract: 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
Market ID: 0x...
USDC token: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
User address: 0x...
Supply amount: 1000000000
USDC balance: 5000000000
Current allowance: 0

Approving USDC spend...
Approval successful

=== Position Before Supply ===
Supply shares: 0
Borrow shares: 0
Collateral: 0

=== Supplying USDC ===
USDC supplied successfully!
Assets supplied: 1000000000
Shares returned: 1000000000

=== Position After Supply ===
Supply shares: 1000000000
Borrow shares: 0
Collateral: 0

=== Supply Summary ===
Supply shares added: 1000000000
Total supply shares: 1000000000
USDC supplied to market for borrowers
```

## How You Earn Interest

1. **Borrowers borrow your USDC** against their wstUSR collateral
2. **They pay interest** based on the Adaptive Curve IRM
3. **You earn that interest** proportional to your share of total supply
4. **Interest compounds** over time
5. **Higher utilization** = higher interest rates = more earnings

## Market Dynamics

- **Low Utilization**: Lower interest rates, but safer
- **High Utilization**: Higher interest rates, but less liquidity for withdrawals
- **Optimal Range**: Usually 70-90% utilization provides good balance

## After Supplying USDC

Once you've supplied USDC, you can:

1. **Earn interest** as borrowers use your USDC
2. **Monitor utilization** to see how much of your USDC is borrowed
3. **Withdraw USDC** when you need it (subject to available liquidity)
4. **Supply more USDC** to increase your earnings

## Safety Notes

- **Start small** - test with a small amount first
- **Monitor utilization** - high utilization means less liquidity for withdrawals
- **Understand risks** - borrowers could default (though liquidations protect against this)
- **Keep ETH for gas** - you'll need ETH for future transactions

## Withdrawal

When you want to withdraw your USDC:
- You can withdraw at any time if there's available liquidity
- If utilization is 100%, you need to wait for borrowers to repay
- You earn interest on your supplied USDC until withdrawal

## Troubleshooting

- **"Insufficient USDC balance"**: You don't have enough USDC tokens
- **"Approval failed"**: Check that your wallet has ETH for gas
- **"Supply failed"**: The market might not exist or have issues
- **Network errors**: Ensure you're connected to Base mainnet

## Next Steps

After supplying USDC:
1. Monitor your position and earnings
2. Watch market utilization rates
3. Consider supplying more or withdrawing based on market conditions
4. Use withdrawal scripts when you want to exit
