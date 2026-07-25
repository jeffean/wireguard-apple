#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
SNAPSHOT_TEST_BINARY="${TMPDIR:-/tmp}/TunnelWidgetSnapshotTests.$$"
RESOLVER_TEST_BINARY="${TMPDIR:-/tmp}/TunnelWidgetStatusResolverTests.$$"
MIGRATION_TEST_BINARY="${TMPDIR:-/tmp}/TunnelConfigurationMigrationTests.$$"

trap 'rm -f "$SNAPSHOT_TEST_BINARY" "$RESOLVER_TEST_BINARY" "$MIGRATION_TEST_BINARY"' EXIT

swiftc \
    -swift-version 5 \
    "$REPOSITORY_ROOT/Sources/Shared/Widget/TunnelWidgetSnapshot.swift" \
    "$REPOSITORY_ROOT/Sources/Shared/Widget/TunnelWidgetSnapshotStore.swift" \
    "$SCRIPT_DIR/TunnelWidgetSnapshotTests.swift" \
    -o "$SNAPSHOT_TEST_BINARY"

"$SNAPSHOT_TEST_BINARY"

swiftc \
    -swift-version 5 \
    "$REPOSITORY_ROOT/Sources/Shared/Widget/TunnelWidgetSnapshot.swift" \
    "$REPOSITORY_ROOT/Sources/Shared/Widget/TunnelWidgetStatusPublisher.swift" \
    "$SCRIPT_DIR/TunnelWidgetStatusResolverTests.swift" \
    -o "$RESOLVER_TEST_BINARY"

"$RESOLVER_TEST_BINARY"

swiftc \
    -swift-version 5 \
    "$REPOSITORY_ROOT/Sources/Shared/Model/TunnelConfigurationMigration.swift" \
    "$SCRIPT_DIR/TunnelConfigurationMigrationTests.swift" \
    -o "$MIGRATION_TEST_BINARY"

"$MIGRATION_TEST_BINARY"
