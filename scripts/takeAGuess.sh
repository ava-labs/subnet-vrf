#!/usr/bin/env bash

set -e

REPO_BASE_PATH=$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  cd .. && pwd
)

source $REPO_BASE_PATH/.env
source $REPO_BASE_PATH/deployment

# Take a guess of a random number to test VRF functionality
echo "Calling VRFConsumer to take a guess of a random number..."
cast send $subnet_consumer\
  "takeAGuess(uint256)" "777" \
  --private-key $user_private_key --rpc-url $subnet_url
echo "Done✨"
