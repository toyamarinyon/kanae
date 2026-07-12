# Kanae 0.1.0

Kanae continues the work that began as Enka under a new product identity. It
uses one `bindings` configuration model for both Command-key taps and modified
key presses. The installer creates
`~/.config/kanae/config.json` with the original left Command → ASCII and right
Command → Kana behavior when no configuration exists. Existing configuration
files are never overwritten.

## Required migration from Enka 0.2.0

Uninstall Enka before installing Kanae so their LaunchAgents do not run at the
same time. Kanae uses new application, Bundle ID, LaunchAgent, installation,
state, and configuration paths.

The Enka `asciiInputRules` format is no longer supported. Convert each rule to a
binding and include the default Command tap bindings explicitly if you want to
retain that behavior. For example:

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

Run `kanae restart` after changing the configuration. `kanae status` reports the
configuration path and whether it loaded successfully.
