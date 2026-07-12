# Next release

Enka now uses one `bindings` configuration model for both Command-key taps and
modified key presses. The installer creates
`~/.config/enka/config.json` with the original left Command → ASCII and right
Command → Kana behavior when no configuration exists. Existing configuration
files are never overwritten.

## Required migration from 0.2.0

The `asciiInputRules` format is no longer supported. Convert each rule to a
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

Run `enka restart` after changing the configuration. `enka status` reports the
configuration path and whether it loaded successfully.
