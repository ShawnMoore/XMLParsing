#!/usr/bin/env bash

rm -rf .build
vapor clean -y --verbose
rm Package.resolved
vapor xcode -n --verbose
