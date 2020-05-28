#!/bin/bash

set +x

output=$(./bin/launcher)
echo "Output from launcher: $output"
./bin/launcher "$output"
env