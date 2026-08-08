# Kanae 0.1.2

This release adds a SwiftPM-centered development workflow for building,
signing, and running Kanae locally without introducing an Xcode project or
weakening the SwiftPM plugin sandbox. The installed application and existing
release workflow remain unchanged.

## Highlights

- Add `./dev` as the one-command entry point for a debug build, local signing,
  Accessibility setup, foreground logs, and `Control-C` shutdown.
- Build the stable `.build/dev/KanaeDev.app` bundle with a sandboxed SwiftPM
  command plugin that does not access the Keychain or launch applications.
- Sign and register the development app after the plugin finishes, keeping
  Accessibility permission scoped to `KanaeDev` instead of the terminal app.
- Support ad hoc signing by default and a fixed local certificate through
  `KANAE_CODE_SIGN_IDENTITY` for stable permission across rebuilds.

Run the development app from the package root:

```sh
./dev
```

To use a fixed local signing identity:

```sh
KANAE_CODE_SIGN_IDENTITY="Kanae Development" ./dev
```
