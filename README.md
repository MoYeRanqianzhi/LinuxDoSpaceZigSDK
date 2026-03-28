# LinuxDoSpace Zig SDK

This directory contains a Zig SDK implementation for LinuxDoSpace mail stream protocol.

## Scope

- `Client`, `Suffix`, `MailMessage`
- Errors: authentication/stream failures
- Full listener queue API
- Local bind (exact/pattern), ordered chain, overlap control
- `route`, `close`

Important:

- `Suffix.linuxdo_space` is semantic, not literal
- `Suffix.linuxdo_space` now resolves to the current token owner's canonical
  mail namespace: `<owner_username>-mail.linuxdo.space`
- the legacy default alias `<owner_username>.linuxdo.space` still matches the
  default semantic binding automatically
- consumer code should keep using `Suffix.linuxdo_space` instead of hardcoding
  a concrete `*-mail.linuxdo.space` namespace

## Transport Note

- The current `start()` implementation uses the system `curl` binary to read the HTTPS NDJSON stream.
- This makes the Zig SDK operational without depending on unstable `std.http` APIs, but it also means `curl` must exist on the target machine.
- Pattern matching is currently a lightweight matcher, not a full general-purpose regex engine.

## Local Verification Status

Current environment does not have Zig toolchain installed, so this SDK was not compiled locally in this session.

## Build (when Zig is available)

```bash
zig build
```
