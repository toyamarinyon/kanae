# kanae

`kanae` switches macOS input sources in response to a small, configurable set of key gestures.

It is intentionally focused on a small job:

- the default left Command single-tap posts the JIS 英数 key event
- the default right Command single-tap posts the JIS かな key event
- pressing another key while Command is held cancels the action
- pressing both Command keys together cancels both actions

The daemon recognizes configured gestures and posts the JIS 英数 / かな key
events directly with `CGEvent.post`. There is no preferences UI and no general
key remapping.

### Bindings

Some apps interpret a key chord through the host input source even though
the chord is meant to run a command rather than type text -- for example, a
terminal multiplexer's prefix key. If a かな input source is active, the
chord's follow-up key types Japanese instead of running the command. `kanae`
can force the JIS 英数 key first, one-way with no restore, whenever a
configured chord is pressed while a configured process is running under the
frontmost app.

Bindings live in `~/.config/kanae/config.json`. `kanae install` creates the
default Command bindings when this file is absent and never overwrites an
existing file:

```json
{
  "bindings": [
    {
      "trigger": { "gesture": "tap", "key": "left_cmd" },
      "action": "ascii"
    },
    {
      "trigger": { "gesture": "tap", "key": "right_cmd" },
      "action": "kana"
    },
    {
      "trigger": {
        "gesture": "press",
        "key": "q",
        "modifiers": ["ctrl"]
      },
      "action": "ascii",
      "process": "herdr"
    }
  ]
}
```

`tap` supports `left_cmd` and `right_cmd`. `press` supports a letter, digit, or
`space`, with any combination of `ctrl`, `cmd`, `shift`, and `alt`. Actions are
`ascii` and `kana`. The optional `process` is matched exactly against process
names in the frontmost app's descendant process tree, so it works regardless
of which terminal emulator hosts the process. Edit the file and run
`kanae restart` to apply changes; malformed bindings are skipped individually
with a message on stderr.

### Migrating from Enka 0.2.0

Kanae is the continuation of Enka under a new product identity. Uninstall Enka
before installing Kanae so both LaunchAgents cannot run at the same time:

```bash
enka uninstall
```

Kanae uses new application, LaunchAgent, installation, state, and
configuration paths. The Enka `asciiInputRules` format has also been removed.
Replace each rule such as
`{ "process": "herdr", "key": "ctrl+q" }` with a `press` binding as shown
above. Add the two default `tap` bindings explicitly if you want to preserve
the original left/right Command behavior. `kanae install` creates those default
bindings when its configuration file is absent.

## Install

Install with one command:

```bash
curl -fsSL https://kanae.ultrahope.dev/install | sh
```

The installer downloads the release archive and configures Kanae automatically:

- downloads the hosted release and checksum
- installs to `~/Applications/kanae` by default
- installs `bin/kanae` and `Kanae.app`
- opens `Kanae.app` and waits for Accessibility permission
- writes the LaunchAgent plist
- starts/restarts the LaunchAgent after permission is granted
- if permission is not granted before timeout, the installer exits with retry guidance

During installation, macOS will ask you to grant Accessibility permission.
Allow `Kanae` in:

```text
System Settings > Privacy & Security > Accessibility
```

You do not need to add the app manually. The installer opens `Kanae.app` so it
appears in the Accessibility list, then waits for permission before starting
the LaunchAgent.

If installation fails while waiting for Accessibility permission, rerun the installer:

```bash
curl -fsSL https://kanae.ultrahope.dev/install | sh
```

If the files are already installed, you can rerun macOS registration directly:

```bash
~/Applications/kanae/bin/kanae install
```

Accessibility permission itself cannot be granted automatically. That part is
controlled by macOS.

## Uninstall

If you want to try another tool, Kanae is easy to remove cleanly:

```bash
kanae uninstall
```

`kanae uninstall` asks before stopping the LaunchAgent and removing the
LaunchAgent plist and installed files.

macOS manages Accessibility permission separately. After uninstalling, open
Accessibility settings, select `Kanae`, then click the minus button below the
app list:

```text
System Settings > Privacy & Security > Accessibility
```

Manual cleanup, if needed:

```bash
rm -rf "$HOME/Applications/kanae"
rm -rf "$HOME/.local/state/kanae"
```

## Why I Built This

I use a US keyboard on macOS and want the left and right Command keys to behave
like dedicated English/Japanese input-source keys when tapped by themselves.

There are already good tools for this. Karabiner-Elements is powerful and
widely used. Other focused open source apps also exist. My reason for building
Enka, which later became Kanae, was narrower: I wanted a tool whose behavior
and implementation are both small enough to understand at a glance.

For my use case, the ideal program does not need to be a general key remapper,
does not need multiple switching modes, and does not need a preferences window.
It only needs to observe Command key taps, cancel when the key is used as a
modifier, and post the corresponding JIS 英数 / かな event.

That constraint is the point of Kanae. It is not meant to replace richer tools
for people who want richer tools. It is meant to be a small, readable daemon
for this one input-source switching habit.

## Acknowledgements

Enka and Kanae were built after learning from prior work in this area:

- [Karabiner-Elements](https://karabiner-elements.pqrs.org/)
- [cmd-eikana](https://github.com/iMasanari/cmd-eikana) and its
  [Apple Silicon fork](https://github.com/dominion525/cmd-eikana)
- [enja-switcher](https://github.com/toshi-kuji/enja-switcher)

Those projects helped clarify what I wanted this tool to be: a smaller tool
with a deliberately narrower scope.

## CLI

Build with SwiftPM:

```bash
swift build
swift build -c release
```

Daemon and lifecycle commands:

```bash
.build/debug/kanae
.build/debug/kanae run
.build/debug/kanae install
.build/debug/kanae status
.build/debug/kanae restart
.build/debug/kanae stop
.build/debug/kanae uninstall
```

Default paths:

- LaunchAgent: `~/Library/LaunchAgents/dev.ultrahope.kanae.plist`
- install root: `~/Applications/kanae`
- state/logs: `~/.local/state/kanae`
- bindings: `~/.config/kanae/config.json`

## Installer Configuration

Environment overrides:

```bash
KANAE_VERSION=0.1.0 \
KANAE_INSTALL_ROOT="$HOME/Applications/kanae" \
KANAE_INSTALL_ORIGIN="https://kanae.ultrahope.dev" \
KANAE_RELEASE_BASE_URL="https://github.com/toyamarinyon/kanae/releases/download" \
KANAE_BASE_URL="https://example.com/custom/path" \
KANAE_SKIP_SETUP=1 \
KANAE_SETUP_WAIT_ACCESSIBILITY_SECONDS=30 \
sh -c "$(curl -fsSL https://kanae.ultrahope.dev/install)"
```

Notes:

- `KANAE_SKIP_SETUP=1` skips automatic configuration after copying files.
- `KANAE_SETUP_WAIT_ACCESSIBILITY_SECONDS` enables a custom timeout for the permission wait.
- `KANAE_INSTALL_ORIGIN` sets the product install site used to resolve `latest.json`.
- `KANAE_RELEASE_BASE_URL` sets the release download base; by default, artifacts are downloaded from GitHub Releases.
- `KANAE_BASE_URL` sets a fully-resolved base path and bypasses the default release download convention.

Development path overrides:

- `KANAE_INSTALL_ROOT`: install root used by installation, status, and plist generation
- `KANAE_LAUNCH_AGENT_DIR`: LaunchAgent directory (default: `~/Library/LaunchAgents`)
- `KANAE_STATE_DIR`: state/log directory (default: `~/.local/state/kanae`)
- `KANAE_CONFIG_DIR`: bindings config directory (default: `~/.config/kanae`)

## Release Packaging

Build a release archive locally:

```bash
sh scripts/package-release.sh
```

Distribution shape:

```text
kanae-v0.1.0-macos-arm64.tar.gz
  Kanae.app/
  bin/kanae
  README.md
  LICENSE (if present)
```

`Kanae.app` metadata is copied from `resources/Kanae.app`.

Customize version/output:

```bash
KANAE_VERSION=0.1.0 \
KANAE_DIST_DIR=/tmp/kanae-dist \
sh scripts/package-release.sh
```

Verify local release artifacts:

```bash
sh scripts/package-release.sh
sh scripts/verify-release.sh
```

Publish a GitHub Release:

1. Open the `Release` workflow in GitHub Actions.
2. Run it manually with a version such as `0.1.0`.
3. The workflow builds and verifies the archive on macOS, then publishes
   `kanae-v0.1.0` with the `.tar.gz` archive and matching `.sha256` file.

GitHub Pages installer site:

```text
docs/
  CNAME
  install
  latest.json
```

Configure GitHub Pages to publish from `main` / `docs`, then assign the custom
domain `kanae.ultrahope.dev`.
