#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.


# ANSI-C quoting ($'...') stores a REAL ESC byte in the variable at
# definition time, instead of the literal 4 characters "\033". This matters
# because plain 'single quotes' only work with echo -e (which interprets
# backslash sequences in its argument) — they silently fail inside any
# `cat << EOF` heredoc, which never interprets escapes and would print the
# literal text "\033[1m" instead of a color. A real byte here works
# everywhere (echo, echo -e, printf, cat heredocs) with no exceptions.
GHOSTMODE_VERSION="3.1"

# full | auto | delete. auto skips live app databases and never passes --force.
GHOSTMODE_MODE="full"
GHOSTMODE_FORCE=0
_GM_STEP_MSG=""
_GM_STEP_FAILS=0

# install.sh saves the sudo password here once (mode 600). Later runs,
# including the timer, read it and do not prompt. It is not in the git repo.
# destroy deletes it. The priv helper is only a fallback if that file is gone.
GHOSTMODE_PRIV="/usr/local/libexec/ghostmode-priv"
GHOSTMODE_SUDO_FILE="$HOME/.config/ghostmode/sudo.pass"
GHOSTMODE_HISTORY_GUARD="$HOME/.config/ghostmode/history-guard.zsh"
GHOSTMODE_HISTORY_GENERATION="$HOME/.config/ghostmode/history.generation"
GHOSTMODE_HISTORY_SAVED="$HOME/.config/ghostmode/history.saved"
GHOSTMODE_SHIELD_STATE="$HOME/.config/ghostmode/shield.state"
GHOSTMODE_TIMER_INTERVAL_FILE="$HOME/.config/ghostmode/timer.interval"
GHOSTMODE_GUARD_MARK="ghostmode-history-guard"

_gm_sudo() {
    # Prefer the saved password so nothing asks again. sudo -S reads it
    # from the file, so the password is not placed on the command line.
    if [[ -f "$GHOSTMODE_SUDO_FILE" ]]; then
        sudo -S -p '' "$@" < "$GHOSTMODE_SUDO_FILE"
        return
    fi
    if [[ -x "$GHOSTMODE_PRIV" ]]; then
        sudo -n "$GHOSTMODE_PRIV" "$@"
        return
    fi
    sudo -n "$@"
}

RED=$'\033[0;31m'
GRN=$'\033[0;32m'
YLW=$'\033[1;33m'
BLU=$'\033[1;34m'
CYN=$'\033[0;36m'
GRY=$'\033[0;37m'
BLD=$'\033[1m'
RST=$'\033[0m'

GHOSTMODE_TRACE_PATHS=(
    "$HOME/.cursor/projects/*/agent-transcripts"
    "$HOME/.cursor/projects/*/agent-tools"
    "$HOME/.cursor/projects/tmp-*"
    "$HOME/.config/Cursor/User/History"
    "$HOME/.ssh/known_hosts"
    "$HOME/.ssh/known_hosts.old"
)

# Ports commonly used by backdoors/RATs — any connection (inbound or
# outbound) on one of these ports is flagged red in "ghostmode connections".
# This is a heuristic indicator only, not definitive proof of a compromise.
GHOSTMODE_BAD_PORTS=(4444 5555 1337 31337 6666 6667 12345 54321 9999 2222)

# Expected/common listening (LISTEN) ports — any other open port is flagged
# yellow (worth reviewing, not necessarily dangerous).
GHOSTMODE_WHITELIST_LISTEN_PORTS=(22 80 443 53 631 5353 3306 5432)

GHOSTMODE_TOR_STATE_FILE="$HOME/.config/ghostmode/tor_state"
GHOSTMODE_CUSTOM_PATHS_FILE="$HOME/.config/ghostmode/custom_paths"
# System-level unit (not user/lingering-dependent) — runs "ghostmode tor on"
# itself at boot via multi-user.target, as the real user via User=. This is
# more reliable than a --user unit + lingering, which depends on the user's
# systemd instance and D-Bus session starting cleanly on every single boot.
GHOSTMODE_TOR_UNIT="/etc/systemd/system/ghostmode-tor-boot.service"
# Legacy unit names from older versions — cleaned up if found.
GHOSTMODE_TOR_LEGACY_UNIT="/etc/systemd/system/ghostmode-tor.service"
GHOSTMODE_TOR_LEGACY_USER_UNIT="$HOME/.config/systemd/user/ghostmode-tor-boot.service"

