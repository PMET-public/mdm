#!/bin/bash

msg_w_newlines "Installing platypus ..."

brew install platypus

./bin/dockerize -s

exit 0