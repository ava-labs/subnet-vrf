#!/usr/bin/env bash

# Copyright (C) 2024, Ava Labs, Inc. All rights reserved.
# See the file LICENSE for licensing terms.

set -e

REPO_BASE_PATH=$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  cd .. && pwd
)

source $REPO_BASE_PATH/.env
source $REPO_BASE_PATH/config
source $REPO_BASE_PATH/deployment

new_authority=""; #insert address here
#consumer_manager_role="0x795edd50d89cf0f09d5fb90f6c834853abd2897512ea74c56cf89c0a94b5da8b" #keccak256("CONSUMER_MANAGER")
role="0x0000000000000000000000000000000000000000000000000000000000000000" #admin role

# Grant role / create a new authority
echo "Grant role $role to $new_authority"
cast send $c_chain_proxy_registry\
  "grantRole(bytes32, address)" $role $new_authority \
  --private-key $user_private_key --rpc-url $c_chain_url
echo "Done✨"
