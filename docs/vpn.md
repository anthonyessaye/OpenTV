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

## What is built

**The configuration parser**, in `packages/opentv_core/lib/src/vpn/`, with 16
tests. Both platforms need it and neither should own it: Android's
`VpnService` and tvOS's `NEPacketTunnelProvider` want the same handful of
facts in different shapes, so the `.conf` a provider hands out is read once,
where it can be tested without a device, a network or an entitlement.

It refuses what cannot work, with sentences a viewer can act on, because the
realistic failure is a half-pasted file rather than a malformed byte. The
check that matters most is key length: a truncated key builds a tunnel that
connects and passes no traffic, which is the least diagnosable failure in the
whole feature. It also reports whether a tunnel is full or split, because that
decides what the interface may honestly claim — calling a split tunnel
"protected" would be a lie in one of the two cases.

**Deliberately not built: any interface for it.** There is no VPN toggle, no
status indicator and no padlock anywhere in the app, and there will not be one
until a tunnel actually exists. A control that implies protection it cannot
deliver is worse than the feature being absent — someone would trust it.

## What remains

1. The Android tunnel: `VpnService` plus a WireGuard implementation
   cross-compiled for four ABIs. No approval needed; this is where the
   plumbing should be proven.
2. The Apple entitlement request. It has a lead time and can be refused, so
   it should be sent before the work it gates, not after.
3. The tvOS packet-tunnel extension target.
4. The interface, last — once there is something true to show.

This document exists so the decision is made on what is actually true rather
than on the assumption that OpenVPN is the default choice.

## Sources

- [NEPacketTunnelProvider is only available in tvOS 17.0 or newer](https://developer.apple.com/forums/thread/731537)
- [VPN providers react to Apple TV third-party app support](https://www.techradar.com/news/vpn-providers-react-to-apple-tv-third-party-app-support)
- [Tailscale: add Apple TV (tvOS) support](https://github.com/tailscale/tailscale/issues/8282)
