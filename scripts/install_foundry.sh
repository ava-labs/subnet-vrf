#!/usr/bin/env bash

# Copyright (C) 2024, Ava Labs, Inc. All rights reserved.
# See the file LICENSE for licensing terms.

set -e

# The foundry install script uses XDG_CONFIG_HOME as the root of the install.
# This can vary for different environments, so it is set to $HOME for consistency.
export XDG_CONFIG_HOME=$HOME

# This installs from ava-labs fork of the foundry repo.
curl -L https://foundry.paradigm.xyz | bash

export PATH=$PATH:$HOME/.foundry/bin:$HOME/.foundry:$HOME/.cargo/bin
foundryup --version nightly
