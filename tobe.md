# Enka Next Version Goal

## Background

Enka began with two behaviors built directly into the daemon:

- tapping left Command switches to ASCII input
- tapping right Command switches to Kana input

Version 0.2.0 added `asciiInputRules`. This solved a concrete problem: a key
operation such as herdr's `ctrl+q` prefix can be interpreted through the
current Japanese input source even though the user intends to invoke a command,
not type text. An ASCII input rule lets Enka intervene before that operation
and force the JIS Eisu key.

The feature works, but it leaves two different models in the application:

- the original left/right Command behavior is hard-coded
- additional ASCII triggers are configured separately as exceptions

These are not fundamentally different features. Both observe a key gesture and
invoke one of Enka's input-source actions. The next version should express them
through one configuration model.

## Goal

Replace the hard-coded Command behavior and `asciiInputRules` with a unified
list of bindings.

A binding connects:

1. a key gesture that triggers Enka
2. an Enka action: `ascii` or `kana`
3. an optional process condition

This does not turn Enka into a general-purpose key remapper. Enka will not map
arbitrary keys to other keys or commands. Configuration decides when Enka
acts, while the set of actions remains deliberately limited to input-source
switching.

## Configuration

Use `~/.config/enka/config.json` with the following shape:

```json
{
  "bindings": [
    {
      "trigger": {
        "gesture": "tap",
        "key": "left_cmd"
      },
      "action": "ascii"
    },
    {
      "trigger": {
        "gesture": "tap",
        "key": "right_cmd"
      },
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

### Trigger gestures

`tap` and `press` describe actions performed by the user, rather than the
shape of a key combination.

#### `tap`

A tap is complete when the configured key is pressed and released without any
other key being pressed in between.

For Command keys, pressing another key while Command is held cancels the tap.
Pressing both Command keys together continues to cancel both taps. The action
therefore fires on key release, after Enka knows that the gesture was a tap.

Initial supported tap keys:

- `left_cmd`
- `right_cmd`

#### `press`

A press is complete when the configured key is pressed while the configured
modifiers are active. Its action fires on the non-modifier key-down event. Key
repeat must not fire the action repeatedly.

Initial supported modifiers:

- `ctrl`
- `cmd`
- `shift`
- `alt`

Aliases may be accepted when reading configuration, but the generated config
should use these canonical names.

Initial supported press keys are letters, digits, and `space`, matching the
keys supported by the 0.2.0 ASCII input rules.

### Actions

Supported actions are:

- `ascii`: post the JIS Eisu key event
- `kana`: post the JIS Kana key event

Actions are one-way. Enka does not restore the input source that was active
before a binding fired.

### Optional process condition

`process` is optional. Without it, the binding is active globally.

When specified, the binding is active only when an exact process-name match is
found in the frontmost application's descendant process tree. This allows a
binding to follow a terminal-hosted program such as herdr without tying the
configuration to a particular terminal emulator.

The process condition limits where a binding applies; it is not itself a
trigger and it does not launch the process.

## Installation and defaults

On a fresh installation, `enka install` should create the configuration file
with the two bindings that preserve Enka's original behavior:

```json
{
  "bindings": [
    {
      "trigger": {
        "gesture": "tap",
        "key": "left_cmd"
      },
      "action": "ascii"
    },
    {
      "trigger": {
        "gesture": "tap",
        "key": "right_cmd"
      },
      "action": "kana"
    }
  ]
}
```

Installation must not overwrite an existing configuration file. Reinstalling
or upgrading Enka should preserve the user's bindings.

Because Enka is still under active development and does not promise backward
compatibility, the next version may replace `asciiInputRules` rather than
maintaining two configuration formats. The release notes should call out the
required migration clearly.

Configuration is loaded when the daemon starts. Users run `enka restart` after
editing it.

## Design intent

The purpose of this change is not configuration for its own sake. It removes
an unnecessary distinction between Enka's original behavior and the trigger
added in 0.2.0.

The original Command taps are already bindings; they were simply embedded in
code. Writing them to the generated configuration makes the complete behavior
visible in one place and lets users change when Enka intervenes without
expanding what Enka can do.

The boundary remains:

- Enka observes a small set of keyboard gestures
- Enka optionally scopes them to a frontmost descendant process
- Enka switches the macOS input source to ASCII or Kana
- Enka does not become a general key remapper, command launcher, or automation
  framework

The next version should make that boundary easier to understand in both the
implementation and the documentation.

## Implementation direction

- Introduce a single decoded `Binding` model containing `trigger`, `action`,
  and optional `process`.
- Replace the separate hard-coded Command mapping and resolved ASCII-rule model
  with bindings resolved at daemon startup.
- Keep gesture recognition separate from action execution: recognizing a tap
  or press yields a matched binding, then the action posts Eisu or Kana.
- Validate bindings independently so one malformed entry does not disable valid
  entries.
- Report invalid gestures, keys, modifiers, actions, and process values with
  enough context to locate the bad binding.
- Generate the default config during installation only when the config file is
  absent.
- Update `status` or another CLI surface to show the config path and whether it
  was loaded successfully.
- Document migration from `asciiInputRules` to `bindings` in the release notes.

## Non-goals

- Mapping an arbitrary input key to another arbitrary key
- Running shell commands or launching applications
- Restoring the previous input source after an action
- Adding a preferences UI
- Supporting an open-ended gesture language in the first version
- Preserving the 0.2.0 `asciiInputRules` format indefinitely
