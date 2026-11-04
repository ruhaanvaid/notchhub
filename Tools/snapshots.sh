#!/bin/sh
# Renders NotchHub views to PNGs for design review: Tools/snapshots.sh [output-dir]
set -e
cd "$(dirname "$0")/.."
OUT="${1:-build/snapshots}"
SRCS=$(find NotchHub -name '*.swift' ! -name 'NotchHubMain.swift')
mkdir -p build
xcrun swiftc -swift-version 5 -parse-as-library -D DEBUG -target arm64-apple-macos14.0 \
  -sdk "$(xcrun --show-sdk-path --sdk macosx)" -o build/snapshots-bin $SRCS Tools/Snapshots/main.swift
build/snapshots-bin "$OUT"
