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
- the SDK resolves it to `<owner_username>.linuxdo.space` after `ready.owner_username`

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
