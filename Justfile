set shell := ["bash", "-uc"]

# Setup local development environment
setup:
  #!/bin/bash
  if [[ "$(cargo 2>&1)" == *"rustup could not choose a version of cargo to run"* ]]; then
    rustup default 1.78.0
  fi

build: setup
  cargo build --release

test: setup
  cargo test

lint: setup
  cargo clippy --workspace
  cargo fmt

bind: setup
  just bind-kotlin
  just bind-swift

bind-kotlin: setup
  cargo build --release --package web5-uniffi
  cargo run --package web5-uniffi \
    --bin uniffi-bindgen \
    generate --library target/release/libweb5.dylib \
    --language kotlin \
    --out-dir target/bindgen-kotlin
  cp target/release/libweb5.dylib binded/kt/src/main/resources/natives
  cp target/bindgen-kotlin/web5/sdk/web5.kt binded/kt/src/main/kotlin/web5/sdk
  cd binded/kt && ./fix-load.sh

bind-swift: setup
  cargo build --release --package web5-uniffi
  cargo run --package web5-uniffi \
    --bin uniffi-bindgen \
    generate --library target/release/libweb5.dylib \
    --language swift \
    --out-dir target/bindgen-swift
  mkdir -p target/xcframework-staging
  mv target/bindgen-swift/web5.swift binded/swift/Sources/UniFFI
  mv target/bindgen-swift/web5FFI.modulemap target/xcframework-staging/module.modulemap
  mv target/bindgen-swift/web5FFI.h target/xcframework-staging/
  rm -rf binded/swift/libweb5-rs.xcframework
  xcodebuild -create-xcframework \
    -library target/release/libweb5.dylib \
    -headers target/xcframework-staging \
    -output binded/swift/libweb5-rs.xcframework

test-binded: setup
  just test-kotlin
  just test-swift

test-kotlin: setup
  cd binded/kt && mvn clean test

test-swift: setup
  cd binded/swift && \
    swift package clean && \
    swift test