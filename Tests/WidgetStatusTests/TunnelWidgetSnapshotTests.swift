import Foundation

@main
private enum TunnelWidgetSnapshotTests {
  static func main() {
    let suiteName = "TunnelWidgetSnapshotTests.\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
      fputs("FAIL: Could not create isolated UserDefaults suite\n", stderr)
      exit(1)
    }
    defer {
      userDefaults.removePersistentDomain(forName: suiteName)
    }

    let store = TunnelWidgetSnapshotStore(userDefaults: userDefaults)
    let firstDate = Date(timeIntervalSince1970: 1_721_868_800)
    let secondDate = Date(timeIntervalSince1970: 1_721_868_860)

    expect(store.load().status == .disconnected, "Missing data falls back to disconnected")
    expect(
      store.saveIfChanged(status: .connected, tunnelName: "Home", now: firstDate),
      "First value is saved")
    expect(
      !store.saveIfChanged(status: .connected, tunnelName: "Home", now: secondDate),
      "Equivalent content is not rewritten")
    expect(store.load().tunnelName == "Home", "Saved snapshot round trips")
    expect(
      store.load().updatedAt == firstDate, "Equivalent content preserves the original timestamp")

    userDefaults.set(Data("not-json".utf8), forKey: TunnelWidgetSnapshotStore.storageKey)
    expect(store.load().status == .disconnected, "Invalid data falls back to disconnected")

    print("PASS: TunnelWidgetSnapshotTests")
  }

  private static func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    guard condition() else {
      fputs("FAIL: \(message) (\(file):\(line))\n", stderr)
      exit(1)
    }
  }
}
