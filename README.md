# Avalanche Subnet VRF by AvaCloud / NIMA
![Diagram](./images/diagram.png)
[![Lint](https://github.com/NIMA-Enterprises/subnet-vrf/actions/workflows/lint.yml/badge.svg)](https://github.com/NIMA-Enterprises/subnet-vrf/actions/workflows/lint.yml)
[![Unit Tests](https://github.com/NIMA-Enterprises/subnet-vrf/actions/workflows/test.yml/badge.svg)](https://github.com/NIMA-Enterprises/subnet-vrf/actions/workflows/test.yml)
<!---[![Slither Static Analysis](https://github.com/NIMA-Enterprises/subnet-vrf/actions/workflows/slither.yml/badge.svg)](https://github.com/NIMA-Enterprises/subnet-vrf/actions/workflows/slither.yml)--->

## Architecture
Architecture is modular and consists of 4 smart-contracts:
- `VRFProvider` -> A singleton c-chain contract, takes `$LINK` deposits and is a gateway for VRF requests from subnets. Verifies that a call is coming from a verified subnet proxy and forwards the request to Chainlink.

- `VRFProxyRegistry` -> A singleton c-chain contract, being the registry of supported/official subnet proxies. It enables seamless VRFProvider migrations/upgrades. Inherits access-control.

- `VRFProxy` -> A smart contract deployed per subnet, serving as a gateway for VRF requests of consumers of a specific subnet. Verifies that a call is coming from a verified consumer and forwards the request to c-chain VRFProvider through the Teleporter.

- `VRFConsumerRegistry` -> A smart contract deployed per subnet, the registry of allowed consumers. It enables seamless VRFProxy migrations/upgrades. Inherits access-control.

Bonus: - `MockConsumer` -> Simple example testing contract, number guessing game. Once you call `takeAGuess()` VRF request will be sent through the arch. In a short while you will be able to check a response and see if it's fulfilled.

## C-Chain Contracts

As a prerequisite to enable VRF on any subnet AvaCloud will need to deploy `VRFProvider` and `VRFProxyRegistry` contracts once on the C-chain.

Contracts require management from AvaCloud end to:

- Deposit `$LINK` token to the `VRFProvider` contract
- Add Subnet Proxy to `VRFProxyRegistry` whenever AvaCloud user deploys new Proxy on their subnet

Management details:

- `VRFProvider` contract is ownable contract. Initial owner is the deployer of the contract
  - Only owner of the contract can manage teleporter versions (see `TeleporterOwnerUpgradeable.sol`)
  - Only owner can add or remove authorized funders to the contract. Authorized funders are the accounts that can deposit `$LINK` to the contract
- `VRFProxyRegistry` inherits access control
  - Default admin and initial proxy manager accounts are set via constructor during the deployment
  - Only accounts with role `keccak256("PROXY_MANAGER")` can add or remove proxies for the subnets
  - Adding the proxy should be done whenever an AvaCloud user enables the feature and deploys the proxy. Proxy should be removed when an AvaCloud user disables the feature

## Enabling VRF On Subnet

### Prerequisites

- Interoperability enabled on subnet that supports relaying messages from/to C-chain
- C-chain VRF contracts deployed and funded with `$LINK`

### Deployment

Enabling VRF functionality for user subnet requires deployment of 2 contracts by the user:

- `VRFConsumerRegistry`
- `VRFProxy`

`VRFConsumerRegistry` needs to be deployed first because the deployed address of the contract is required as constructor argument for deployment of `VRFProxy` contract.

While initiating deployment of `VRFConsumerRegistry`, registry admin and initial consumer managers need to be passed as constructor parameters.

Once a `VRFProxy` instance is deployed, AvaCloud backend should automatically add the contract to `VRFProviderRegistry` contract on the C-chain.

### Management

Once the above contracts are deployed it is needed to approve the `consumer` contracts on the `VRFConsumerRegistry` contract.

`VRFConsumerRegistry` enables user to:

- See if an address is an approved consumer
- Add consumer
- Remove consumer
- Grant/Revoke role for other wallets to be able to add or remove consumers (only accounts with `keccak256("CONSUMER_MANAGER")` role can add or remove consumers)
- View consumer managers

## Usage

### Deploy

Deployment script deploys the 4 main contracts + funds `VRFProvider` with `$LINK` + mock consumer for testing.

_See `./scripts/deploy.sh` for details._

```shell
$ ./scripts/deploy.sh
```

### Test

Mock consumer provides features of a basic guessing game. Using the following scripts you can make a guess of a random number and later check if the request has been fulfilled.

```shell
$ ./scripts/takeAGuess.sh
```

```shell
$ ./scripts/checkResponse.sh
```

## License

This repository is covered under the Ava Labs Proprietary License. For the complete license terms see [LICENSE](./LICENSE).
