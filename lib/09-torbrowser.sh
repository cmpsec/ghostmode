#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.

# ============================================================
#  TOR BROWSER LAUNCHER  (runs it as the exempted "torbrowser" user so it
#  connects directly to the real Tor network instead of nesting inside
#  anonsurf's system-wide tunnel)
# ============================================================

GHOSTMODE_TB_PATH_FILE="$HOME/.config/ghostmode/torbrowser_path"

cmd_torbrowser() {
    local tb_path="${1:-}"
    if [[ -z "$tb_path" ]]; then
        tb_path=$(cat "$GHOSTMODE_TB_PATH_FILE" 2>/dev/null)
    fi
    # Fast path: the standard torbrowser-launcher install location
    # (apt install torbrowser-launcher — the normal way to get Tor Browser
    # on Debian/Kali) before falling back to a slower full search.
    if [[ -z "$tb_path" || ! -x "$tb_path" ]]; then
        local standard_path="$HOME/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/start-tor-browser"
        [[ -x "$standard_path" ]] && tb_path="$standard_path"
    fi
    if [[ -z "$tb_path" || ! -x "$tb_path" ]]; then
        echo "Usage: ghostmode torbrowser /path/to/start-tor-browser"
        echo "(the path is remembered after the first successful run)"
        echo ""
        echo "Searching common locations..."
        find "$HOME" /opt /home -iname "start-tor-browser" -type f 2>/dev/null
        return 1
    fi
    if ! id -u torbrowser >/dev/null 2>&1; then
        echo -e "  ${YLW}!${RST} The 'torbrowser' exempt user doesn't exist yet — run ${GRN}ghostmode tor on${RST} first."
        return 1
    fi
    mkdir -p "$(dirname "$GHOSTMODE_TB_PATH_FILE")"
    echo "$tb_path" > "$GHOSTMODE_TB_PATH_FILE"

    # Kill any previous Tor Browser instance first, every time. A background
    # copy left running from an earlier launch is exactly what causes
    # "Tor Browser is already running, but is not responding" and an
    # apparent hang on the next launch attempt — so each invocation starts
    # from a guaranteed-clean slate instead of trying to detect staleness.
    echo CHANGEME_PASSWORD | sudo -S pkill -9 -u torbrowser 2>/dev/null
    sleep 1

    # torbrowser (a separate system user) can't read into your home
    # directory at all by default — Debian/Kali home dirs block other users
    # regardless of individual file permissions. Rather than loosening your
    # home directory's permissions, give torbrowser its own private copy
    # that it fully owns, refreshed whenever the source bundle updates.
    local tb_home
    tb_home=$(getent passwd torbrowser | cut -d: -f6)
    local bundle_root
    bundle_root=$(dirname "$(dirname "$tb_path")")
    local dest_root="${tb_home}/tor-browser"

    if [[ ! -x "${dest_root}/Browser/start-tor-browser" ]] \
       || [[ "$tb_path" -nt "${dest_root}/Browser/start-tor-browser" ]]; then
        echo -e "  ${GRY}Copying the Tor Browser bundle to the exempted user's own directory (first run, or an update was found)...${RST}"
        echo CHANGEME_PASSWORD | sudo -S rm -rf "$dest_root" 2>/dev/null
        echo CHANGEME_PASSWORD | sudo -S cp -a "$bundle_root" "$dest_root" 2>/dev/null
        echo CHANGEME_PASSWORD | sudo -S chown -R torbrowser:torbrowser "$dest_root" 2>/dev/null
    fi

    # kill -9 doesn't give the browser a chance to clean up its own lock
    # files — clear any that survived, or the next launch sees a stale lock
    # and refuses to start even though nothing is actually running anymore.
    find "$dest_root" -maxdepth 6 \( -iname "lock" -o -iname ".parentlock" \) -delete 2>/dev/null

    # xhost's SI:localuser exception lets another local user connect to this
    # X display without needing to read your .Xauthority file at all (which
    # it couldn't read anyway, same home-directory restriction as above).
    command -v xhost >/dev/null 2>&1 && xhost +SI:localuser:torbrowser >/dev/null 2>&1

    echo -e "  ${GRN}${BLD}[+] Launching Tor Browser as the exempted user...${RST}"
    echo CHANGEME_PASSWORD | sudo -S -u torbrowser env HOME="$tb_home" DISPLAY="$DISPLAY" \
        "${dest_root}/Browser/start-tor-browser" &
}

