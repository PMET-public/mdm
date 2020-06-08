#!/bin/bash

msg "Installing platypus"

brew install platypus

./bin/dockerize -s

exit 0