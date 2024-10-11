#!/usr/bin/env bash

# Enable constructor-args
set -e

REPO_BASE_PATH=$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  cd .. && pwd
)

source $REPO_BASE_PATH/.env
source $REPO_BASE_PATH/config

# Retrieve the user address from private key
user_address=$(cast wallet address --private-key $user_private_key)
link_amount="5000000000000000000"
vrf_proxy_allowance="0" # Means the default allowance will be used => 150e18.
# Calculate the next expected contract address for the given deployer on both the C-Chain and Subnet.
# These nonces/addresses will be used to deploy the VRF Provider and Proxy contracts to.

# Retrieve nonces to use for address computation.
c_chain_nonce=$(cast nonce $user_address --rpc-url $c_chain_url);
subnet_nonce=$(cast nonce $user_address --rpc-url $subnet_url);

# Compute VRFProxyRegistry C-Chain address.
computed_proxy_registry_contract_address=$(cast compute-address $user_address --rpc-url $c_chain_url)
vrf_proxy_registry_address=${computed_proxy_registry_contract_address: 18}
#echo "a" $vrf_proxy_registry_address

# Compute VRFProvider C-Chain address.
computed_provider_contract_address=$(cast compute-address $user_address --nonce $((++c_chain_nonce)) --rpc-url $c_chain_url)
vrf_provider_address=${computed_provider_contract_address: 18}
#echo "b" $vrf_provider_address

# Compute VRFConsume Registry Subnet address.
computed_consumer_registry_contract_address=$(cast compute-address $user_address --rpc-url $subnet_url)
vrf_consumer_registry_address=${computed_consumer_registry_contract_address: 18}
#echo "c" $vrf_consumer_registry_address

# Compute VRFProxy address Subnet address.
computed_proxy_contract_address=$(cast compute-address $user_address --nonce $((++subnet_nonce)) --rpc-url $subnet_url)
vrf_proxy_address=${computed_proxy_contract_address: 18}
#echo "d" $vrf_proxy_address

# Compute VRFConsumer (mock) address Subnet address.
computed_consumer_contract_address=$(cast compute-address $user_address --nonce $((2+subnet_nonce)) --rpc-url $subnet_url)
vrf_consumer_mock_address=${computed_consumer_contract_address: 18}
#echo "e" $vrf_consumer_mock_address

# Deploy the VRFProxyRegistry contract to the C-Chain.
echo "Deploying VRFProxyRegistry to C-Chain..."
forge create --private-key $user_private_key \
    src/VRFProxyRegistry.sol:VRFProxyRegistry \
    --constructor-args $c_chain_proxy_registry_admin [$c_chain_proxy_registry_managers] \
    --rpc-url $c_chain_url > /dev/null
echo "Deployed VRFProxyRegistry to C-Chain: $vrf_proxy_registry_address."

# Deploy the VRFProvider contract to the C-Chain.
echo "Deploying VRFProvider to C-Chain..."
forge create --private-key $user_private_key \
    src/VRFProvider.sol:VRFProvider \
    --constructor-args $c_chain_teleporter_registry_address $vrf_proxy_registry_address $c_chain_vrf_v2_plus_wrapper_address \
    --rpc-url $c_chain_url > /dev/null
echo "Deployed VRFProvider to C-Chain: $vrf_provider_address."

# Deploy the VRFConsumerRegistry contract to the Subnet.
echo "Deploying VRFConsumerRegistry to Subnet..."
forge create --private-key $user_private_key \
    src/VRFConsumerRegistry.sol:VRFConsumerRegistry \
    --constructor-args $subnet_consumer_registry_admin [$subnet_consumer_registry_managers] \
    --rpc-url $subnet_url > /dev/null
echo "Deployed VRFConsumerRegistry to Subnet: $vrf_consumer_registry_address."

# Deploy the VRFProxy contract to the Subnet.
echo "Deploying VRFProxy to Subnet..."
forge create --private-key $user_private_key \
    src/VRFProxy.sol:VRFProxy \
    --constructor-args $subnet_teleporter_registry_address $vrf_consumer_registry_address $c_chain_blockchain_id $vrf_provider_address \
    --rpc-url $subnet_url > /dev/null
echo "Deployed VRFProxy to Subnet: $vrf_proxy_address."

# Deploy the VRFConsumer (mock) on the Subnet.
echo "Deploying VRFConsumer to Subnet..."
forge create --private-key $user_private_key \
  src/mocks/VRFConsumer.sol:VRFConsumer \
  --constructor-args $vrf_proxy_address \
  --rpc-url $subnet_url > /dev/null
echo "Deployed VRFConsumer to Subnet: $vrf_consumer_mock_address."

# Approve the deployed VRFProxy for Subnet Id on VRFProxyRegistry
echo "Approving VRFProxy on VRFProxyRegistry..."
cast send $vrf_proxy_registry_address \
  "addProxies(bytes32,address[],uint256[])" \
  $subnet_blockchain_id "[$vrf_proxy_address]" "[$vrf_proxy_allowance]" \
  --private-key $user_private_key --rpc-url $c_chain_url \
  > /dev/null
echo "VRFProxy Approved."

# Approve the deployed VRFConsumer on VRFConsumerRegistry
echo "Approving VRFConsumer on VRFConsumerRegistry..."
cast send $vrf_consumer_registry_address \
  "addConsumers(address[])" "[$vrf_consumer_mock_address]" \
  --private-key $user_private_key --rpc-url $subnet_url \
  > /dev/null
echo "VRFConsumer Approved."

# Approve $LINK to the VRFProvider
echo "Approving \$LINK to the VRFProvider..."
cast send $c_chain_link_token_address \
  "approve(address,uint256)" $vrf_provider_address $link_amount \
  --private-key $user_private_key --rpc-url $c_chain_url \
  > /dev/null
echo "\$LINK Approved."

# Deposit $Link to the VRFProvider
echo "Depositing \$LINK to the VRFProvider..."
cast send $vrf_provider_address \
  "deposit(uint256)" $link_amount \
  --private-key $user_private_key --rpc-url $c_chain_url \
  > /dev/null
echo "\$LINK Deposited."
