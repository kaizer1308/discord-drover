# Discord Drover for iOS

Discord Drover is a standalone iOS 17+ app for using the official Discord app over your own IKEv2 VPN. It is intended for networks such as those in the UAE where Discord text may work while voice does not. Unlike the Windows version, it does not modify individual Discord packets or use an HTTP/SOCKS proxy. No modified Discord IPA is needed.

## Install on an iPhone or iPad

1. Open `DroverIOS.xcodeproj` in Xcode on a Mac. In the **DroverIOS** target’s **Signing & Capabilities**, select a development team and replace `com.example.discord-drover-ios` with a unique bundle identifier.
2. Ensure the App ID and provisioning profile include the **Personal VPN** entitlement (`com.apple.developer.networking.vpn.api` with `allow-vpn`) and allow the app's `keychain-access-groups` entry. Xcode expands `$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)` when signing. If re-signing an unsigned IPA manually, use the profile's actual App ID prefix (including its trailing period) and the final bundle ID, not the literal build-setting variables. Build and run on a physical device.
3. Enter the IKEv2 **server address** and the **remote ID** given by your VPN provider. For username/password (EAP) authentication, use a server with a trusted certificate matching the remote ID. If the server is set up for IKEv2 pre-shared-key authentication, select **Pre-shared key** instead. There is no built-in server or account.
4. Tap **Connect**, approve the iOS VPN configuration prompt, and wait for **Connected**, then open Discord and join a voice channel. The app stores the credential in the device Keychain; leave the credential field blank to keep the saved value when reusing the same authentication method. Tap **Disconnect** when finished; this also turns off on-demand connection.

## Discord voice and routing

- Use an IKEv2 server reachable from your network (typically over UDP ports 500 and 4500) with working DNS, internet egress and UDP forwarding. A full-tunnel profile covering both IPv4 and IPv6 avoids relying on a fixed list of Discord voice server IPs. With split routing, your routes must cover the actual voice endpoints as well as Discord’s web/API traffic. A VPN status of **Connected** does not guarantee that media reaches Discord.
- Optional **Connect on demand for Discord domains** saves a hostname-based activation rule. It is not a per-app traffic filter, and it may not activate if Discord’s hostnames still resolve and only the voice UDP path is blocked. For voice, use **Connect** before opening Discord or joining a call.
- On unmanaged iOS, Personal VPN cannot route only the Discord app. Which packets use the tunnel depends on its routes; a full tunnel also carries other apps’ traffic. Per-app VPN for managed apps requires device management and is not part of this app.
- To verify on a physical device in the UAE, connect over the network you intend to use, then join a voice channel and confirm another person can hear you and you can hear them. Leave and rejoin after switching between Wi-Fi and cellular if both matter to you. Availability depends on your server and network; the simulator tests do not verify live VPN connectivity or Discord voice.

## Build and test on a simulator

From the repository root:

```sh
xcodebuild -project ios/DroverIOS.xcodeproj -scheme DroverIOS \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/DroverIOS.xcodeproj -scheme DroverIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO test
```

Substitute an installed simulator from `xcrun simctl list devices available` if needed. Tests exercise protocol and on-demand rule construction; they do not install a VPN profile.
