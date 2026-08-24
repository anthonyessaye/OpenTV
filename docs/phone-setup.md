# Setting up from a phone

Typing a portal address, a username and a password on a television remote is
the worst part of this app. A WireGuard configuration — several lines of
base64 — is barely possible at all. So the television can serve a form on the
local network for as long as somebody is standing in front of it setting
things up.

## What this exposes

The form carries a provider password and possibly a tunnel's private key,
over plain HTTP, on whatever network the television is joined to. That is a
real exposure. The interface says so on screen, in those words, before anyone
types anything.

**TLS is not the answer here.** A certificate nothing can verify produces a
browser warning, and the habit it teaches — clicking through security
warnings to reach your own devices — is worse than the problem it solves. It
also authenticates nobody: an attacker on the network can present their own
self-signed certificate just as easily.

What does work on a local network is keeping the window short and requiring
proof that whoever is filling in the form can see the television.

## The defences, and what each is for

| Defence | What it stops |
| --- | --- |
| Runs only while setup is open | A server nobody remembers, still listening months later |
| Six-digit code, shown on the television | Being on the network is not enough; you have to be in the room |
| Code from `Random.secure()` | A predictable code is the same as no code |
| Five wrong attempts closes the window | An evening of guessing at a six-digit number |
| A session token, not the code, authorises afterwards | Replay from a browser history or over a shoulder |
| Constant-time comparison | Guessing the token one character at a time by timing |
| Secrets in POST bodies only | Proxy logs, browser history, server logs — everything that writes URLs down |
| `Host` header checked | A page on the internet pointing your browser here and reading the replies |
| Nothing stored is rendered back | The next person to pick up that phone |
| Bound to one private interface | Ever being reachable from outside the house |
| Bodies capped at 256 KB | Exhausting a television's memory with one request |
| Code and token cleared on stop | A restarted window accepting yesterday's credentials |
| Content-Security-Policy forbidding all fetches | Anything injected into the page loading anything |

The submission type overrides `toString` to redact itself, because these
values end up in crash reports.

## What it does not do

- **No discovery.** No Bonjour, no UPnP, no broadcast. The address is read off
  the television and typed in. Advertising a service that accepts a password
  is not something to do for convenience.
- **No port forwarding**, ever.
- **Not available outside setup.** There is no toggle in settings that leaves
  it running. It is started from the onboarding screen, and stops on success,
  on cancel, when the screen is left, or after fifteen minutes.

## Tests

`packages/opentv_core/test/setup/setup_server_test.dart` tests the refusals
rather than the happy path — an unpaired browser getting the code page rather
than the form, the code alone being insufficient to submit, the lockout, the
host check, and that a submitted password is never rendered back into any
reply.
