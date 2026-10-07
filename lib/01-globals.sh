#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.


# ANSI-C quoting ($'...') stores a REAL ESC byte in the variable at
# definition time, instead of the literal 4 characters "\033". This matters
# because plain 'single quotes' only work with echo -e (which interprets
# backslash sequences in its argument) — they silently fail inside any
# `cat << EOF` heredoc, which never interprets escapes and would print the
# literal text "\033[1m" instead of a color. A real byte here works
# everywhere (echo, echo -e, printf, cat heredocs) with no exceptions.
GHOSTMODE_VERSION="2.0"

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

