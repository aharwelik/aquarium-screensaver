# Security Policy

## Reporting a vulnerability

I'm **Anthony Harwelik** and I take this seriously. If you've found a security
issue in Aquarium — anything from a sandbox escape to a privacy leak to an
unintended file-system reach — please report it privately.

**Preferred channel:** open a [private vulnerability advisory on
GitHub](https://github.com/aharwelik/aquarium-screensaver/security/advisories/new).

**Alternative:** email me at `aharwelik@gmail.com` with the subject line
`Aquarium security disclosure` and I'll respond within 72 hours.

Please **do not** open a public GitHub issue for security problems.

## Scope

In scope:

- The compiled `aquarium-bin` Swift binary.
- The `install.sh` / `uninstall.sh` / `scripts/fetch-video.sh` install path.
- The `defaults` storage under `com.harwelik.aquarium`.

Out of scope:

- Vulnerabilities in macOS itself, AVFoundation, AppKit, SwiftUI, ffmpeg,
  yt-dlp, aria2, or Homebrew.
- Issues that require the attacker to already have unsandboxed local code
  execution as the user.
- The source video file's container or codec (handled by AVFoundation).

## What to expect

| Severity   | First response | Patch target |
| ---------- | -------------- | ------------ |
| Critical   | 24 hours       | 7 days       |
| High       | 72 hours       | 14 days      |
| Medium     | 1 week         | 30 days      |
| Low / info | 2 weeks        | next release |

I will credit reporters in the changelog unless you ask me not to.

## Supply chain

The release process for this repo is:
1. Tag a commit
2. GitHub Actions builds `aquarium-bin` from `Aquarium.swift`
3. The release page shows the source-zip checksum

There is no separate pre-built binary distribution. If you find a binary
labelled "Aquarium" anywhere other than `github.com/aharwelik/aquarium-screensaver`,
treat it as suspicious.

## Anthony's day-job context

I work in compliant-environment Microsoft 365 / Azure / Intune deployments
through [BluetechGreen](https://bluetechgreen.com), including putting Claude
behind enterprise data-protection controls. I care about this stuff. Tell me
when something's wrong and I'll act on it.
