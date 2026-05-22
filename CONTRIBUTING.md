# Contributing to Aquarium

Thanks for considering a contribution! This is a small personal project by
**Anthony Harwelik** that escaped into the wild — I'm happy to take PRs that
keep it small and focused.

## Ways to help

- **Tell me what's broken.** Open a GitHub issue with your hardware, macOS
  version, and what you saw. Screenshots are gold.
- **Add a source video preset.** If you know a CC-licensed 4K HDR aquarium
  clip people can swap in via the settings panel, please link it.
- **Real Metal fish simulator.** The "fish swim across displays" dream needs
  a real-time renderer that knows global display geometry. I haven't built
  one. If you do, I'll happily fold it in.
- **App-bundle (`.app`) packaging.** Right now you `git clone` and run the
  installer — an installable `.app` would lower the bar a lot.
- **`.saver` bundle.** Making this load through System Settings → Screen
  Saver would be the proper macOS-native ending to the project.

## Development setup

```bash
git clone https://github.com/aharwelik/aquarium-screensaver.git
cd aquarium-screensaver
./install.sh
```

The whole app is one file (`Aquarium.swift`) compiled to a single binary —
no Xcode project, no Swift Package Manager, no Cocoapods, no nothing. Edit,
`swiftc -O Aquarium.swift -o bin/aquarium-bin`, run.

## Code style

- Match the existing voice: comments explain **why**, not what. The reader
  can see what.
- Prefer `MARK: - ` section headers over splitting into more files. The
  whole point of one-file-Swift is that you can read it linearly.
- AVFoundation is the rendering pipeline of record — please don't reach for
  Metal directly unless the change requires it.
- `defaults` keys live in the `com.harwelik.aquarium` suite. If you add a
  new one, add it to `AquariumDefaults` and to the settings panel.

## Reviewing your own PR

Before opening:

1. `swiftc -O Aquarium.swift -o /tmp/aq` — no warnings, no errors.
2. `/tmp/aq --duration 1` — runs, paints fish, exits on input or after
   60 seconds.
3. `defaults delete com.harwelik.aquarium` — your changes work from a fresh
   defaults state.

## Sensitive content / safe to share?

Don't include screenshots in PRs that show identifiable third-party content
(work email, client documents, etc.). I caught one of mine doing this during
development; you might too.

## License

By submitting a PR you agree to MIT-license the contribution.
