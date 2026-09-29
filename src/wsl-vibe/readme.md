# WSL Vibe Coding

*One script, run inside your WSL2 distro, that sets up a shell + Node + optional coding CLIs.*

Everything here runs **inside WSL2** — nothing is installed on the Windows side. The Windows Dev Config flow ([`windows-dev-config/README.md`](../windows-dev-config/README.md)) ends with a picker for the optional groups and prints the exact command below; run it inside your distro once.

## Run it

Open your Ubuntu distro from the Start menu (first launch creates your Linux user), then:

```bash
curl -fsSL https://raw.githubusercontent.com/masfrank/WindowsDeveloperConfig/main/src/wsl-vibe/install-vibe.sh | bash -s -- --tools codex,grok,bun
```

From Windows, without opening a terminal first:

```powershell
wsl -d Ubuntu-24.04 -- bash -ic "curl -fsSL https://raw.githubusercontent.com/masfrank/WindowsDeveloperConfig/main/src/wsl-vibe/install-vibe.sh | bash -s -- --tools codex,grok,bun"
```

The zsh step asks for your `sudo` password part-way through — that is expected. The script is safe to re-run.

## Options

| Option | What installs |
| ------ | ------------- |
| *(no option)* | Everything: zsh, zsh plugins, nvm, Node 24, pnpm/yarn/rimraf, and all three optional groups |
| `--tools codex,grok,bun` | The base plus only the listed groups (`codex`, `grok`, `bun`, comma-separated) |
| `--base-only` | zsh, zsh plugins, nvm, Node 24, pnpm/yarn/rimraf — no optional tools |
| `--dry-run` | Prints every step instead of running it |
| `--help` | Usage text |

## What it installs

**Always (the base):**

- `zsh`, via the [`install-zsh.sh`](https://gist.github.com/masfrank/d0102fc77a7c2df4f8db7810ee29b7fb) gist
- The zsh plugins, via the [`install-zsh-plugin.sh`](https://gist.github.com/masfrank/8c6cf75d67f9fd81ef7217d862227225) gist
- nvm `v0.40.8`, then `nvm install 24` + `nvm use 24`
- The global npm tools `pnpm`, `yarn`, `rimraf`

**Optional groups:**

| Group | Command |
| ----- | ------- |
| `codex` | `npm install -g @openai/codex @cometix/claude-code @deepseek-ai/dsh @opencode/cli @earendil-works/pi-coding-agent --ignore-scripts` |
| `grok` | `curl -fsSL https://x.ai/cli/install.sh \| bash` |
| `bun` | `curl -fsSL https://bun.com/install \| bash`, then `bun install -g @oh-my-pi/pi-coding-agent` |

The script prints installed versions at the end, and tells you to `exec zsh` (or open a new terminal) for the shell changes to take effect.

## Requirements

- A WSL2 distro that has been launched once (so your Linux user exists) — the Ubuntu 24.04 that Windows Dev Config installs works out of the box.
- A normal (non-root) user in the distro; the script refuses to install as root.
- Network access to `gist.githubusercontent.com`, `raw.githubusercontent.com`, `x.ai`, and `bun.com`.
