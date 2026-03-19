# LinuxDoSpace Zig SDK

This directory contains a Zig SDK implementation for LinuxDoSpace mail stream protocol.

## Scope

- `Client`, `Suffix`, `MailMessage`
- Errors: authentication/stream failures
- Full listener queue API
- Local bind (exact/regex), ordered chain, overlap control
- `route`, `close`

## Local Verification Status

Current environment does not have Zig toolchain installed, so this SDK was not compiled locally in this session.

## Build (when Zig is available)

```bash
zig build
```
