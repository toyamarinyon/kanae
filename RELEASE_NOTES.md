# Kanae 0.1.1

This release makes Kanae's keyboard observation safer and adds an opt-in
diagnostic mode. Existing bindings and the Accessibility-only permission model
remain unchanged.

## Highlights

- Observe keyboard events with a passive event tap. Kanae can no longer modify
  or discard the original event stream while detecting configured triggers.
- Add `kanae run --verbose` for foreground diagnostics. Verbose mode reports
  Command-key events, binding decisions, and synthetic key posts without
  changing normal LaunchAgent logging.
- Keep the existing Accessibility-only permission model. Input Monitoring is
  not required.

To diagnose event handling, temporarily stop the LaunchAgent and run Kanae in
the foreground:

```sh
kanae stop
kanae run --verbose
```

Press `Control-C` when finished, then restore background operation:

```sh
kanae restart
```
