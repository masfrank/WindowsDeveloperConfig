#!/usr/bin/env bash
#
# One-click WSL2 setup: zsh + zsh plugins, nvm + Node 24, pnpm/yarn/rimraf,
# and the optional vibe coding tools.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/masfrank/WindowsDeveloperConfig/main/src/wsl-vibe/install-vibe.sh | bash -s -- --tools codex,grok,bun
#   curl -fsSL https://raw.githubusercontent.com/masfrank/WindowsDeveloperConfig/main/src/wsl-vibe/install-vibe.sh | bash -s -- --base-only
#
# Options:
#   --tools codex,grok,bun   Install only these optional groups (codes: codex, grok, bun)
#   --all                    Install every optional group (default when no option is given)
#   --base-only              Only zsh, zsh plugins, nvm, Node 24, pnpm/yarn/rimraf
#   --dry-run                Print every step instead of running it
#   --help                   Show this help
#
# The zsh install step asks for your sudo password part-way through -- that is expected.
# Safe to re-run: every step is an install-what-is-missing operation.

set -euo pipefail

SCRIPT_VERSION='1.0.0'

NVM_INSTALL_URL='https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh'
ZSH_GIST_URL='https://gist.githubusercontent.com/masfrank/d0102fc77a7c2df4f8db7810ee29b7fb/raw/d4d4610e2151d4168460c514e213aab86ba3f651/install-zsh.sh'
ZSH_PLUGIN_GIST_URL='https://gist.githubusercontent.com/masfrank/8c6cf75d67f9fd81ef7217d862227225/raw/install-zsh-plugin.sh'
GROK_INSTALL_URL='https://x.ai/cli/install.sh'
BUN_INSTALL_URL='https://bun.com/install'

CODEX_NPM_PACKAGES='@openai/codex @cometix/claude-code @deepseek-ai/dsh @opencode/cli @earendil-works/pi-coding-agent'
BASE_NPM_PACKAGES='pnpm yarn rimraf'
PI_NPM_PACKAGE='@oh-my-pi/pi-coding-agent'

MODE='all'          # all | base | explicit
WANT_CODEX=0
WANT_GROK=0
WANT_BUN=0
DRY_RUN=0

usage() {
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
}

warn() { printf '\033[1;33m==> %s\033[0m\n' "$*"; }
log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }

# run() evaluates one command line; --dry-run prints it instead.
run() {
    if [ "$DRY_RUN" = '1' ]; then
        printf '    [dry-run] %s\n' "$*"
    else
        eval "$@"
    fi
}

parse_tools() {
    local groups token
    groups=$(printf '%s' "$1" | tr ',' ' ')
    for token in $groups; do
        case "$token" in
            codex) WANT_CODEX=1 ;;
            grok)  WANT_GROK=1 ;;
            bun)   WANT_BUN=1 ;;
            '')    ;;
            *)     printf 'Unknown tool group: %s (known: codex, grok, bun)\n' "$token" >&2; exit 2 ;;
        esac
    done
}

while [ $# -gt 0 ]; do
    case "$1" in
        --tools)
            [ $# -ge 2 ] || { printf -- '--tools needs a value\n' >&2; exit 2; }
            parse_tools "$2"
            MODE='explicit'
            shift 2
            ;;
        --tools=*)
            parse_tools "${1#--tools=}"
            MODE='explicit'
            shift
            ;;
        --all)
            MODE='all'
            shift
            ;;
        --base-only)
            MODE='base'
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ "$MODE" = 'all' ]; then
    WANT_CODEX=1
    WANT_GROK=1
    WANT_BUN=1
fi

# This script installs into $HOME and expects your normal WSL user, not root.
if [ "$(id -u)" -eq 0 ]; then
    warn 'Running as root. Run this as your normal WSL user so the setup lands in your home directory.'
    exit 1
fi

if [ "$DRY_RUN" = '1' ]; then
    warn 'Dry run -- every step is printed, nothing is installed.'
fi

note 'The zsh step asks for your sudo password part-way through; that is expected.'

# ---------------------------------------------------------------------------
# 1. zsh
# ---------------------------------------------------------------------------
log 'Installing zsh'
run 'mkdir -p ~/scripts && cd ~/scripts'
run "wget -O install-zsh.sh $ZSH_GIST_URL"
run 'chmod +x install-zsh.sh'
run 'clear'
run './install-zsh.sh'

# ---------------------------------------------------------------------------
# 2. zsh plugins
# ---------------------------------------------------------------------------
log 'Installing zsh plugins'
run "wget -O install-zsh-plugin.sh $ZSH_PLUGIN_GIST_URL"
run 'chmod +x install-zsh-plugin.sh'
run 'clear'
run './install-zsh-plugin.sh'

# ---------------------------------------------------------------------------
# 3. nvm + Node 24
# ---------------------------------------------------------------------------
log 'Installing nvm and Node 24'
run "curl -o- $NVM_INSTALL_URL | bash"

# nvm is a shell function; source it so the rest of this script can call it directly.
export NVM_DIR="$HOME/.nvm"
if [ "$DRY_RUN" = '1' ]; then
    note '[dry-run] skipping nvm sourcing -- later steps assume Node 24 ends up on PATH.'
elif [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
else
    warn "Could not find nvm at $NVM_DIR after installing it -- check the nvm installer output."
    exit 1
fi
run 'nvm list'
run 'nvm install 24'
run 'nvm use 24'

# ---------------------------------------------------------------------------
# 4. Base global npm tools
# ---------------------------------------------------------------------------
log 'Installing base global npm tools (pnpm, yarn, rimraf)'
run "npm install -g $BASE_NPM_PACKAGES"

# ---------------------------------------------------------------------------
# 5. Optional groups
# ---------------------------------------------------------------------------
if [ "$WANT_CODEX" = '1' ]; then
    log 'Installing npm agent CLIs (codex, claude-code, dsh, opencode, pi-coding-agent)'
    run "npm install $CODEX_NPM_PACKAGES --ignore-scripts"
fi

if [ "$WANT_GROK" = '1' ]; then
    log 'Installing the Grok CLI (x.ai)'
    run "curl -fsSL $GROK_INSTALL_URL | bash"
fi

if [ "$WANT_BUN" = '1' ]; then
    log 'Installing bun and the oh-my-pi coding agent'
    run "curl -fsSL $BUN_INSTALL_URL | bash"
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    run "bun install -g $PI_NPM_PACKAGE"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
show() {
    local label="$1"; shift
    local out
    if out=$("$@" 2>/dev/null); then
        printf '  %-16s %s\n' "$label" "$out"
    else
        printf '  %-16s %s\n' "$label" '(version check unavailable)'
    fi
}

log 'Installed versions'
show 'zsh'      zsh --version
show 'node'     node --version
show 'npm'      npm --version
show 'pnpm'     pnpm --version
show 'yarn'     yarn --version
show 'rimraf'   rimraf --version
show 'nvm'      bash -lc 'nvm --version'
if [ "$WANT_CODEX" = '1' ]; then show 'codex' codex --version; fi
if [ "$WANT_GROK" = '1' ]; then show 'grok' bash -lc 'grok --version'; fi
if [ "$WANT_BUN" = '1' ]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    show 'bun' bun --version
    show 'pi' bash -lc 'pi --version'
fi

log 'Done'
note 'Open a new terminal (or run: exec zsh) for the shell changes to take effect.'
