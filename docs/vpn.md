# Built-in VPN

Asked for as OpenVPN. Researched, and the recommendation is **WireGuard
instead** — for a reason that has nothing to do with taste.

## OpenVPN would reinstate the licence conflict we just removed

The Kotlin app was deleted partly to retire a GPL-3.0 obligation that had no
route to the App Store. Embedding OpenVPN puts one straight back:

| | Licence | Consequence |
|---|---|---|
| `openvpn3` (the official core library) | **AGPL-3.0** | Stricter than GPL-3.0. Categorically incompatible with the App Store, and its network clause is a poor fit for a client application. |
| `ics-openvpn` (what every Android OpenVPN app is built on) | **GPL-2.0** | Copyleft again. Android-only; nothing equivalent exists for tvOS. |

There is no permissively licensed OpenVPN implementation worth shipping. So
"add OpenVPN" and "keep the App Store route we just opened" cannot both be
true.

## WireGuard does the same job and is licensed to be used

- **MIT**, both `wireguard-go` and `wireguard-apple`. No copyleft, no App
  Store conflict.
- **Already shipping on Apple TV.** Tailscale and Mullvad both use it on
  tvOS, which is the strongest evidence available that the route works.
- **Far smaller.** WireGuard is a few thousand lines against OpenVPN's
  hundreds of thousands, which matters when it has to be cross-compiled for
  four architectures.
- **Faster to connect and faster in throughput**, which for 4K video is the
  whole point.

The one real cost: WireGuard is not OpenVPN, so a provider offering only
`.ovpn` configuration files cannot be used. Most commercial VPNs now publish
WireGuard configurations; some do not.

## What it takes on each platform

**Android** is the straightforward one. `VpnService` needs no special
approval, only the user accepting a system consent dialog the first time.

**Apple TV** is possible and was not always: `NEPacketTunnelProvider` arrived
in **tvOS 17**, and Apple opened third-party VPN apps at the same time. It
needs three things:

1. A separate packet-tunnel extension target alongside the app.
2. The `com.apple.developer.networking.networkextension` entitlement, which
   **Apple grants by request, not automatically**. This is the item with a
   lead time and the one that can be refused.
3. The tunnel implementation cross-compiled for tvOS.

## Honest scope

This is not a small feature. A working, trustworthy tunnel on both platforms
is on the order of weeks, most of it native rather than Flutter, and the tvOS
half is gated on an approval outside anyone's control here.

It should also be said plainly: a VPN inside a media player is a smaller
guarantee than it sounds. It routes this app's traffic; it does nothing about
DNS handled elsewhere on the device, nothing about what a provider logs at
their end, and nothing about the credentials that travel in the clear because
IPTV portals do not offer usable TLS. It is worth building. It is not
anonymity by itself, and the interface should not imply that it is.

## Recommendation

1. **WireGuard, not OpenVPN**, on licence grounds above all.
2. **Request the Apple entitlement early**, because it has a lead time and
   because a refusal changes the plan rather than delaying it.
3. **Build Android first**, where nothing is gated, and treat it as the proof
   the plumbing is right before committing to the Apple half.
4. **Say what it does and does not cover** in the interface, rather than
   letting a padlock imply more than it delivers.

Nothing here is built yet. This document exists so the decision is made on
what is actually true rather than on the assumption that OpenVPN is the
default choice.

## Sources

- [NEPacketTunnelProvider is only available in tvOS 17.0 or newer](https://developer.apple.com/forums/thread/731537)
- [VPN providers react to Apple TV third-party app support](https://www.techradar.com/news/vpn-providers-react-to-apple-tv-third-party-app-support)
- [Tailscale: add Apple TV (tvOS) support](https://github.com/tailscale/tailscale/issues/8282)
