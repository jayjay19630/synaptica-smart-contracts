# Synaptica Smart Contracts

A comprehensive smart contract system built on Hedera for trustless agent identity management, reputation tracking, validation, and task escrow with multi-verifier consensus.

## Overview

This project implements a decentralized infrastructure for AI agents and marketplace tasks on the Hedera network. The contract suite includes:

- **IdentityRegistry** - Central registry for agent identities with spam protection via registration fees
- **ReputationRegistry** - Track and manage agent reputation scores and history
- **ValidationRegistry** - Validate agent behaviors and interactions
- **TaskEscrow** - Escrow system for marketplace tasks with multi-verifier consensus for secure fund release

The project uses Hardhat for development and supports both Hedera testnet and local node deployments via the [Hedera JSON RPC Relay](https://github.com/hashgraph/hedera-json-rpc-relay).

## Project Structure

- [hardhat.config.js](hardhat.config.js) - Hardhat configuration for Hedera networks, Solidity compiler settings, and deployment tasks

- [/contracts](contracts/) - Core smart contract implementations:
  - [IdentityRegistry.sol](contracts/IdentityRegistry.sol) - Agent identity and domain registration
  - [ReputationRegistry.sol](contracts/ReputationRegistry.sol) - Reputation tracking system
  - [ValidationRegistry.sol](contracts/ValidationRegistry.sol) - Validation and verification logic
  - [TaskEscrow.sol](contracts/TaskEscrow.sol) - Multi-verifier escrow for task payments
  - [/interfaces](contracts/interfaces/) - Contract interfaces for modularity

- [/test](test/) - Comprehensive test suites validating contract functionality and edge cases

- [/scripts](scripts/) - Deployment and utility scripts for Hedera network interactions

- `.env.example` - Environment variable template. Copy to `.env` and configure with your Hedera testnet credentials
  
## Setup

1. Clone this repository:

```shell
git clone git@github.com:ProvidAI/SmartContract.git
cd SmartContract
```

2. Install dependencies:

```shell
npm install
```

3. Configure environment:

```shell
cp .env.example .env
```

Get your Hedera testnet account hex-encoded private key from the [Hedera Developer Portal](https://portal.hedera.com/register) and add it to `.env`:

```
TESTNET_OPERATOR_PRIVATE_KEY=your_private_key_here
```

## Deployment

### Compile Smart Contracts

Before deploying, compile your smart contracts to check for any errors:

```shell
npx hardhat compile
```

This compiles all contracts in [/contracts](contracts/) and generates:
- Contract artifacts in `/artifacts`
- Type definitions and ABIs for contract interaction
- Compilation reports showing any warnings or errors

### Deploy to Hedera Testnet

Deploy the complete contract suite to Hedera testnet:

```shell
npx hardhat deploy-contract
```

The deployment process:
1. Connects to Hedera testnet using your configured private key
2. Deploys contracts in the correct dependency order
3. Links contract references (e.g., IdentityRegistry → ReputationRegistry)
4. Outputs deployed contract addresses for future interactions

**Important**: Ensure your testnet account has sufficient HBAR balance to cover deployment gas fees and contract initialization costs.

## Testing

Run the comprehensive test suite:

```shell
npm test
```

This executes all tests in [/test](test/) to verify contract behavior, security, and edge cases.

