#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TEST_BINARY="${TMPDIR:-/tmp}/TunnelWidgetSnapshotTests.$$"

trap 'rm -f "$TEST_BINARY"' EXIT

swiftc \
    -swift-version 5 \
    "$REPOSITORY_ROOT/Sources/Shared/Widget/TunnelWidgetSnapshot.swift" \
    "$REPOSITORY_ROOT/Sources/Shared/Widget/TunnelWidgetSnapshotStore.swift" \
    "$SCRIPT_DIR/TunnelWidgetSnapshotTests.swift" \
    -o "$TEST_BINARY"

"$TEST_BINARY"
