# Basic Usage

## Deploy your smart contract

To deploy to a local network, run:

```shell
bunx settlemint scs hardhat deploy local -m ignition/modules/FullDeployment.ts
```

To deploy to the platform, run:

```shell
bunx settlemint scs hardhat deploy remote -m ignition/modules/FullDeployment.ts
```

## Deploy your subgraph

To index your smart contract events, use The Graph middleware.
First, edit `subgraph/subgraph.config.json` to set the addresses of your smart contracts. You can find them in the deployment folder created under `ignition`. Then, run:

```shell
bunx settlemint login
```

This logs you in to the platform. This command only needs to be run once, so you can skip it if you've already logged in.

Then, run:

```shell
bunx settlemint scs subgraph deploy
```

## Help

To get info about the tasks, run:

```shell
bunx settlemint scs hardhat --help
bunx settlemint scs subgraph --help
```
