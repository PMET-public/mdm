#!/bin/bash

set +x

output=$(./bin/launcher)
./bin/launcher "$output"
