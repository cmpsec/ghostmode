#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.

cmd_status() {
    echo ""
    echo -e "${BLD}${BLU}╔══════════════════════════════════════════════════╗${RST}"
    echo -e "${BLD}${BLU}║                  STATUS REPORT                  ║${RST}"
    echo -e "${BLD}${BLU}╚══════════════════════════════════════════════════╝${RST}"
    echo -e "  ${GRY}v${GHOSTMODE_VERSION} — $(date '+%Y-%m-%d %H:%M:%S')${RST}"
    echo ""

    echo -e "${BLD}${CYN}[ Device & System ]${RST}"
    _check_system_info

    echo ""
    echo -e "${BLD}${CYN}[ Battery ]${RST}"
    _check_battery

    echo ""
    echo -e "${BLD}${CYN}[ Clipboard ]${RST}"
    _check_clipboard

    echo ""
    echo -e "${BLD}${CYN}[ Shell Histories ]${RST}"
    _check_file ~/.zsh_history        "zsh history"
    _check_file ~/.bash_history       "bash history"
    _check_file ~/.python_history     "python history"
    _check_file ~/.node_repl_history  "node history"
    _check_file ~/.mysql_history      "mysql history"
    _check_zsh_autosuggest
    _check_file ~/.psql_history       "psql history"
    _check_file ~/.pgpass            "pgpass (passwords)"
    _check_file ~/.pg_service.conf   "pg_service.conf"
    _check_file ~/.sqlite_history     "sqlite history"
    _check_file ~/.lesshst            "less history"
    _check_file ~/.viminfo            "vim info"
    _check_file ~/.wget-hsts          "wget hsts"

    echo ""
    echo -e "${BLD}${CYN}[ Recently Used Files ]${RST}"
    _check_recently_used
    _check_dbus_opened
    _check_document_viewers
    _check_telemetry
    _check_dir  ~/.local/share/gvfs-metadata  "gvfs-metadata"

    echo ""
    echo -e "${BLD}${CYN}[ Messengers ]${RST}"
    _check_messengers

    echo ""
    echo -e "${BLD}${CYN}[ Cache & Thumbnails ]${RST}"
    _check_dir ~/.cache/thumbnails        "thumbnails (~/.cache)"
    _check_dir ~/.thumbnails              "thumbnails (legacy)"
    _check_sqlite_wal_shm
    _check_dir ~/.cache/sessions          "sessions cache"
    _check_dir ~/.cache/mozilla           "firefox cache"
    _check_dir ~/.cache/chromium          "chromium cache"
    _check_dir ~/.cache/google-chrome     "chrome cache"
    _check_dir ~/.cache/pip               "pip cache"
    _check_dir ~/.cache/claude            "claude cache"

    echo ""
    echo -e "${BLD}${CYN}[ Cursor IDE ]${RST}"
    _check_trace_paths
    _check_cursor_projects
    _check_cursor_databases
    _check_cursor_plans
    _check_cursor_ai
    _check_dir  ~/.config/Cursor/logs       "Cursor/logs"
    _check_cursor_cache
    _check_dir  ~/.config/Cursor/CachedData "Cursor/CachedData"
    _check_file ~/.config/Cursor/Cookies    "Cursor/Cookies"
    _check_dir  ~/.config/Cursor/Backups    "Cursor/Backups"
    _check_dir  ~/.config/Cursor/GPUCache   "Cursor/GPUCache"
    _check_dir  ~/.config/Cursor/DawnGraphiteCache "Cursor/DawnCache"
    _check_dir  ~/.config/Cursor/Crashpad   "Cursor/Crashpad"

    echo ""
    echo -e "${BLD}${CYN}[ Claude / Antigravity / OpenCode ]${RST}"
    _check_claude_traces
    _check_coding_agents

    echo ""
    echo -e "${BLD}${CYN}[ Temp Directories ]${RST}"
    _check_tmp /tmp     "/tmp"
    _check_tmp /var/tmp "/var/tmp"

    echo ""
    echo -e "${BLD}${CYN}[ Home Directory (~) ]${RST}"
    _check_home_dir

    echo ""
    echo -e "${BLD}${CYN}[ System Logs ]${RST}"
    _check_log /var/log/auth.log    "auth.log"
    _check_log /var/log/syslog      "syslog"
    _check_log /var/log/kern.log    "kern.log"
    _check_log /var/log/dpkg.log    "dpkg.log"
    _check_log /var/log/wtmp        "wtmp (logins)"
    _check_log /var/log/btmp        "btmp (failed)"
    _check_log /var/log/faillog     "faillog"
    _check_log /var/log/lastlog     "lastlog"

    echo ""
    echo -e "${BLD}${CYN}[ Hidden Tracking ]${RST}"
    _check_file ~/.bash_sessions_startup  "bash_sessions"
    _check_dir  ~/.local/share/zeitgeist  "zeitgeist"
    _check_dir  ~/.local/share/tracker    "tracker"
    _check_dir  ~/.local/share/recently-used.d "recently-used.d"
    _check_file ~/.xsession-errors        "xsession-errors"
    _check_file ~/.xsession-errors.old    "xsession-errors.old"
    _check_dir  ~/.dbus                   "dbus sessions"
    _check_journal

    echo ""
    echo -e "${BLD}${CYN}[ Swap ]${RST}"
    local swap_used padded
    padded=$(printf "%-22s" "swap usage")
    if ! awk 'NR>1 { found=1 } END { exit !found }' /proc/swaps 2>/dev/null; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not present${RST}"
    else
        swap_used=$(free -h | awk '/^Swap:/ {print $3}')
        if [[ "$swap_used" == "0B" || "$swap_used" == "0" ]]; then
            echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
        else
            echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${swap_used}${RST}"
        fi
    fi

    echo ""
    echo -e "${BLD}${CYN}[ Firefox ESR ]${RST}"
    _check_firefox

    echo ""
    echo -e "${BLD}${CYN}[ GNOME Shell ]${RST}"
    _check_gnome_shell

    echo ""
    echo -e "${BLD}${CYN}[ Text Editors ]${RST}"
    _check_text_editors

    echo ""
    echo -e "${BLD}${CYN}[ Trash ]${RST}"
    _check_trash

    echo ""
    echo -e "${BLD}${CYN}[ Service Logs ]${RST}"
    _check_service_logs

    echo ""
    echo -e "${BLD}${CYN}[ Network ]${RST}"
    _check_network_manager

    echo ""
    echo -e "${BLD}${CYN}[ SSH Keys ]${RST}"
    _check_ssh_keys

    echo ""
    echo -e "${BLD}${CYN}[ VPS / VNC Traces ]${RST}"
    _check_vnc_traces

    echo ""
    echo -e "${BLD}${CYN}[ Custom Paths ]${RST}"
    _check_custom_paths

    echo ""
    echo -e "${BLD}${CYN}[ Pentest Tool Traces ]${RST}"
    _check_pentest_traces

    echo ""
    echo -e "${BLD}${CYN}[ Additional Traces ]${RST}"
    _check_locate_db
    _check_crash_dumps
    _check_chromium
    _check_apt_logs
    _check_user_journal

    echo ""
    echo -e "${BLD}${CYN}[ Service ]${RST}"
    padded=$(printf "%-22s" "auto-clean timer")
    # Checks the system-level unit first (current, reliable); falls back to
    # the older --user one so status still works right after an upgrade
    # before the next "ghostmode tor on"-style re-arm touches it.
    local sctl=""
    if systemctl is-active --quiet ghostmode-timer.timer 2>/dev/null; then
        sctl="system"
    elif systemctl --user is-active --quiet ghostmode-timer.timer 2>/dev/null; then
        sctl="user"
    fi
    if [[ -n "$sctl" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}ACTIVE${RST} (${sctl}-level)"
        local next_val pd2
        next_val=$(_timer_next_text "$sctl")
        pd2=$(printf "%-22s" "next trigger")
        echo -e "  ${GRN}◷${RST}  ${pd2} → ${YLW}${next_val}${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${RED}INACTIVE${RST}"
    fi
    local pd3
    pd3=$(printf "%-22s" "lingering (boot)")
    if loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
        echo -e "  ${GRN}✔${RST}  ${pd3} → ${GRN}enabled (survives reboot)${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${pd3} → ${RED}disabled${RST}"
    fi

    echo ""
    _shield_status
    echo ""
    echo -e "${BLD}${CYN}[ Machine ]${RST}"
    _check_disk_encryption
    _check_screen_lock
    _check_core_limit
    _check_home_perms
    _check_hibernate
    _check_fingerprint_auto
    _check_cursor_sockets
    echo ""
    echo -e "${BLD}${CYN}[ Git credentials ]${RST}"
    _check_git_credentials

    echo ""
    echo -e "${BLD}${BLU}══════════════════════════════════════════════════${RST}"
    echo -e "  ${GRY}Green here means that layer checked out. It does not mean the machine is fully clean.${RST}"
    echo ""
}


_step() {
    local label="$1"
    shift
    _GM_STEP_MSG=""
    local rc=0
    "$@" || rc=$?
    local padded
    padded=$(printf "%-45s" "$label")
    case "$rc" in
        0)
            echo -e "  ${GRN}✔${RST}  ${padded} ${GRN}cleared${RST}"
            [[ -n "$_GM_STEP_MSG" ]] && echo -e "       ${GRY}${_GM_STEP_MSG}${RST}"
            ;;
        2)
            echo -e "  ${YLW}!${RST}  ${padded} ${YLW}${_GM_STEP_MSG:-skipped}${RST}"
            [[ ! -t 1 ]] && echo -e "  ${YLW}!${RST}  ${label}: ${_GM_STEP_MSG:-skipped}" >&2
            ;;
        *)
            echo -e "  ${RED}✘${RST}  ${padded} ${RED}${_GM_STEP_MSG:-still present}${RST}"
            [[ ! -t 1 ]] && echo -e "  ${RED}✘${RST}  ${label}: ${_GM_STEP_MSG:-still present}" >&2
            _GM_STEP_FAILS=$((_GM_STEP_FAILS + 1))
            ;;
    esac
    sleep 0.4
}

_empty_dir() {
    local d
    for d in "$@"; do
        [[ -d "$d" ]] || continue
        find "$d" -mindepth 1 -depth -delete 2>/dev/null || return 1
    done
}

_dir_clean() {
    local d
    for d in "$@"; do
        [[ -d "$d" ]] || continue
        if [[ -n "$(find "$d" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
            _GM_STEP_MSG="not empty: ${d/#$HOME/~}"
            return 1
        fi
    done
    return 0
}

_c_clipboard() {
    echo -n '' | xclip -selection clipboard 2>/dev/null || true
    echo -n '' | xclip -selection primary 2>/dev/null || true
    rm -f -- "$HOME/.cache/xfce4/clipman/textsrc" 2>/dev/null || true
    mkdir -p "$HOME/.cache/xfce4/clipman" 2>/dev/null || true
    : > "$HOME/.cache/xfce4/clipman/textsrc" 2>/dev/null || true
    local clip
    clip=$(xclip -selection clipboard -o 2>/dev/null || true)
    if [[ -n "$clip" ]]; then
        _GM_STEP_MSG="clipboard still has data"
        return 1
    fi
    if [[ -s "$HOME/.cache/xfce4/clipman/textsrc" ]]; then
        _GM_STEP_MSG="clipman history still has data"
        return 1
    fi
    return 0
}

_c_app_histories() {
    rm -f -- \
        "$HOME/.python_history" "$HOME/.node_repl_history" "$HOME/.mysql_history" \
        "$HOME/.psql_history" "$HOME/.pgpass" "$HOME/.pg_service.conf" \
        "$HOME/.sqlite_history" "$HOME/.lesshst" "$HOME/.viminfo" "$HOME/.wget-hsts" \
        "$HOME/.bash_sessions_startup" "$HOME/.xsession-errors" "$HOME/.xsession-errors.old"
    local f
    for f in "$HOME/.python_history" "$HOME/.mysql_history" "$HOME/.sqlite_history" "$HOME/.viminfo" "$HOME/.pgpass"; do
        if [[ -s "$f" ]]; then
            _GM_STEP_MSG="still present: ${f/#$HOME/~}"
            return 1
        fi
    done
    return 0
}

_c_recent() {
    rm -f -- "$HOME/.local/share/recently-used.xbel" "$HOME/.local/share/recently-used.xbel."* 2>/dev/null || true
    ln -sfn /dev/null "$HOME/.local/share/recently-used.xbel" 2>/dev/null || return 1
    rm -rf -- "$HOME/.local/share/gvfs-metadata" 2>/dev/null || true
    if [[ -f "$HOME/.local/share/recently-used.xbel" && ! -L "$HOME/.local/share/recently-used.xbel" && -s "$HOME/.local/share/recently-used.xbel" ]]; then
        _GM_STEP_MSG="recently-used.xbel still has entries"
        return 1
    fi
    return 0
}

_c_cache() {
    _empty_dir "$HOME/.cache/thumbnails" "$HOME/.thumbnails" "$HOME/.cache/sessions" \
        "$HOME/.cache/mozilla" "$HOME/.cache/chromium" "$HOME/.cache/google-chrome" \
        "$HOME/.cache/pip" "$HOME/.cache/claude" || true
    _dir_clean "$HOME/.cache/thumbnails" "$HOME/.thumbnails" "$HOME/.cache/pip"
}

_c_wal() {
    find "$HOME/.config" "$HOME/.local/share" -maxdepth 8 \
        \( -name '*.db-wal' -o -name '*.db-shm' -o -name '*.sqlite-wal' -o -name '*.sqlite-shm' \
           -o -name '*.vscdb-wal' -o -name '*.vscdb-shm' \) \
        -type f -delete 2>/dev/null || true
    local left
    left=$(find "$HOME/.config/Cursor" "$HOME/.cursor" -name '*.vscdb-wal' -o -name 'state.vscdb-wal' -type f -size +0c 2>/dev/null | head -n 1 || true)
    if [[ -n "$left" && "$GHOSTMODE_MODE" != "auto" && -z "$(_cursor_running)" ]]; then
        _GM_STEP_MSG="a WAL file is still present"
        return 1
    fi
    if [[ -n "$left" && -n "$(_cursor_running)" ]]; then
        _GM_STEP_MSG="Cursor is running, left its open WAL files"
        return 2
    fi
    return 0
}

_c_zeitgeist() {
    rm -rf -- "$HOME/.local/share/zeitgeist" "$HOME/.local/share/tracker" 2>/dev/null || true
    tracker3 reset -s -r >/dev/null 2>&1 || true
    tracker reset --hard >/dev/null 2>&1 || true
    _dir_clean "$HOME/.local/share/zeitgeist" "$HOME/.local/share/tracker"
}

_c_tmp() {
    find /tmp -maxdepth 1 \
        -not -name 'tmp' \
        -not -name 'systemd-private*' \
        -not -name 'snap-private-tmp' \
        -not -name '.X*' \
        -not -name '.ICE*' \
        -not -name '.font-unix' \
        -not -name '.org.chromium.*' \
        -not -name '.mount_cursor*' \
        \( -user "$USER" \) \
        \( -type f -o -type d \) \
        -exec rm -rf {} + 2>/dev/null || true
    local sock
    shopt -s nullglob
    for sock in /tmp/*.sock /tmp/*.socket; do
        [[ -S "$sock" ]] || continue
        [[ "$(stat -c '%U' "$sock" 2>/dev/null)" == "$USER" ]] || continue
        ss -x 2>/dev/null | grep -qF "$sock" || rm -f -- "$sock" 2>/dev/null || true
    done
    shopt -u nullglob
    return 0
}

_c_vartmp() {
    find /var/tmp -maxdepth 1 -user "$USER" -not -name 'tmp' -not -name 'systemd-private*' \
        -exec rm -rf {} + 2>/dev/null || true
    return 0
}

_c_home_dirs() {
    local d
    for d in "$HOME/Downloads" "$HOME/Music" "$HOME/Videos" "$HOME/Pictures" \
             "$HOME/Documents" "$HOME/Desktop" "$HOME/Templates" "$HOME/Public"; do
        [[ -d "$d" ]] || continue
        find "$d" -mindepth 1 -depth -delete 2>/dev/null || true
    done
    _dir_clean "$HOME/Downloads" "$HOME/Documents" "$HOME/Desktop"
}

_c_home_scripts() {
    find "$HOME" -maxdepth 1 -type f \
        \( -name '*.sh' -o -name '*.py' -o -name '*.pl' -o -name '*.rb' -o -name '*.bash' -o -name '*.zsh' \) \
        -not -name '.*' -delete 2>/dev/null || true
    local left
    left=$(find "$HOME" -maxdepth 1 -type f \
        \( -name '*.sh' -o -name '*.py' -o -name '*.pl' -o -name '*.rb' \) \
        -not -name '.*' -print -quit 2>/dev/null || true)
    if [[ -n "$left" ]]; then
        _GM_STEP_MSG="a script is still in the home directory"
        return 1
    fi
    return 0
}

_c_journal() {
    _gm_sudo journalctl --rotate -q || { _GM_STEP_MSG="journalctl failed"; return 1; }
    _gm_sudo journalctl --vacuum-time=1s -q || { _GM_STEP_MSG="journal vacuum failed"; return 1; }
    _gm_sudo find /var/log/journal -type f \( -name '*.journal~' \) -delete 2>/dev/null || true
    _gm_sudo systemctl kill --kill-who=main -s USR2 systemd-journald 2>/dev/null || true
    return 0
}

_c_syslogs() {
    local f failed=0
    for f in /var/log/auth.log /var/log/syslog /var/log/kern.log \
             /var/log/wtmp /var/log/btmp /var/log/lastlog \
             /var/log/dpkg.log /var/log/faillog; do
        [[ -e "$f" ]] || continue
        _gm_sudo truncate -s 0 "$f" || failed=1
        if [[ -s "$f" ]]; then
            failed=1
        fi
    done
    if [[ "$failed" -eq 1 ]]; then
        _GM_STEP_MSG="a system log still has content or truncate was refused"
        return 1
    fi
    return 0
}

_c_swap() {
    if ! awk 'NR>1 { found=1 } END { exit !found }' /proc/swaps 2>/dev/null; then
        _GM_STEP_MSG="no swap on this machine"
        return 0
    fi
    _gm_sudo swapoff -a || { _GM_STEP_MSG="swapoff failed"; return 1; }
    _gm_sudo swapon -a || { _GM_STEP_MSG="swapon failed"; return 1; }
    return 0
}

_c_ssh() {
    rm -f -- "$HOME/.ssh/id_"* "$HOME/.ssh/"*.pem "$HOME/.ssh/"*.key \
        "$HOME/.ssh/known_hosts" "$HOME/.ssh/known_hosts.old" \
        "$HOME/.ssh/authorized_keys" "$HOME/.ssh/config" 2>/dev/null || true
    mkdir -p "$HOME/.ssh"
    : > "$HOME/.ssh/known_hosts"
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh/known_hosts"
    if [[ -s "$HOME/.ssh/known_hosts" ]]; then
        _GM_STEP_MSG="known_hosts still has entries"
        return 1
    fi
    local left
    left=$(find "$HOME/.ssh" -maxdepth 1 -type f \( -name 'id_*' -o -name '*.pem' -o -name 'config' \) -print -quit 2>/dev/null || true)
    if [[ -n "$left" ]]; then
        _GM_STEP_MSG="an SSH key or config is still present"
        return 1
    fi
    return 0
}

_c_vnc() {
    if [[ -d "$HOME/.vnc" ]]; then
        find "$HOME/.vnc" -maxdepth 2 \
            \( -name '*.log' -o -name '*.pid' -o -name 'xstartup' -o -name 'passwd' -o -name 'vncpasswd' \) \
            -type f -delete 2>/dev/null || true
    fi
    find "$HOME" -maxdepth 3 \( -name '*.vnc' -o -name 'vncpasswd' \) -type f -delete 2>/dev/null || true
    find "$HOME" /tmp -maxdepth 2 \
        \( -name '.x11vncpass' -o -name 'x11vncpass' -o -name 'vp' \) \
        -type f -delete 2>/dev/null || true
    rm -rf -- "$HOME/.config/tigervnc" 2>/dev/null || true
    rm -f -- "$HOME/setup_vnc.py" 2>/dev/null || true
    return 0
}

_c_remmina() {
    rm -rf -- "$HOME/.local/share/remmina" "$HOME/.remmina" 2>/dev/null || true
    _dir_clean "$HOME/.local/share/remmina" "$HOME/.remmina"
}

_c_firefox() {
    if _proc_running firefox firefox-esr; then
        _GM_STEP_MSG="Firefox is open, skipped its databases"
        return 2
    fi
    local ff_profile db
    ff_profile=$(find "$HOME/.mozilla/firefox" -maxdepth 1 -type d \
        \( -name '*.default-esr' -o -name '*.default' \) 2>/dev/null | head -1)
    if [[ -z "$ff_profile" ]]; then
        return 0
    fi
    for db in places.sqlite cookies.sqlite formhistory.sqlite webappstore.sqlite \
              content-prefs.sqlite favicons.sqlite storage.sqlite; do
        rm -f -- "$ff_profile/$db" "$ff_profile/${db}-wal" "$ff_profile/${db}-shm"
    done
    rm -f -- "$ff_profile/sessionstore.jsonlz4" 2>/dev/null || true
    rm -f -- "$ff_profile/sessionstore-backups/"*.jsonlz4 2>/dev/null || true
    rm -rf -- "$ff_profile/cache2" "$ff_profile/startupCache" "$HOME/.cache/firefox" "$HOME/.cache/mozilla" 2>/dev/null || true
    if [[ -s "$ff_profile/places.sqlite" ]]; then
        _GM_STEP_MSG="Firefox places.sqlite is still present"
        return 1
    fi
    return 0
}

_c_gnome() {
    rm -f -- "$HOME/.local/share/gnome-shell/application_state" \
        "$HOME/.local/share/gnome-shell/session-active-history.json" \
        "$HOME/.local/share/gnome-shell/session.gvdb" 2>/dev/null || true
    return 0
}

_c_texteditor() {
    rm -f -- "$HOME/.local/share/org.gnome.TextEditor/recently-used.xbel" \
        "$HOME/.local/share/org.gnome.TextEditor/session.gvariant" 2>/dev/null || true
    rm -rf -- "$HOME/.local/share/org.gnome.TextEditor/drafts" 2>/dev/null || true
    return 0
}

_c_cherrytree() {
    local cfg="$HOME/.config/cherrytree/config.cfg"
    [[ -f "$cfg" ]] || return 0
    sed -i "s|^pick_dir_file=.*|pick_dir_file=$HOME|" "$cfg" || return 1
    sed -i "s|^pick_dir_export=.*|pick_dir_export=$HOME|" "$cfg" || return 1
    sed -i "s|^pick_dir_import=.*|pick_dir_import=$HOME|" "$cfg" || return 1
    sed -i "s|^pick_dir_img=.*|pick_dir_img=$HOME|" "$cfg" || return 1
    sed -i "s|^recent_docs=true|recent_docs=false|" "$cfg" || return 1
    return 0
}

_c_trash() {
    _empty_dir "$HOME/.local/share/Trash/files" "$HOME/.local/share/Trash/info" \
        "$HOME/.local/share/Trash/expunged" || true
    _dir_clean "$HOME/.local/share/Trash/files" "$HOME/.local/share/Trash/info"
}

_c_service_logs() {
    _gm_sudo find /var/log/postgresql -maxdepth 1 -name '*.log' -type f -exec truncate -s 0 {} \; 2>/dev/null || true
    local f
    for f in /var/log/apache2/access.log /var/log/apache2/error.log \
             /var/log/apache2/other_vhosts_access.log \
             /var/log/nginx/access.log /var/log/nginx/error.log \
             /var/log/macchanger.log; do
        [[ -e "$f" ]] || continue
        _gm_sudo truncate -s 0 "$f" || true
    done
    return 0
}

_c_dconf() {
    dconf reset /org/gnome/portal/filechooser/org.gnome.Settings/last-folder-path 2>/dev/null || true
    dconf reset /org/gtk/settings/file-chooser/recent-files-max-age 2>/dev/null || true
    return 0
}

_c_locate() {
    _gm_sudo truncate -s 0 /var/lib/mlocate/mlocate.db 2>/dev/null || true
    _gm_sudo truncate -s 0 /var/lib/plocate/plocate.db 2>/dev/null || true
    _gm_sudo updatedb 2>/dev/null || true
    return 0
}

_c_crash() {
    _gm_sudo rm -rf -- /var/crash/* 2>/dev/null || true
    rm -rf -- "$HOME/.cache/apport" 2>/dev/null || true
    return 0
}

_c_chromium() {
    local base prof
    if _proc_running chrome chromium google-chrome brave brave-browser; then
        _GM_STEP_MSG="a Chromium-family browser is open, skipped its databases"
        return 2
    fi
    for base in "$HOME/.config/google-chrome" "$HOME/.config/chromium" "$HOME/.config/BraveSoftware/Brave-Browser"; do
        [[ -d "$base" ]] || continue
        for prof in "$base/Default" "$base"/Profile*; do
            [[ -d "$prof" ]] || continue
            rm -f -- "$prof/History" "$prof/History-journal" "$prof/Cookies" "$prof/Cookies-journal" \
                "$prof/Web Data" "$prof/Web Data-journal" "$prof/Login Data" "$prof/Login Data-journal" 2>/dev/null || true
            rm -rf -- "$prof/Sessions" "$prof/Session Storage" "$prof/Local Storage" "$prof/IndexedDB" 2>/dev/null || true
        done
        rm -rf -- "$base/Crash Reports" 2>/dev/null || true
    done
    return 0
}

_c_apt() {
    _gm_sudo truncate -s 0 /var/log/apt/history.log /var/log/apt/term.log 2>/dev/null || {
        _GM_STEP_MSG="could not empty apt logs"
        return 1
    }
    return 0
}

_c_user_journal() {
    rm -rf -- "$HOME/.local/state/journal" 2>/dev/null || true
    return 0
}

_c_dns() {
    _gm_sudo resolvectl flush-caches 2>/dev/null || true
    _gm_sudo systemd-resolve --flush-caches 2>/dev/null || true
    _gm_sudo ip neigh flush all 2>/dev/null || {
        _GM_STEP_MSG="could not flush the ARP cache"
        return 1
    }
    return 0
}

_c_pentest() {
    rm -rf -- "$HOME/.msf4/history" "$HOME/.msf4/logs" "$HOME/.msf4/loot" \
        "$HOME/.msf4/local" "$HOME/.msf4/store.db" 2>/dev/null || true
    rm -f -- "$HOME/.john/john.pot" "$HOME/.john/john.log" 2>/dev/null || true
    find "$HOME/.local/share/hashcat" "$HOME/.hashcat" -maxdepth 1 -name '*.potfile' -type f -delete 2>/dev/null || true
    rm -rf -- "$HOME/.local/share/hashcat/sessions" "$HOME/.hashcat/sessions" 2>/dev/null || true
    rm -rf -- "$HOME/.cme" "$HOME/.nxc" "$HOME/.evil-winrm" "$HOME/.local/share/sqlmap" "$HOME/.sqlmap" 2>/dev/null || true
    _gm_sudo rm -rf -- /usr/share/responder/logs/* 2>/dev/null || true
    rm -f -- "$HOME/.config/wireshark/recent" "$HOME/.config/wireshark/recent_common" 2>/dev/null || true
    rm -rf -- "$HOME/.BurpSuite" "$HOME/.java/.userPrefs/burp" 2>/dev/null || true
    return 0
}

_coding_agent_roots() {
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
    local data="${XDG_DATA_HOME:-$HOME/.local/share}"
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}"
    local state="${XDG_STATE_HOME:-$HOME/.local/state}"
    printf '%s\n' \
        "$HOME/.claude" \
        "$cfg/Claude" \
        "$cfg/claude" \
        "$cache/claude" \
        "$data/claude" \
        "$state/claude" \
        "$cfg/Antigravity" \
        "$cfg/Antigravity IDE" \
        "$cache/antigravity" \
        "$cache/antigravity-ide" \
        "$cache/antigravity-ide-backups" \
        "$HOME/.gemini/antigravity" \
        "$HOME/.gemini/antigravity-ide" \
        "$HOME/.gemini/antigravity-cli" \
        "$HOME/.gemini/antigravity-browser-profile" \
        "$HOME/.antigravity-ide" \
        "$data/antigravity" \
        "$state/antigravity" \
        "$cfg/opencode" \
        "$data/opencode" \
        "$state/opencode" \
        "$cache/opencode" \
        "$HOME/.opencode"
    local d
    shopt -s nullglob
    for d in "$HOME/.var/app/"*[Cc]laude* "$HOME/.var/app/"*[Aa]ntigravity* \
             "$HOME/.var/app/"*[Oo]pencod* \
             "$HOME/snap/"*claude*/common "$HOME/snap/"*opencode*/common \
             "$HOME/snap/"*antigravity*/common; do
        printf '%s\n' "$d"
    done
    shopt -u nullglob
}

_c_claude() {
    local d left=""
    while IFS= read -r d; do
        [[ -n "$d" ]] || continue
        rm -rf -- "$d" 2>/dev/null || true
        if [[ -e "$d" ]]; then
            left=1
        fi
    done < <(_coding_agent_roots)
    rm -f -- "$HOME/.claude.json" "$HOME/.claude.json.backup" 2>/dev/null || true
    [[ -e "$HOME/.claude.json" || -e "$HOME/.claude.json.backup" ]] && left=1
    if [[ -d /tmp/opencode && "$(stat -c '%u' /tmp/opencode 2>/dev/null || true)" == "$UID" ]]; then
        rm -rf -- /tmp/opencode 2>/dev/null || true
        [[ -e /tmp/opencode ]] && left=1
    fi
    if [[ -n "$left" ]]; then
        _GM_STEP_MSG="a Claude, Antigravity, or OpenCode path is still on disk"
        return 1
    fi
    return 0
}

_c_custom() {
    [[ -s "$GHOSTMODE_CUSTOM_PATHS_FILE" ]] || return 0
    local p
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        if [[ -d "$p" ]]; then
            find "$p" -mindepth 1 -delete 2>/dev/null || true
        elif [[ -f "$p" ]]; then
            : > "$p" 2>/dev/null || true
        fi
    done < "$GHOSTMODE_CUSTOM_PATHS_FILE"
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        if [[ -d "$p" && -n "$(find "$p" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
            _GM_STEP_MSG="custom path still has files"
            return 1
        fi
        if [[ -f "$p" && -s "$p" ]]; then
            _GM_STEP_MSG="custom path still has content"
            return 1
        fi
    done < "$GHOSTMODE_CUSTOM_PATHS_FILE"
    return 0
}

_run_clean() {
    _GM_STEP_FAILS=0
    _step "Clipboard" _c_clipboard
    _step "Shell history" _history_bump_and_wipe
    _step "App histories" _c_app_histories
    _step "Recently used" _c_recent
    _step "Thumbnails and cache" _c_cache
    _step "SQLite sidecars" _c_wal
    _step "Cursor" _cursor_clean
    _step "Zeitgeist and Tracker" _c_zeitgeist
    _step "Temp files" _c_tmp
    _step "var/tmp" _c_vartmp
    _step "Home folders" _c_home_dirs
    _step "Home scripts" _c_home_scripts
    _step "Journal" _c_journal
    _step "System logs" _c_syslogs
    _step "Device traces" _extra_traces
    _step "Swap" _c_swap
    _step "SSH keys" _c_ssh
    _step "VNC traces" _c_vnc
    _step "Remmina" _c_remmina
    _step "Firefox" _c_firefox
    _step "GNOME shell" _c_gnome
    _step "Text editor" _c_texteditor
    _step "CherryTree" _c_cherrytree
    _step "Trash" _c_trash
    _step "Service logs" _c_service_logs
    _step "Recent folders" _c_dconf
    _step "Locate database" _c_locate
    _step "Crash dumps" _c_crash
    _step "Chromium family" _c_chromium
    _step "Apt logs" _c_apt
    _step "User journal" _c_user_journal
    _step "DNS and ARP" _c_dns
    _step "Pentest tools" _c_pentest
    _step "Claude, Antigravity, OpenCode" _c_claude
    _step "Custom paths" _c_custom
    if _shield_tor_running; then
        _shield_audit || _GM_STEP_FAILS=$((_GM_STEP_FAILS + 1))
    fi
}

_clean_finish_message() {
    if [[ "${_GM_STEP_FAILS:-0}" -gt 0 ]]; then
        echo -e "  ${RED}${BLD}${_GM_STEP_FAILS} step(s) still show a trace or were refused.${RST}"
        echo -e "  ${GRY}Red means that layer is still there. This is not a complete wipe.${RST}"
    else
        echo -e "  ${GRN}${BLD}Finished the layers this tool can reach.${RST}"
        echo -e "  ${GRY}Not a 100% wipe. The router, ISP, cloud accounts, firmware, and SSD spare area are outside this tool.${RST}"
    fi
}

cmd_clean() {
    local auto="${1:-}"
    if [[ "$auto" == "auto" ]]; then
        GHOSTMODE_MODE=auto
    else
        GHOSTMODE_MODE=full
    fi
    if [[ "$auto" == "auto" && ! -t 1 ]]; then
        _run_clean >/dev/null
    else
        echo ""
        echo -e "${BLD}${BLU}╔══════════════════════════════════════════════════╗${RST}"
        echo -e "${BLD}${BLU}║                   CLEANING                     ║${RST}"
        echo -e "${BLD}${BLU}╚══════════════════════════════════════════════════╝${RST}"
        echo ""
        _run_clean
        echo ""
        _clean_finish_message
        echo ""
    fi
}

cmd_delete() {
    GHOSTMODE_MODE=delete
    echo ""
    echo -e "${BLD}${RED}╔══════════════════════════════════════════════════╗${RST}"
    echo -e "${BLD}${RED}║                 DELETE NOW                      ║${RST}"
    echo -e "${BLD}${RED}╚══════════════════════════════════════════════════╝${RST}"
    echo ""
    _run_clean
    echo ""
    _clean_finish_message
    echo ""
}
