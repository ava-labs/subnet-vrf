#!/usr/bin/env bash

set -e

REPO_BASE_PATH=$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  cd .. && pwd
)

source $REPO_BASE_PATH/deployment
source $REPO_BASE_PATH/config

requestId=1;

# Retrieve the response status - check if request for random words has been addressed
echo "Calling VRFConsumer to retrieve response status..."
response=$(cast call $subnet_consumer\
  "guesses(uint256)" $requestId \
  --rpc-url $subnet_url)

isAddressed=false

if [[ ${response:193} -eq 1 ]]; then isAddressed=true; fi

echo "Is response addressed: $isAddressed"
