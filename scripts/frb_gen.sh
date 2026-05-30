#!/usr/bin/env bash
# Regenerate flutter_rust_bridge Dart bindings + rust/peerbeat_core/src/frb_generated.rs.
# Requires: `cargo install flutter_rust_bridge_codegen --version 2.12.0`
# (must match the `flutter_rust_bridge` crate version in rust/peerbeat_core/Cargo.toml).
#
# Config lives in apps/peerbeat/flutter_rust_bridge.yaml; codegen runs from there.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  echo "flutter_rust_bridge_codegen not found." >&2
  echo "Install with: cargo install flutter_rust_bridge_codegen --version 2.12.0" >&2
  exit 1
fi

echo "==> Generating flutter_rust_bridge bindings…"
( cd apps/peerbeat && flutter_rust_bridge_codegen generate )
echo "==> Formatting generated Rust…"
( cd rust/peerbeat_core && cargo fmt --all )
echo "Done. Review & commit apps/peerbeat/lib/src/rust and rust/peerbeat_core/src/frb_generated.rs"
