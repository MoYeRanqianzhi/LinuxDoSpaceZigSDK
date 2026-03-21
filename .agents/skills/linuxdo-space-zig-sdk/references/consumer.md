# Consumer Guide

## Integrate

Current repository state documents source-module integration, not a package
registry install flow.

- module name: `linuxdospace`
- root source: `src/lib.zig`
- build registration: `build.zig`

Typical local integration is to vendor the source or add the repository as a
dependency, then import the module:

```zig
const lds = @import("linuxdospace");
```

If the target program uses the built-in upstream transport, the target machine
must provide `curl`.

## Consumer Mental Model

- `try lds.Client.init(...)` constructs the client and validates `token` and
  `base_url`.
- `try client.start()` opens the built-in upstream HTTPS stream through system
  `curl` and feeds the full queue.
- `client.listenNext()` drains the full-stream queue one item at a time.
- `try client.bind(...)` registers local exact or pattern mailbox bindings.
- A mailbox starts receiving only after `try mailbox.listenStart()`.
- `mailbox.listenNext()` drains the mailbox queue one item at a time.
- `Suffix.linuxdo_space` resolves to `<owner_username>.linuxdo.space` after the
  `ready` event.
- Exact and pattern bindings share one ordered chain per suffix.
- `allow_overlap=false` stops at the first local match; `true` continues.
- Pattern matching is currently lightweight and regex-like, not a general regex
  engine.

## Preferred Usage Patterns

### Create A Client

```zig
const std = @import("std");
const lds = @import("linuxdospace");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();

var client = try lds.Client.init(
    arena.allocator(),
    "lds_pat_example",
    "https://api.linuxdo.space",
);
defer client.deinit();
```

### Register An Exact Mailbox

```zig
var mailbox = try client.bind("alice", null, lds.Suffix.linuxdo_space, false);
try mailbox.listenStart();
defer mailbox.close();
```

### Register A Pattern Mailbox

```zig
var mailbox = try client.bind(null, ".*", lds.Suffix.linuxdo_space, true);
try mailbox.listenStart();
defer mailbox.close();
```

### Route A Full-Queue Message Locally

```zig
var matches = std.ArrayList(*lds.MailBox).init(arena.allocator());
defer matches.deinit();

if (client.listenNext()) |message| {
    try client.route(message, &matches);
}
```

### Custom Transport Or Tests

If the caller already has NDJSON lines, bypass the built-in `curl` transport and
feed them directly:

```zig
try client.ingestNdjsonLine(line);
```

## Consumer Do / Do Not

Do:

- keep one long-lived `Client` when possible
- use `client.bind(...)` with either `prefix` or `pattern`, never both
- call `listenStart()` before expecting mailbox delivery
- use `ingestNdjsonLine(...)` when testing or integrating custom transport

Do not:

- document `Client.init(...)` as connecting immediately
- assume mailbox queues buffer mail before `listenStart()`
- assume pattern matching is a full regex engine
- depend on non-local `http://` base URLs
