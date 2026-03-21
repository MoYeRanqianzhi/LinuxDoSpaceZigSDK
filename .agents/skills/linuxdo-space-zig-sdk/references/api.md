# API Reference

## Paths

- SDK root: `../../../`
- Module registration: `../../../build.zig`
- Core implementation: `../../../src/lib.zig`
- Consumer README: `../../../README.md`

## Public Surface

- exported constants and types:
  - `Suffix`
  - `LinuxDoSpaceError`
  - `MailMessage`
  - `MailBox`
  - `Client`
- `Client`:
  - `init(allocator, token, base_url) !Client`
  - `deinit()`
  - `bind(prefix, pattern, suffix, allow_overlap) !*MailBox`
  - `route(message, out) !void`
  - `listenNext() ?MailMessage`
  - `close()`
  - `ingestNdjsonLine(line) !void`
  - `start() !void`
- `MailBox`:
  - `init(...) MailBox`
  - `deinit()`
  - `enqueue(message) !void`
  - `listenStart() !void`
  - `listenNext() ?MailMessage`
  - `close()`

## Semantics

- `Client.init(...)` validates token and base URL, then returns a client value.
- `Client.start()` is the built-in high-level transport loop and currently blocks
  while streaming.
- `Client.listenNext()` drains the full queue and returns `null` when it is
  empty.
- `Client.bind(...)` requires exactly one of `prefix` or `pattern`.
- `MailBox.listenStart()` activates mailbox buffering.
- `MailBox.listenNext()` drains the mailbox queue and returns `null` when it is
  empty.
- `allow_overlap=false` breaks on the first match in the ordered suffix chain.
- `Suffix.linuxdo_space` is semantic and falls back to
  `<owner_username>.linuxdo.space` after the `ready` event is received.
- `regexLikeMatch(...)` currently supports `.*`, exact match, `abc.*`,
  `.*abc`, and `.*abc.*`. It is not a full regex engine.
- Remote `http://` base URLs are rejected unless the host is localhost,
  `127.0.0.1`, `::1`, or `*.localhost`.

## Wire Behavior

- built-in stream endpoint: `{base_url}/v1/token/email/stream`
- required headers:
  - `Authorization: Bearer <token>`
  - `Accept: application/x-ndjson`
- handled event types:
  - `ready`
  - `heartbeat`
  - `mail`

## Lifecycle Notes

- `close()` sets `closed = true`; it does not remove bindings from the chain.
- `deinit()` is required to release owned allocations.
- `MailBox.listenStart()` only permits one active listener and returns
  `MailboxAlreadyListening` when called twice.
