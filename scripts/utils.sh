#!/usr/bin/env bash

function parseContractAddress() {
    echo $1 | ggrep -o -P 'Deployed to: .{42}' | sed 's/^.\{13\}//';
}

function parseComputedContractAddress() {
    echo $1 | ggrep -o -P 'Computed Address: .{42}' | sed 's/^.\{18\}//';
}
