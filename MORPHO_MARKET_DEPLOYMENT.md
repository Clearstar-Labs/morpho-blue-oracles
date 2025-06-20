# Morpho Market Deployment - wstUSR/USDC on Base

This script deploys a new Morpho Blue market for wstUSR (collateral) / USDC (loan) on Base network.

## Market Parameters

- **Loan Token**: USDC (`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`)
- **Collateral Token**: wstUSR (`0xc33dcb063e3d9da00c3fa0a7cbf9f6670cd7c132`)
- **Oracle**: Your deployed oracle (`0x31fB76310E7AA59f4994af8cb6a420c39669604A`)
- **IRM**: Adaptive Curve IRM (`0x46415998764C29aB2a25CbeA6254146D50D22687`)
- **LLTV**: 91.5% (915000000000000000 in 18 decimals)

## Oracle Chain

The oracle calculates wstUSR price in USDC terms using:
1. **WSTUSR/USR** (Pyth): `0x17D099fc623bd06CFE4861d874704Af184773c75`
2. **USR/USD** (Chainlink): `0x4a595E0a62E50A2E5eC95A70c8E612F9746af006`
3. **USDC/USD** (Chainlink): `0x7e860098F58bBFC8648a4311b374B1D669a2bc6B`

## Deployment

```bash
forge script scripts/DeployBaseMorphoMarket.s.sol:DeployBaseMorphoMarket \
    --rpc-url https://mainnet.base.org \
    --private-key $PRIVATE_KEY \
    --broadcast
```

## What This Creates

The script will:
1. Create a new Morpho Blue market with the specified parameters
2. Return a unique Market ID that identifies this market
3. Verify all parameters were set correctly
4. Display integration information

## Market Functionality

Once deployed, users can:

### Suppliers (USDC)
- Supply USDC to earn interest from borrowers
- Withdraw USDC at any time (subject to utilization)
- Earn yield based on market utilization and IRM

### Borrowers (wstUSR → USDC)
- Supply wstUSR as collateral
- Borrow up to 91.5% of collateral value in USDC
- Pay interest based on the Adaptive Curve IRM
- Risk liquidation if collateral value drops

### Liquidators
- Monitor positions that fall below 91.5% health factor
- Liquidate unhealthy positions for profit
- Help maintain market solvency

## Integration

After deployment, use the returned **Market ID** to interact with the market:

```solidity
// Example: Supply USDC
morpho.supply(marketParams, assets, shares, onBehalf, data);

// Example: Supply wstUSR collateral
morpho.supplyCollateral(marketParams, assets, onBehalf, data);

// Example: Borrow USDC
morpho.borrow(marketParams, assets, shares, onBehalf, receiver);
```

## Risk Parameters

- **Maximum LTV**: 91.5%
- **Liquidation Threshold**: 91.5% (same as LTV in Morpho Blue)
- **Oracle Risk**: Dependent on Pyth and Chainlink feed reliability
- **Interest Rate**: Determined by Adaptive Curve IRM based on utilization

## Monitoring

Monitor the market health by watching:
1. **Utilization Rate**: How much of supplied USDC is borrowed
2. **Interest Rates**: Current supply and borrow rates
3. **Oracle Prices**: wstUSR/USDC price from your oracle
4. **Total Supply/Borrow**: Market size and activity

## Next Steps

1. **Deploy the market** using the script
2. **Note the Market ID** for your frontend integration
3. **Test with small amounts** before going live
4. **Monitor oracle feeds** to ensure price accuracy
5. **Set up liquidation bots** if needed for market health
