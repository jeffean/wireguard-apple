#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .agent/runtime/macos-icon
swiftc Sources/Shared/Widget/TunnelWidgetSnapshot.swift \
    Sources/WireGuardApp/UI/macOS/StatusItemController.swift \
    Tests/MacOSStatusItemTests/main.swift \
    -o .agent/runtime/macos-icon/pixel-probe
.agent/runtime/macos-icon/pixel-probe
