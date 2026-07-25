# AGENTS.md

This app is still under active development. Backward compatibility does not need to be preserved when making changes.

Prefer the best design and implementation for the stated goal, even when that requires breaking existing behavior, removing legacy APIs, deleting obsolete configuration, or changing command-line interfaces. Destructive changes are welcome when they make the project simpler, clearer, or more correct for the current direction.

## Building in Codex

Codex's filesystem sandbox may prevent Swift and Clang from writing to their
usual caches under the user's home directory. In that case, `swift build` can
first report an `Operation not permitted` error for `~/.cache/clang/ModuleCache`
and then emit the misleading secondary error `This SDK is not supported by the
compiler`.

Do not diagnose that secondary message as a Swift/SDK mismatch until the build
has been retried with writable caches. Use temporary paths and disable SwiftPM's
nested sandbox:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/kanae-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/kanae-swiftpm-cache \
swift build --disable-sandbox --scratch-path /tmp/kanae-build
```

Do not set `SDKROOT` unless a retry with writable caches still demonstrates a
real SDK compatibility problem. The ordinary default macOS SDK is expected to
build this project successfully.

## Checking macOS Privacy Permissions in Codex

Do not trust Accessibility/TCC results obtained while running Kanae inside
Codex's filesystem sandbox. A sandboxed invocation such as
`~/Applications/kanae/bin/kanae status` can report
`Accessibility: missing` even when the same command run from the user's normal
terminal correctly reports `Accessibility: granted`.

When checking installed Kanae permission state, run the command outside the
Codex sandbox with escalated execution, or ask the user to run it in their
normal terminal:

```sh
~/Applications/kanae/bin/kanae status
```

Treat the non-sandboxed result as authoritative. Do not reset TCC permissions,
change code signing, reinstall Kanae, or ask the user to repeatedly remove and
re-add the Accessibility entry based only on a sandboxed `missing` result.
