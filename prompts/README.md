# Aquarium ❤️ AI coding agents

Anthony built this project with an AI coding agent (Claude Code) in a single
evening. The prompts in this folder make it easy for *you* to do the same —
clone the repo, paste a prompt into your agent of choice, and it'll handle
the install, the permissions, the video fetch, and a smoke test.

## Available prompts

| File | For |
| ---- | --- |
| [`claude.md`](claude.md) | Claude Code (the CLI), Claude Desktop, or Claude in any agent harness |
| [`codex.md`](codex.md) | OpenAI Codex CLI / Codex Cloud |
| [`cursor.md`](cursor.md) | Cursor (Composer / Agent mode) |
| [`generic.md`](generic.md) | Any other coding agent — pure-text, no host-specific syntax |

## How to use

```bash
# 1. clone the repo
git clone https://github.com/aharwelik/aquarium-screensaver.git
cd aquarium-screensaver

# 2. open your favorite AI coding agent here
claude       # or `codex`, or `cursor .`, etc.

# 3. paste the matching prompt from this folder
```

The agent will install Homebrew + ffmpeg + yt-dlp + aria2 if missing, build
the Swift binary, run the video fetch + watermark blur, open the System
Settings pane for Input Monitoring, and run a 1-minute smoke test so you
know it works before it's expected to run.

If you're an enterprise security architect (Anthony is one) and you want to
deploy this through Intune / Jamf instead, see [`docs/permissions.md`](../docs/permissions.md).
