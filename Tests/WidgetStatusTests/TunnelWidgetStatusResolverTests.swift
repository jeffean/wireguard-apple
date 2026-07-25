// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import Foundation

@main
private enum TunnelWidgetStatusResolverTests {
    static func main() {
        assertResolution(
            [],
            equals: TunnelWidgetResolvedStatus(status: .disconnected, tunnelName: nil)
        )
        assertResolution(
            [TunnelWidgetStatusCandidate(state: .inactive, tunnelName: "Home")],
            equals: TunnelWidgetResolvedStatus(status: .disconnected, tunnelName: nil)
        )
        assertResolution(
            [TunnelWidgetStatusCandidate(state: .active, tunnelName: "Home")],
            equals: TunnelWidgetResolvedStatus(status: .connected, tunnelName: "Home")
        )

        for state in [
            TunnelWidgetStatusCandidate.State.activating,
            .reasserting,
            .restarting
        ] {
            assertResolution(
                [TunnelWidgetStatusCandidate(state: state, tunnelName: "Home")],
                equals: TunnelWidgetResolvedStatus(status: .connecting, tunnelName: "Home")
            )
        }

        assertResolution(
            [TunnelWidgetStatusCandidate(state: .deactivating, tunnelName: "Home")],
            equals: TunnelWidgetResolvedStatus(status: .disconnecting, tunnelName: "Home")
        )
        assertResolution(
            [TunnelWidgetStatusCandidate(state: .waiting, tunnelName: "Office")],
            equals: TunnelWidgetResolvedStatus(status: .connecting, tunnelName: "Office")
        )
        assertResolution(
            [
                TunnelWidgetStatusCandidate(state: .waiting, tunnelName: "Office"),
                TunnelWidgetStatusCandidate(state: .active, tunnelName: "Home")
            ],
            equals: TunnelWidgetResolvedStatus(status: .connected, tunnelName: "Home")
        )
        assertResolution(
            [
                TunnelWidgetStatusCandidate(state: .waiting, tunnelName: "Office"),
                TunnelWidgetStatusCandidate(state: .deactivating, tunnelName: "Home")
            ],
            equals: TunnelWidgetResolvedStatus(status: .disconnecting, tunnelName: "Home")
        )

        print("PASS: TunnelWidgetStatusResolverTests")
    }

    private static func assertResolution(
        _ candidates: [TunnelWidgetStatusCandidate],
        equals expected: TunnelWidgetResolvedStatus
    ) {
        let actual = TunnelWidgetStatusResolver.resolve(candidates)
        precondition(actual == expected, "Expected \(expected), got \(actual)")
    }
}
