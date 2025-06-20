# Read Market Utilization Script

This script reads and displays comprehensive information about the wstUSR/USDC Morpho market, including utilization, interest rates, and market health.

## Usage

```bash
forge script scripts/ReadMarketUtilization.s.sol:ReadMarketUtilization \
    --rpc-url https://mainnet.base.org
```

Note: This is a read-only script, so no `--private-key` or `--broadcast` is needed.

## What the Script Shows

### Market State
- Total USDC supplied to the market
- Total USDC borrowed from the market
- Supply and borrow shares
- Last update timestamp
- Market fee

### Utilization Metrics
- **Utilization Rate**: Percentage of supplied USDC that is borrowed
- **Available Liquidity**: USDC available for withdrawal/borrowing
- **Utilization Status**: Health assessment of the market

### Interest Rates
- **Borrow Rate**: Interest rate borrowers pay (APY)
- **Supply Rate**: Interest rate lenders earn (APY)
- **Rate Calculation**: Based on Adaptive Curve IRM and utilization

### Oracle Information
- Current wstUSR/USDC price from your oracle
- Human-readable price conversion

### Market Health Summary
- Overall market status assessment
- Total Value Locked (TVL)
- Available liquidity for operations

## Example Output

```
=== Morpho Market Utilization Report ===
Market ID: 0x...
Loan Token (USDC): 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
Collateral Token (wstUSR): 0xB67675158B412D53fe6B68946483ba920b135bA1
Oracle: 0x31fB76310E7AA59f4994af8cb6a420c39669604A
IRM: 0x46415998764C29aB2a25CbeA6254146D50D22687
LLTV: 91.5%

=== Market State ===
Total Supply Assets (USDC): 2136803
Total Supply Shares: 2136803
Total Borrow Assets (USDC): 1923123
Total Borrow Shares: 1923123
Last Update: 1750436371
Fee: 0

=== Utilization Metrics ===
Utilization (1e18 = 100%): 900000000000000000
Utilization Percentage: 90
Available Liquidity (USDC): 213680

=== Interest Rates ===
Borrow Rate (per second, 1e18): 317097919
Borrow Rate APY: 10.0%
Supply Rate (per second, 1e18): 285388127
Supply Rate APY: 9.0%

=== Oracle Price ===
wstUSR/USDC Price (scaled by 1e36): 1088546689450181297918350
wstUSR/USDC Price (human readable): 1088546689450181

=== Market Summary ===
Status: High utilization - good for lenders
Total Value Locked (USDC): 2136803
Total Borrowed (USDC): 1923123
Available for Withdrawal (USDC): 213680
```

## Utilization Status Meanings

- **No borrowing activity**: 0% utilization
- **Low utilization**: < 50% - rates may be low
- **Moderate utilization**: 50-80% - healthy balanced market
- **High utilization**: 80-95% - good returns for lenders
- **Very high utilization**: > 95% - limited liquidity for withdrawals

## Use Cases

1. **Monitor Market Health**: Check if the market is functioning properly
2. **Track Utilization**: See how much of supplied USDC is being borrowed
3. **Interest Rate Monitoring**: Track current borrow and supply rates
4. **Liquidity Assessment**: Check available liquidity for withdrawals
5. **Oracle Verification**: Ensure oracle is providing current prices

## Frequency of Use

- **Before Operations**: Check market state before supplying/borrowing
- **Regular Monitoring**: Daily/weekly checks for active positions
- **Troubleshooting**: When transactions fail or rates seem off
- **Market Analysis**: Understanding market dynamics and trends

## No Transaction Required

This script only reads data from the blockchain and doesn't perform any transactions, so:
- No gas fees required
- No private key needed
- No risk of failed transactions
- Can be run as often as needed

Perfect for monitoring your market without any costs! 📊
