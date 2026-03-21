# Development Guide

## Workdir

```bash
cd sdk/zig
```

## Validate

Current repository validation contract:

```bash
zig build
```

Also confirm the runtime transport dependency exists when testing the built-in
stream path:

```bash
curl --version
```

## Release Model

- Workflow file: `../../../.github/workflows/release.yml`
- Trigger: push tag `v*` or manual workflow dispatch
- Current release output is a source archive uploaded to GitHub Release
- The repository does not currently define `zig build install` output or a
  package-registry publish flow

## Keep Aligned

- `../../../build.zig`
- `../../../src/lib.zig`
- `../../../README.md`
- `../../../.github/workflows/ci.yml`
- `../../../.github/workflows/release.yml`

## Editing Notes

- Keep transport descriptions aligned with the current `curl`-based
  implementation until the code changes.
- If matcher semantics change, update both `README.md` and this skill in the
  same change.
- If the client lifecycle changes so `init(...)` starts the stream directly,
  update this skill immediately because that would be a breaking semantic shift.
