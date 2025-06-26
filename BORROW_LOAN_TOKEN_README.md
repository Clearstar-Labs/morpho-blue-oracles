# Borrow Loan Token Script

This script allows you to borrow any loan token against your collateral in a Morpho Blue market.

## Prerequisites

1. **Collateral** already supplied to the market (use `SupplyMorphoCollateral.s.sol` first)
2. **ETH for gas** on the target network
3. **Private key** with access to the collateral position
4. **Environment variables** configured for your market

## Usage

### Basic Usage
```bash
# Set borrow amount first
export BORROW_AMOUNT=1000000000

forge script scripts/BorrowMorphoLoanToken.s.sol:BorrowMorphoLoanToken \
    --rpc-url $ETH_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Custom Amount
```bash
# Borrow specific amount (in token units with decimals)
export BORROW_AMOUNT=1000000000

forge script scripts/BorrowMorphoLoanToken.s.sol:BorrowMorphoLoanToken \
    --rpc-url $ETH_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Dry Run (Simulation)
```bash
export BORROW_AMOUNT=1000000000

forge script scripts/BorrowMorphoLoanToken.s.sol:BorrowMorphoLoanToken \
    --rpc-url $ETH_RPC_URL \
    --private-key $PRIVATE_KEY
```

## What the Script Does

1. **Reads market configuration** from environment variables
2. **Checks your collateral position** to ensure you have collateral supplied
3. **Fetches current oracle price** for collateral/loan token pair
4. **Calculates maximum borrowable** amount based on LLTV
5. **Validates borrow amount** against maximum borrowable
6. **Shows health factor** after borrowing
7. **Executes the borrow** transaction
8. **Displays position summary** and risk management info

## Environment Variables

### Required (from .env file)
- `MORPHO_CONTRACT`: Morpho Blue contract address
- `LOAN_TOKEN`: Address of the token being borrowed
- `COLLATERAL_TOKEN`: Address of the token used as collateral
- `ORACLE_ADDRESS`: Oracle contract address for the market
- `IRM_ADDRESS`: Interest Rate Model contract address
- `LLTV`: Loan-to-Value ratio in 18 decimals

### Required for execution
- `PRIVATE_KEY`: Your wallet's private key
- `BORROW_AMOUNT`: Amount to borrow in token units with decimals (required)

## Market Details

- **Collateral**: Configured via COLLATERAL_TOKEN (must be supplied first)
- **Loan**: Configured via LOAN_TOKEN (what you receive)
- **Maximum LTV**: Configured via LLTV environment variable
- **Interest**: Accrues over time based on configured IRM
- **Liquidation**: If health factor drops below 100%
- **Network**: Any network (determined by RPC URL)

## Example Output

```
=== Borrowing Loan Token from Morpho Market ===
Chain ID: 8453
Morpho contract: 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
Market ID: 0x...
Loan token: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
Loan token symbol: USDC
Collateral token: 0xB67675158B412D53fe6B68946483ba920b135bA1
Collateral token symbol: wstUSR
User address: 0x...
Borrow amount: 500000000

=== Current Position ===
Supply shares: 0
Borrow shares: 0
Collateral: 1000000000000000000

Current oracle price (scaled by 1e36): 1088546689450181297918350
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

- **"No collateral found"**: Supply collateral tokens first using SupplyMorphoCollateral.s.sol
- **"Borrow amount exceeds maximum"**: Reduce borrow amount or add more collateral
- **"Could not fetch oracle price"**: Oracle might be temporarily unavailable
- **"Borrow failed"**: Market might not have enough loan token liquidity
- **"Environment variable not found"**: Ensure all required variables are set in .env
- **"BORROW_AMOUNT environment variable not set"**: Set the BORROW_AMOUNT before running

## Next Steps

After borrowing loan tokens:
1. Use your borrowed tokens for intended purpose
2. Monitor your position health regularly
3. Plan for interest payments and eventual repayment
4. Consider using repay scripts when ready to repay
5. Market ID for reference is displayed in the output
