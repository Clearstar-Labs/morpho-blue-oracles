#!/bin/bash

# Source environment variables if .env file exists
if [ -f .env ]; then
  source .env
  echo "Loaded environment variables from .env file"
fi

# Check if ETHERSCAN_API_KEY is set
if [ -z "$ETHERSCAN_API_KEY" ]; then
  echo "Warning: ETHERSCAN_API_KEY environment variable is not set."
  echo "Please set it in your .env file or export it directly."
  echo "Continuing with default key, but this may fail or hit rate limits."
fi

# Verify NetAssetValueChainlinkAdapter contract
echo "Verifying NetAssetValueChainlinkAdapter contract..."
forge verify-contract \
  --chain-id 1 \
  --compiler-version 0.8.21 \
  --optimizer-runs 999999 \
  --via-ir \
  --evm-version shanghai \
  --etherscan-api-key "${ETHERSCAN_API_KEY}" \
  0xDd957FbBdB549B957A1Db92b88bBA5297D0BbE99 \
  src/fxusd-nav-adapter/NetAssetValueChainlinkAdapter.sol:NetAssetValueChainlinkAdapter \
  --constructor-args $(cast abi-encode "constructor(address,uint256,address)" 0x7743e50F534a7f9F1791DdE7dCD89F7783Eefc39 1213464970549442365 0x72882eb5D27C7088DFA6DDE941DD42e5d184F0ef)

# Check if verification was successful
if [ $? -eq 0 ]; then
  echo "✅ Contract verification successful!"
else
  echo "❌ Contract verification failed."
  echo "Please check the error message above and ensure your ETHERSCAN_API_KEY is valid."
fi
