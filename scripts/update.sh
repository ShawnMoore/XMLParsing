#!/usr/bin/env bash

rm -rf .build
vapor clean -y --verbose
vapor xcode -n --verbose
