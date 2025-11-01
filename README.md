# Hedera Hardhat Example Project

This Hedera Hardhat Example Project offers boilerplate code for testing and deploying smart contracts via Hardhat. It includes configuration for both community-hosted and local ([Hedera Local Node](https://github.com/hashgraph/hedera-local-node)) instances of the [Hedera JSON RPC Relay](https://github.com/hashgraph/hedera-json-rpc-relay). 

:fire: Check out the step-by-step tutorial [here](https://docs.hedera.com/hedera/tutorials/smart-contracts/deploy-a-smart-contract-using-hardhat-and-hedera-json-rpc-relays).

## Project Files and Folders

- `hardhat.config.js` - This is the configuration file for your Hardhat project development environment. It centralizes and defines various settings like Hedera networks, Solidity compiler versions, plugins, and tasks.

- `/contracts` - This folder holds all the Solidity smart contract files that make up the core logic of your dApp. Contracts are written in `.sol` files.

- `/test` - This folder contains test scripts that help validate your smart contracts' functionality. These tests are crucial for ensuring that your contracts behave as expected.
  
-  `/scripts` - This folder contains essential JavaScript files for tasks such as deploying smart contracts to the Hedera network. 

- `.env.example` - This file is contains the environment variables needed by the project. Copy this file to a `.env` file and fill in the actual values before starting the development server or deploying smart contracts. To expedite your test setup and deployment, some variables are pre-filled in this example file.
  
## Setup

1. Clone this repo to your local machine:

```shell
git clone git@github.com:ProvidAI/SmartContract.git
```

2. Once you've cloned the repository, open your IDE terminal and navigate to the root directory of the project:

```shell
cd SmartContract
```

3. Run the following command to install all the necessary dependencies:

```shell
npm install
```

4. Get your Hedera testnet account hex encoded private key from the [Hedera Developer Portal](https://portal.hedera.com/register) and update the `.env.example` `TESTNET_OPERATOR_PRIVATE_KEY`

5. Rename `.env.example` to `.env`

6. Run `npx hardhat deploy-contract`

