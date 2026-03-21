# Examples

## Task: Write consumer code that listens for all mail under the semantic owner suffix

Start with `references/consumer.md`, then use:

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

var catch_all = try client.bind(null, ".*", lds.Suffix.linuxdo_space, true);
try catch_all.listenStart();
defer catch_all.close();
```

## Task: Route a full-stream event into local mailboxes

```zig
var matches = std.ArrayList(*lds.MailBox).init(arena.allocator());
defer matches.deinit();

if (client.listenNext()) |message| {
    try client.route(message, &matches);
    for (matches.items) |mailbox| {
        _ = mailbox;
    }
}
```

## Task: Feed test fixtures without opening the built-in upstream transport

```zig
try client.ingestNdjsonLine(ready_line);
try client.ingestNdjsonLine(mail_line);

if (catch_all.listenNext()) |message| {
    std.debug.print("{s}\n", .{message.address});
}
```

## Task: Explain current limitations accurately

State these points explicitly:

- `Client.start()` is the built-in blocking transport loop
- `curl` is a runtime dependency for that path
- pattern matching is regex-like rather than full regex
- mailbox queues activate only after `listenStart()`
