---
name: linuxdo-space-zig-sdk
description: Use when writing or fixing Zig code that consumes or maintains the LinuxDoSpace Zig SDK under sdk/zig. Use for source-module integration, Client.init/start, full-stream queue handling, mailbox bindings, regex-like pattern matching, allow_overlap semantics, curl-based transport, release guidance, and local validation.
---

# LinuxDoSpace Zig SDK

Read [references/consumer.md](references/consumer.md) first for normal SDK usage.
Read [references/api.md](references/api.md) for exact public Zig API names and current behavior.
Read [references/examples.md](references/examples.md) for task-shaped snippets.
Read [references/development.md](references/development.md) only when editing `sdk/zig`.

## Workflow

1. Treat this SDK as a Zig source module named `linuxdospace`, not as a package-manager install target.
2. The SDK root relative to this `SKILL.md` is `../../../`.
3. Preserve these invariants:
   - one `Client` owns one upstream HTTPS stream
   - `Client.init(...)` only constructs the client; `client.start()` is what opens the built-in transport
   - the built-in transport currently shells out to system `curl` and reads `/v1/token/email/stream` as NDJSON
   - `client.listenNext()` reads the full-intake queue
   - `try client.bind(...)` registers exact or pattern mailbox bindings locally
   - mailbox queues activate only after `mailbox.listenStart()`
   - `prefix` and `pattern` are mutually exclusive
   - exact and pattern bindings share one ordered chain per suffix
   - `allow_overlap=false` stops at the first match; `true` continues
   - `Suffix.linuxdo_space` is semantic and resolves to `<owner_username>.linuxdo.space`
   - current pattern support is regex-like fallback matching, not a full regex engine
   - remote `base_url` must use `https://`; only localhost forms may use `http://`
4. Keep `README.md`, `build.zig`, `src/lib.zig`, and workflows aligned when behavior changes.
5. Validate with the commands in `references/development.md`.

## Do Not Regress

- Do not document `Client.init(...)` as opening the upstream stream immediately.
- Do not describe the current matcher as full regex support.
- Do not introduce hidden pre-listen mailbox buffering.
- Do not imply `close()` is an unbind API; current binding lifetime is explicit and local.
- Do not document prebuilt package-manager installation that the repo does not currently provide.
