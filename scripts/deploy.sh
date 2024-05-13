#!/usr/bin/env bash

# Enable constructor-args
set -e

REPO_BASE_PATH=$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  cd .. && pwd
)

source $REPO_BASE_PATH/.env
source $REPO_BASE_PATH/scripts/utils.sh

# Retrieve the user address from private key
user_address=$(cast wallet address --private-key $user_private_key)

# Calculate the next expected contract address for the given deployer on both the C-Chain and Subnet.
# These nonces/addresses will be used to deploy the VRF Provider and Proxy contracts to.

# Retrieve nonces to use for address computation.
c_chain_nonce=$(cast nonce $user_address --rpc-url $c_chain_url);
subnet_nonce=$(cast nonce $user_address --rpc-url $subnet_url);

# Compute VRFProxyRegistry C-Chain address.
computed_proxy_registry_contract_address=$(cast compute-address $user_address --rpc-url $c_chain_url)
vrf_proxy_registry_address=$(parseComputedContractAddress "$computed_provider_contract_address")

# Compute VRFProvider C-Chain address.
computed_provider_contract_address=$(cast compute-address $user_address --nonce ((++c_chain_nonce)) --rpc-url $c_chain_url)
vrf_provider_address=$(parseComputedContractAddress "$computed_provider_contract_address")

# Compute VRFConsume Registry Subnet address.
computed_consumer_registry_contract_address=$(cast compute-address $user_address --rpc-url $subnet_url)
vrf_consumer_registry_address=$(parseComputedContractAddress "$computed_proxy_contract_address")

# Compute VRFProxy address
computed_proxy_contract_address=$(cast compute-address $user_address --nonce ((++subnet_nonce)) --rpc-url $subnet_url)
vrf_proxy_address=$(parseComputedContractAddress "$computed_proxy_contract_address")

cd $REPO_BASE_PATH/contracts

# Deploy the VRFProxyRegistry contract to the C-Chain.
echo "Deploying VRFProxyRegistry to C-Chain..."
forge create --private-key $user_private_key \
    src/VRFProxyRegistry.sol:VRFProxyRegistry \
    --constructor-args $c_chain_proxy_registry_admin $c_chain_proxy_registry_managers \
    --rpc-url $c_chain_url > /dev/null
echo "Deployed VRFProxyRegistry to C-Chain: $vrf_proxy_registry_address."

# Deploy the VRFProvider contract to the C-Chain.
echo "Deploying VRFProvider to C-Chain..."
forge create --private-key $user_private_key \
    src/VRFProvider.sol:VRFProvider \
    --constructor-args $c_chain_teleporter_registry_address $vrf_proxy_registry_address $c_chain_vrf_wrapper_address $c_chain_link_token_address \
    --rpc-url $c_chain_url > /dev/null
echo "Deployed VRFProvider to C-Chain: $vrf_provider_address."

# Deploy the VRFConsumerRegistry contract to the Subnet.
echo "Deploying VRFConsumerRegistry to Subnet..."
forge create --private-key $user_private_key \
    src/VRFConsumerRegistry.sol:VRFConsumerRegistry \
    --constructor-args $c_chain_consumer_registry_admin $c_chain_consumer_registry_managers \
    --rpc-url $subnet_url > /dev/null
echo "Deployed VRFConsumerRegistry to Subnet: $vrf_consumer_registry_address."

# Deploy the VRFProxy contract to the Subnet.
echo "Deploying VRFProxy to Subnet..."
forge create --private-key $user_private_key \
    src/VRFProxy.sol:VRFProxy \
    --constructor-args $subnet_teleporter_registry_address $vrf_consumer_registry_address $c_chain_blockchain_id $vrf_provider_address \
    --rpc-url $subnet_url > /dev/null
echo "Deployed VRFProxy to Subnet: $vrf_proxy_address."

# Deploy the SimpleBettingGame on the Subnet.
#echo "Deploying SimpleBettingGame to Subnet..."
#simple_betting_game_deploy_result=$(forge create --private-key $user_private_key \
#  src/SimpleBettingGame.sol:SimpleBettingGame \
#  --constructor-args $vrf_proxy_address $c_chain_vrf_subscription_id $c_chain_vrf_key_hash \
#  --rpc-url $subnet_url)
#simple_betting_game_address=$(parseContractAddress "$simple_betting_game_deploy_result")
#echo "Deployed SimpleBettingGame to Subnet."
