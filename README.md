# [WireGuard](https://www.wireguard.com/) for iOS and macOS

This project contains an application for iOS and for macOS, as well as many components shared between the two of them. You may toggle between the two platforms by selecting the target from within Xcode.

## Building

- Clone this repo:

```
$ git clone https://git.zx2c4.com/wireguard-apple
$ cd wireguard-apple
```

- Rename and populate developer team ID file:

```
$ cp Sources/WireGuardApp/Config/Developer.xcconfig.template Sources/WireGuardApp/Config/Developer.xcconfig
$ vim Sources/WireGuardApp/Config/Developer.xcconfig
```

- Install swiftlint and Go 1.23.1 or later:

```
$ brew install swiftlint go
```

- Open project in Xcode:

```
$ open WireGuard.xcodeproj
```

- Flip switches, press buttons, and make whirling noises until Xcode builds it.

## macOS Menu Bar Icon

The menu bar icon turns light purple (`#C4A7E7`) when a connected tunnel routes all IPv4 traffic,
including profiles that exclude the LAN. This uses the same route classification
as the iOS widget. The colored icon uses a non-template image to preserve its
color in the menu bar. Split tunnels keep the standard icon. Disconnected tunnels
and connection transitions keep their original icons and animation.

## iOS Home Screen Widget

The iOS app includes small and medium Home Screen widgets. On iOS 16 and
later it also offers circular, rectangular, and inline Lock Screen widgets.
While a tunnel is active or changing state, the widget leads with the tunnel
name and shows where its traffic goes. The tunnel state (Connected,
Connecting, or Disconnecting) appears as a colored caption above the name.
While connected, the widget shows a live uptime timer that counts from the
last time the shared snapshot changed to Connected.

A connected split tunnel uses a green tint. A connected tunnel that carries all
traffic, with or without the LAN excluded, uses a purple tint so a full tunnel
stands out. Lock Screen widgets are usually monochrome, so they show a
network shield symbol instead of the padlock shield for a full tunnel.
Connecting and Disconnecting stay orange in both cases.

The routing summary comes from the tunnel configuration when the tunnel
starts. It is not a live measurement of where packets exit.

| Shown | Meaning |
| --- | --- |
| All traffic | The peers' `AllowedIPs` cover all of IPv4, for example `0.0.0.0/0` or `0.0.0.0/1` plus `128.0.0.0/1` |
| All traffic, LAN excluded | The peers' `AllowedIPs` cover all public IPv4 ranges, as written by the Exclude private IPs option |
| Split · N routes | Only some destinations use the tunnel. The first IPv4 route is shown with the number of other routes |
| Endpoint | The endpoint host of the peer that carries the default route, or the first peer with an endpoint for split tunnels |
| DNS | The first DNS server from the interface, or System DNS when none is set |
| IPv6 not tunneled | The tunnel routes all IPv4 traffic but not `::/0`, so IPv6 traffic bypasses it |

The endpoint, DNS, and route details are marked privacy sensitive, so iOS
redacts them where it hides widget data on a locked device. If the Network
Extension stops without publishing a final state, the widget keeps the last
published state until the app or extension publishes again.

The app and Network Extension publish a shared status snapshot when the tunnel
state changes. A changed snapshot requests a WidgetKit timeline reload.
WidgetKit controls the reload schedule and may delay, combine, or throttle
requests. State changes are not guaranteed to appear in the widget
immediately.

The iOS app, Network Extension, and Widget Extension must use the same
registered App Group. The default identifier is `group.$(APP_ID_IOS)`. Enable
this App Group for all three App IDs in the Apple Developer portal, then
regenerate the related provisioning profiles. Set `DEVELOPMENT_TEAM` and
`APP_ID_IOS` in `Sources/WireGuardApp/Config/Developer.xcconfig` before
building.

An unsigned simulator build verifies that the Widget Extension compiles and is
embedded in the iOS app. It does not verify App Group access, provisioning, or
WidgetKit reload behavior. Test those requirements with a signed build on a
real device before release.

## WireGuardKit integration

1. Open your Xcode project and add the Swift package with the following URL:
   
   ```
   https://git.zx2c4.com/wireguard-apple
   ```
   
2. `WireGuardKit` links against `wireguard-go-bridge` library, but it cannot build it automatically
   due to Swift package manager limitations. So it needs a little help from a developer. 
   Please follow the instructions below to create a build target(s) for `wireguard-go-bridge`.
   
   - In Xcode, click File -> New -> Target. Switch to "Other" tab and choose "External Build 
     System".
   - Type in `WireGuardGoBridge<PLATFORM>` under the "Product name", replacing the `<PLATFORM>` 
     placeholder with the name of the platform. For example, when targeting macOS use `macOS`, or 
     when targeting iOS use `iOS`.
     Make sure the build tool is set to: `/usr/bin/make` (default).
   - In the appeared "Info" tab of a newly created target, type in the "Directory" path under 
     the "External Build Tool Configuration":
     
     ```
     ${BUILD_DIR%Build/*}SourcePackages/checkouts/wireguard-apple/Sources/WireGuardKitGo
     ```
     
   - Switch to "Build Settings" and find `SDKROOT`.
     Type in `macosx` if you target macOS, or type in `iphoneos` if you target iOS.
   
3. Go to Xcode project settings and locate your network extension target and switch to 
   "Build Phases" tab.
   
   - Locate "Dependencies" section and hit "+" to add `WireGuardGoBridge<PLATFORM>` replacing 
     the `<PLATFORM>` placeholder with the name of platform matching the network extension 
     deployment target (i.e macOS or iOS).
     
   - Locate the "Link with binary libraries" section and hit "+" to add `WireGuardKit`.
   
4. In Xcode project settings, locate your main bundle app and switch to "Build Phases" tab. 
   Locate the "Link with binary libraries" section and hit "+" to add `WireGuardKit`.
   
5. iOS only: Locate Bitcode settings under your application target, Build settings -> Enable Bitcode, 
   change the corresponding value to "No".
   
Note that if you ship your app for both iOS and macOS, make sure to repeat the steps 2-4 twice, 
once per platform.

## MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
