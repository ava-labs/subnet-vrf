#!/usr/bin/env bash

set -e

REPO_BASE_PATH=$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  cd .. && pwd
)

source $REPO_BASE_PATH/.env
source $REPO_BASE_PATH/config
source $REPO_BASE_PATH/deployment

new_owner=""#insert address here

# Transfer ownership
echo "Performing ownership transfer to $new_owner"
cast send $c_chain_provider\
  "transferOwnership(address)" $new_owner \
  --private-key $user_private_key --rpc-url $c_chain_url
echo "Done✨"
