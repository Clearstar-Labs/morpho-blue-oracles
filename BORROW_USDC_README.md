# Borrow USDC Script

This script allows you to borrow USDC against your wstUSR collateral in the Morpho Blue market.

## Prerequisites

1. **wstUSR collateral** already supplied to the market (use `SupplyWstUsrCollateral.s.sol` first)
2. **ETH for gas** on Base network
3. **Private key** with access to the collateral position

## Usage

### Basic Usage (500 USDC)
```bash
forge script scripts/BorrowUsdc.s.sol:BorrowUsdc \
    --rpc-url https://mainnet.base.org \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Custom Amount
```bash
# Borrow 1000 USDC (1000 * 10^6 since USDC has 6 decimals)
export BORROW_AMOUNT=1000000000

forge script scripts/BorrowUsdc.s.sol:BorrowUsdc \
    --rpc-url https://mainnet.base.org \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Dry Run (Simulation)
```bash
forge script scripts/BorrowUsdc.s.sol:BorrowUsdc \
    --rpc-url https://mainnet.base.org \
    --private-key $PRIVATE_KEY
```

## What the Script Does

1. **Checks your collateral position** to ensure you have wstUSR supplied
2. **Fetches current oracle price** for wstUSR/USDC
3. **Calculates maximum borrowable** amount (91.5% of collateral value)
4. **Validates borrow amount** against maximum borrowable
5. **Shows health factor** after borrowing
6. **Executes the borrow** transaction
7. **Displays position summary** and risk management info

## Environment Variables

- `PRIVATE_KEY`: Your wallet's private key (required)
- `BORROW_AMOUNT`: Amount to borrow in USDC units with 6 decimals (optional, defaults to 500000000 = 500 USDC)

## Market Details

- **Collateral**: wstUSR (must be supplied first)
- **Loan**: USDC (what you receive)
- **Maximum LTV**: 91.5% (you can borrow up to 91.5% of collateral value)
- **Interest**: Accrues over time based on Adaptive Curve IRM
- **Liquidation**: If health factor drops below 100%

## Example Output

```
=== Borrowing USDC from Morpho Market ===
Morpho contract: 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
Market ID: 0x...
USDC token: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
User address: 0x...
Borrow amount: 500000000

=== Current Position ===
Supply shares: 0
Borrow shares: 0
Collateral (wstUSR): 1000000000000000000

Current wstUSR/USDC price (scaled by 1e36): 1088546689450181297918350
Maximum borrowable USDC: 995820000
Requested borrow amount: 500000000
Health factor after borrow (1e18 = 100%): 1991640000000000000
USDC balance before borrow: 0

=== Borrowing USDC ===
USDC borrowed successfully!
Assets borrowed: 500000000
Shares borrowed: 500000000

=== Position After Borrow ===
Supply shares: 0
Borrow shares: 500000000
Collateral: 1000000000000000000
USDC balance after borrow: 500000000

=== Borrow Summary ===
Borrow shares added: 500000000
Total borrow shares: 500000000
USDC received: 500000000
Collateral used: 1000000000000000000
```

## Health Factor Explained

- **Health Factor = (Collateral Value * 91.5%) / Borrowed Amount**
- **Above 100%**: Safe position
- **Below 100%**: Risk of liquidation
- **Recommended**: Keep above 110% for safety buffer

## Interest Accrual

- **Interest accrues** on your borrowed USDC over time
- **Rate depends** on market utilization (Adaptive Curve IRM)
- **Higher utilization** = higher interest rates
- **You owe more** USDC over time due to interest

## Risk Management

### Safe Practices:
1. **Borrow conservatively** - don't max out your LTV
2. **Monitor oracle prices** - wstUSR price changes affect your position
3. **Keep safety buffer** - aim for 70-80% LTV instead of 91.5%
4. **Set price alerts** - know when your position becomes risky
5. **Have repayment plan** - know how you'll repay the loan

### Warning Signs:
- Health factor dropping below 110%
- wstUSR price declining significantly
- High interest rates increasing your debt quickly

## After Borrowing

Once you've borrowed USDC, you should:

1. **Monitor your position** regularly
2. **Track interest accrual** on your debt
3. **Watch wstUSR/USDC price** movements
4. **Plan for repayment** or collateral management
5. **Consider partial repayments** to reduce risk

## Liquidation Risk

You face liquidation if:
- **Health factor drops below 100%**
- **wstUSR price falls** relative to USDC
- **Interest accrual** increases your debt significantly

Liquidation means:
- Part of your collateral is sold to repay debt
- You lose some wstUSR but debt is reduced
- Liquidation penalty may apply

## Safety Notes

- **Start small** - test with a small borrow amount first
- **Understand risks** - you can lose your collateral if liquidated
- **Monitor actively** - crypto prices can move quickly
- **Have exit strategy** - know how you'll repay or manage the position

## Troubleshooting

- **"No collateral found"**: Supply wstUSR collateral first
- **"Borrow amount exceeds maximum"**: Reduce borrow amount or add more collateral
- **"Could not fetch oracle price"**: Oracle might be temporarily unavailable
- **"Borrow failed"**: Market might not have enough USDC liquidity

## Next Steps

After borrowing USDC:
1. Use your borrowed USDC for intended purpose
2. Monitor your position health regularly
3. Plan for interest payments and eventual repayment
4. Consider using `RepayUsdc.s.sol` when ready to repay
