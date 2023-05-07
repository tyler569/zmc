#!/usr/bin/env bash

set -euo pipefail

if [[ ! -e wgpu-native ]]; then
    git clone https://github.com/gfx-rs/wgpu-native.git wgpu-native
fi

cd wgpu-native

git pull
git submodule update --init
make lib-native

