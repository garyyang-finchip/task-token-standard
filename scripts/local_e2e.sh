#!/usr/bin/env bash
# local_e2e.sh — compile (solc-js) -> local chain (ganache) -> full lifecycle smoke test.
# No Foundry required; mirrors the ERC-8338 ec2_e2e.sh philosophy.
# Prereqs: node >= 18; npm i -g solc@0.8.24 ganache; npm i ethers@6 (in repo root)
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf solc-out && mkdir -p solc-out
solcjs --bin --abi --optimize --optimize-runs 1 --base-path . \
  contracts/TaskToken.sol contracts/TaskVault.sol \
  contracts/verifiers/HashlockVerifier.sol contracts/judgment/JuryPanel.sol \
  contracts/interfaces/ITaskToken.sol contracts/interfaces/ITaskTender.sol \
  contracts/interfaces/ITaskVerifier.sol contracts/interfaces/IOnchainTaskDocument.sol \
  scripts/helpers/SmokeFixtures.sol \
  -o solc-out

ganache --wallet.mnemonic "test test test test test test test test test test test junk" \
  --chain.chainId 31337 > /tmp/ganache-e2e.log 2>&1 &
GPID=$!
trap "kill $GPID 2>/dev/null || true" EXIT
for i in $(seq 1 25); do sleep 1; grep -q "Listening" /tmp/ganache-e2e.log && break; done

SOLC_OUT=solc-out node scripts/smoke.mjs
