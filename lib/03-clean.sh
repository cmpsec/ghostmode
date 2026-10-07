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
    _check_dir  ~/.local/share/gvfs-metadata  "gvfs-metadata"

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
    echo -e "${BLD}${CYN}[ Claude Code / Claude Desktop ]${RST}"
    _check_claude_traces
    _check_dir  ~/.claude/todos             "claude/todos"
    _check_dir  ~/.claude/shell-snapshots   "claude/shell-snap"
    _check_dir  ~/.claude/statsig           "claude/statsig"
    _check_dir  ~/.claude/ide               "claude/ide"
    _check_dir  ~/.config/Claude/logs       "Claude/logs"
    _check_dir  ~/.config/Claude/Cache      "Claude/Cache"
    _check_dir  ~/.config/Claude/CachedData "Claude/CachedData"
    _check_file ~/.config/Claude/Cookies    "Claude/Cookies"
    _check_dir  ~/.config/Claude/Backups    "Claude/Backups"
    _check_dir  ~/.config/Claude/GPUCache   "Claude/GPUCache"
    _check_dir  ~/.config/Claude/Crashpad   "Claude/Crashpad"

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
    local swap_used
    swap_used=$(free -h | awk '/^Swap:/ {print $3}')
    local padded
    padded=$(printf "%-22s" "swap usage")
    if [[ "$swap_used" == "0B" || "$swap_used" == "0" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${swap_used}${RST}"
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
        # نستخدم خاصية systemd الخام (NextElapseUSecRealtime) بدل تحليل أعمدة
        # list-timers النصية — تلك الأعمدة تنهار لو كان التشغيل الحالي لسه
        # شغّال (مثلًا تعويض Persistent=true بعد الإقلاع)، لأن NEXT يطلع
        # شرطة "-" وحيدة فتزيح كل الأعمدة اللي بعدها
        local next_val
        if [[ "$sctl" == "system" ]]; then
            next_val=$(systemctl show ghostmode-timer.timer -p NextElapseUSecRealtime --value 2>/dev/null)
        else
            next_val=$(systemctl --user show ghostmode-timer.timer -p NextElapseUSecRealtime --value 2>/dev/null)
        fi
        if [[ -n "$next_val" && "$next_val" != "0" && "$next_val" != "n/a" ]]; then
            local pd2
            pd2=$(printf "%-22s" "next trigger")
            echo -e "  ${GRN}◷${RST}  ${pd2} → ${YLW}${next_val}${RST}"
        else
            echo -e "  ${GRY}◷${RST}  $(printf "%-22s" "next trigger") → ${GRY}calculating (current run may still be in progress)${RST}"
        fi
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${RED}INACTIVE${RST}"
    fi
    local pd3
    pd3=$(printf "%-22s" "lingering (boot)")
    if loginctl show-user someone 2>/dev/null | grep -q "Linger=yes"; then
        echo -e "  ${GRN}✔${RST}  ${pd3} → ${GRN}enabled (survives reboot)${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${pd3} → ${RED}disabled${RST}"
    fi

    echo ""
    echo -e "${BLD}${BLU}══════════════════════════════════════════════════${RST}"
    echo ""
}

_clean_cursor_projects() {
    local proj_dir=~/.cursor/projects
    [[ ! -d "$proj_dir" ]] && return
    find "$proj_dir" -type d -name "agent-transcripts" 2>/dev/null | while read -r d; do
        rm -rf "${d:?}"/* 2>/dev/null
    done
    find "$proj_dir" -type d -name "terminals" 2>/dev/null | while read -r d; do
        rm -rf "${d:?}"/* 2>/dev/null
    done
    local active_tmp
    active_tmp=$(ls -td "$proj_dir"/tmp-*/ 2>/dev/null | head -1)
    active_tmp="${active_tmp%/}"
    for d in "$proj_dir"/*/; do
        [[ ! -d "$d" ]] && continue
        local abs="${d%/}"
        [[ -n "$active_tmp" && "$abs" == "$active_tmp" ]] && continue
        rm -rf "$abs" 2>/dev/null
    done
    find "$proj_dir" -maxdepth 1 -type f -delete 2>/dev/null
}

_clean_cursor_plans() {
    local plans_dir=~/.cursor/plans
    [[ ! -d "$plans_dir" ]] && return
    find "$plans_dir" -mindepth 1 -delete 2>/dev/null
}

_clean_cursor_ai() {
    local ai_dir=~/.cursor/ai-tracking
    [[ ! -d "$ai_dir" ]] && return
    if [[ -f "$ai_dir/ai-code-tracking.db" ]]; then
        rm -f "$ai_dir/ai-code-tracking.db" "$ai_dir/ai-code-tracking.db-wal" \
              "$ai_dir/ai-code-tracking.db-shm" 2>/dev/null
        [[ -f "$ai_dir/ai-code-tracking.db" ]] && \
            sqlite3 "$ai_dir/ai-code-tracking.db" \
            "DELETE FROM code_tracking; DELETE FROM sqlite_sequence; VACUUM;" 2>/dev/null
    fi
    find "$ai_dir" -maxdepth 1 -type f -not -name "ai-code-tracking.db" -delete 2>/dev/null
}

_run_clean() {
    _step "Clipboard (X11 + clipman)" \
        "echo -n '' | xclip -selection clipboard 2>/dev/null
         echo -n '' | xclip -selection primary 2>/dev/null
         rm -f ~/.cache/xfce4/clipman/textsrc 2>/dev/null
         touch ~/.cache/xfce4/clipman/textsrc 2>/dev/null; true"

    _step "Shell histories" \
        "cat /dev/null > ~/.zsh_history 2>/dev/null
         cat /dev/null > ~/.bash_history 2>/dev/null"

    _step "App histories" \
        "rm -f ~/.python_history ~/.node_repl_history ~/.mysql_history \
         ~/.psql_history ~/.pgpass ~/.pg_service.conf ~/.sqlite_history ~/.lesshst ~/.viminfo ~/.wget-hsts \
         ~/.bash_sessions_startup ~/.xsession-errors ~/.xsession-errors.old"

    _step "Recently used & gvfs" \
        "rm -f ~/.local/share/recently-used.xbel ~/.local/share/recently-used.xbel.* 2>/dev/null
         ln -sf /dev/null ~/.local/share/recently-used.xbel 2>/dev/null
         rm -rf ~/.local/share/gvfs-metadata/ 2>/dev/null"

    _step "Thumbnails & cache" \
        "rm -rf ~/.cache/thumbnails/* ~/.cache/thumbnails/ ~/.thumbnails/* ~/.thumbnails/ ~/.cache/sessions/ \
         ~/.cache/mozilla/ ~/.cache/chromium/ ~/.cache/google-chrome/ \
         ~/.cache/pip/ ~/.cache/claude/ 2>/dev/null"

    _step "SQLite WAL/SHM (user config)" \
        "find ~/.config ~/.local/share -maxdepth 4 \
         \( -name '*.db-wal' -o -name '*.db-shm' -o -name '*.sqlite-wal' -o -name '*.sqlite-shm' \) \
         -type f -delete 2>/dev/null; true"

    _step "Cursor IDE traces" \
        "_clean_trace_paths
         _clean_cursor_projects
         _clean_cursor_plans
         _clean_cursor_ai
         rm -rf ~/.config/Cursor/logs/ ~/.config/Cursor/Cache/ \
                ~/.config/Cursor/CachedData/ ~/.config/Cursor/GPUCache/ \
                ~/.config/Cursor/DawnGraphiteCache/ ~/.config/Cursor/DawnWebGPUCache/ \
                ~/.config/Cursor/Crashpad/ ~/.config/Cursor/Backups/ 2>/dev/null
         rm -rf ~/.config/Cursor/User/History/* 2>/dev/null
         rm -f  ~/.config/Cursor/Cookies ~/.config/Cursor/Cookies-journal \
                ~/.config/Cursor/DIPS ~/.config/Cursor/DIPS-wal 2>/dev/null"

    _step "Zeitgeist & Tracker" \
        "rm -rf ~/.local/share/zeitgeist/ ~/.local/share/tracker/ 2>/dev/null
         tracker3 reset -s -r 2>/dev/null
         tracker reset --hard 2>/dev/null"

    _step "/tmp (user files only)" \
        "find /tmp -maxdepth 1 \
         -not -name 'tmp' \
         -not -name 'systemd-private*' \
         -not -name 'snap-private-tmp' \
         -not -name '.X*' \
         -not -name '.ICE*' \
         -not -name '.font-unix' \
         -not -name '.org.chromium.*' \
         -not -name '.mount_cursor*' \
         \( -type f -o -type d \) \
         \( -type f -delete -o -type d -exec rm -rf {} + \) \
         2>/dev/null
         for _sock in /tmp/*.sock /tmp/*.socket; do
           [[ -S \"\$_sock\" ]] || continue
           ss -x 2>/dev/null | grep -q \"\$_sock\" || rm -f \"\$_sock\" 2>/dev/null
         done; true"

    _step "/var/tmp (user files only)" \
        "find /var/tmp -maxdepth 1 \
         -not -name 'tmp' \
         -not -name 'systemd-private*' \
         -delete 2>/dev/null; true"

    _step "Home dirs (Downloads/Docs/Music/Videos/Pics)" \
        "rm -rf ~/Downloads/* ~/Downloads/.* \
                ~/Music/* ~/Music/.* \
                ~/Videos/* ~/Videos/.* \
                ~/Pictures/* ~/Pictures/.* \
                ~/Documents/* ~/Documents/.* \
                ~/Desktop/* ~/Desktop/.* \
                ~/Templates/* ~/Public/* 2>/dev/null; true"

    _step "Home scripts (*.sh/.py/.pl/.rb)" \
        "find \$HOME -maxdepth 1 -type f \
         \( -name '*.sh' -o -name '*.py' -o -name '*.pl' \
            -o -name '*.rb' -o -name '*.bash' -o -name '*.zsh' \) \
         -not -name '.*' -delete 2>/dev/null; true"

    _step "Journal logs" \
        "echo CHANGEME_PASSWORD | sudo -S journalctl --rotate -q 2>/dev/null
         echo CHANGEME_PASSWORD | sudo -S journalctl --vacuum-time=1s -q 2>/dev/null
         echo CHANGEME_PASSWORD | sudo -S find /var/log/journal -type f \
           \( -name '*.journal' -o -name '*.journal~' \) -delete 2>/dev/null
         echo CHANGEME_PASSWORD | sudo -S systemctl kill --kill-who=main \
           -s USR2 systemd-journald 2>/dev/null
         sleep 0.3; true"

    _step "System logs" \
        "echo CHANGEME_PASSWORD | sudo -S truncate -s 0 \
         /var/log/auth.log /var/log/syslog /var/log/kern.log \
         /var/log/wtmp /var/log/btmp /var/log/lastlog \
         /var/log/dpkg.log /var/log/faillog 2>/dev/null"

    _step "Flush swap" \
        "echo CHANGEME_PASSWORD | sudo -S swapoff -a 2>/dev/null
         echo CHANGEME_PASSWORD | sudo -S swapon -a 2>/dev/null"

    _step "SSH keys & known_hosts" \
        "rm -f ~/.ssh/id_* ~/.ssh/*.pem ~/.ssh/*.key \
               ~/.ssh/known_hosts ~/.ssh/known_hosts.old \
               ~/.ssh/authorized_keys ~/.ssh/config 2>/dev/null
         mkdir -p ~/.ssh && touch ~/.ssh/known_hosts
         chmod 700 ~/.ssh && chmod 600 ~/.ssh/known_hosts"

    _step "VNC/TightVNC traces" \
        "if [[ -d \$HOME/.vnc ]]; then
           find \$HOME/.vnc -maxdepth 2 \
             \( -name '*.log' -o -name '*.pid' -o -name 'xstartup' \
                -o -name 'passwd' -o -name 'vncpasswd' \) \
             -type f -delete 2>/dev/null
         fi
         find \$HOME -maxdepth 3 \
           \( -name '*.vnc' -o -name 'vncpasswd' \) \
           -type f -delete 2>/dev/null
         find \$HOME /tmp -maxdepth 2 \
           \( -name '.x11vncpass' -o -name 'x11vncpass' -o -name 'vp' \) \
           -type f -delete 2>/dev/null
         rm -rf \$HOME/.config/tigervnc 2>/dev/null
         rm -f \$HOME/setup_vnc.py 2>/dev/null
         rm -f \$HOME/.ssh/known_hosts.old \$HOME/.ssh/known_hosts.bak 2>/dev/null
         true"

    _step "Remmina/RDP sessions" \
        "rm -rf ~/.local/share/remmina/ ~/.remmina/ 2>/dev/null; true"

    _step "SSH cmds from history" \
        "for hf in ~/.zsh_history ~/.bash_history; do
           [[ -f \"\$hf\" ]] || continue
           local _ght
           _ght=\$(mktemp) 2>/dev/null
           grep -v 'ssh\|scp\|sshpass\|expect\|@[0-9]' \"\$hf\" \
             > \"\$_ght\" 2>/dev/null \
             && mv \"\$_ght\" \"\$hf\" \
             || { cat /dev/null > \"\$hf\"; rm -f \"\$_ght\"; }
         done; true"

    _step "Firefox ESR (history/cookies/sessions/cache)" \
        "local ff_profile
         ff_profile=\$(find ~/.mozilla/firefox -maxdepth 1 -type d \
             \( -name '*.default-esr' -o -name '*.default' \) 2>/dev/null | head -1)
         if [[ -n \"\$ff_profile\" ]]; then
             for db in places.sqlite cookies.sqlite formhistory.sqlite \
                       webappstore.sqlite content-prefs.sqlite \
                       favicons.sqlite storage.sqlite; do
                 rm -f \"\$ff_profile/\$db\" \"\$ff_profile/\$db-wal\" \
                        \"\$ff_profile/\$db-shm\" 2>/dev/null
             done
             rm -f \"\$ff_profile/sessionstore.jsonlz4\" \
                    \"\$ff_profile/sessionstore-backups\"/*.jsonlz4 \
                    \"\$ff_profile/downloads.sqlite\" 2>/dev/null
             rm -rf \"\$ff_profile/cache2/\" \"\$ff_profile/startupCache/\" 2>/dev/null
             rm -rf ~/.cache/firefox/ ~/.cache/mozilla/ 2>/dev/null
         fi; true"

    _step "GNOME shell app state & session history" \
        "rm -f ~/.local/share/gnome-shell/application_state \
               ~/.local/share/gnome-shell/session-active-history.json \
               ~/.local/share/gnome-shell/session.gvdb 2>/dev/null; true"

    _step "TextEditor recent & session" \
        "rm -f ~/.local/share/org.gnome.TextEditor/recently-used.xbel \
               ~/.local/share/org.gnome.TextEditor/session.gvariant 2>/dev/null
         rm -rf ~/.local/share/org.gnome.TextEditor/drafts/ 2>/dev/null; true"

    _step "cherrytree recent dirs" \
        "if [[ -f ~/.config/cherrytree/config.cfg ]]; then
             sed -i 's|^pick_dir_file=.*|pick_dir_file=/home/someone|' \
                 ~/.config/cherrytree/config.cfg 2>/dev/null
             sed -i 's|^pick_dir_export=.*|pick_dir_export=/home/someone|' \
                 ~/.config/cherrytree/config.cfg 2>/dev/null
             sed -i 's|^pick_dir_import=.*|pick_dir_import=/home/someone|' \
                 ~/.config/cherrytree/config.cfg 2>/dev/null
             sed -i 's|^pick_dir_img=.*|pick_dir_img=/home/someone|' \
                 ~/.config/cherrytree/config.cfg 2>/dev/null
             sed -i 's|^recent_docs=true|recent_docs=false|' \
                 ~/.config/cherrytree/config.cfg 2>/dev/null
         fi; true"

    _step "Trash (empty)" \
        "rm -rf ~/.local/share/Trash/files/* \
               ~/.local/share/Trash/info/* \
               ~/.local/share/Trash/expunged/* 2>/dev/null; true"

    _step "Service logs (postgres/apache/nginx/macchanger)" \
        "echo CHANGEME_PASSWORD | sudo -S find /var/log/postgresql -maxdepth 1 -name '*.log' -type f -exec truncate -s 0 {} \\; 2>/dev/null
         echo CHANGEME_PASSWORD | sudo -S truncate -s 0 \
             /var/log/apache2/access.log \
             /var/log/apache2/error.log \
             /var/log/apache2/other_vhosts_access.log \
             /var/log/nginx/access.log \
             /var/log/nginx/error.log \
             /var/log/macchanger.log 2>/dev/null; true"

    _step "dconf recent-folder reset" \
        "dconf reset /org/gnome/portal/filechooser/org.gnome.Settings/last-folder-path 2>/dev/null
         dconf reset /org/gtk/settings/file-chooser/recent-files-max-age 2>/dev/null; true"

    _step "locate database (mlocate/plocate)" \
        "echo CHANGEME_PASSWORD | sudo -S truncate -s 0 /var/lib/mlocate/mlocate.db 2>/dev/null
         echo CHANGEME_PASSWORD | sudo -S truncate -s 0 /var/lib/plocate/plocate.db 2>/dev/null
         echo CHANGEME_PASSWORD | sudo -S updatedb 2>/dev/null; true"

    _step "Crash dumps (apport)" \
        "echo CHANGEME_PASSWORD | sudo -S rm -rf /var/crash/* 2>/dev/null
         rm -rf ~/.cache/apport/* 2>/dev/null; true"

    _step "Chrome/Chromium/Brave (history/cookies/logins)" \
        "for base in ~/.config/google-chrome ~/.config/chromium ~/.config/BraveSoftware/Brave-Browser; do
           [[ -d \"\$base\" ]] || continue
           for prof in \"\$base\"/Default \"\$base\"/Profile*; do
             [[ -d \"\$prof\" ]] || continue
             rm -f \"\$prof\"/History \"\$prof\"/History-journal \"\$prof\"/Cookies \"\$prof\"/Cookies-journal \
                    \"\$prof/Web Data\" \"\$prof/Web Data-journal\" \"\$prof/Login Data\" \"\$prof/Login Data-journal\" 2>/dev/null
             rm -rf \"\$prof/Sessions\" \"\$prof/Session Storage\" \"\$prof/Local Storage\" \"\$prof/IndexedDB\" 2>/dev/null
           done
           rm -rf \"\$base/Crash Reports\" 2>/dev/null
         done; true"

    _step "apt/dpkg extra logs" \
        "echo CHANGEME_PASSWORD | sudo -S truncate -s 0 /var/log/apt/history.log /var/log/apt/term.log 2>/dev/null; true"

    _step "User systemd journal" \
        "rm -rf ~/.local/state/journal/* 2>/dev/null; true"

    _step "DNS & ARP cache" \
        "echo CHANGEME_PASSWORD | sudo -S resolvectl flush-caches 2>/dev/null
         echo CHANGEME_PASSWORD | sudo -S systemd-resolve --flush-caches 2>/dev/null
         echo CHANGEME_PASSWORD | sudo -S ip neigh flush all 2>/dev/null; true"

    _step "Metasploit (~/.msf4)" \
        "rm -rf ~/.msf4/history ~/.msf4/logs ~/.msf4/loot \
                ~/.msf4/local ~/.msf4/store.db 2>/dev/null; true"

    _step "Cracking potfiles (john/hashcat)" \
        "rm -f ~/.john/john.pot ~/.john/john.log 2>/dev/null
         find ~/.local/share/hashcat ~/.hashcat -maxdepth 1 \
             -name '*.potfile' -type f -delete 2>/dev/null
         rm -rf ~/.local/share/hashcat/sessions ~/.hashcat/sessions 2>/dev/null; true"

    _step "CrackMapExec/NetExec loot" \
        "rm -rf ~/.cme ~/.nxc 2>/dev/null; true"

    _step "Responder logs" \
        "echo CHANGEME_PASSWORD | sudo -S rm -rf /usr/share/responder/logs/* 2>/dev/null; true"

    _step "evil-winrm history" \
        "rm -rf ~/.evil-winrm 2>/dev/null; true"

    _step "SQLMap output" \
        "rm -rf ~/.local/share/sqlmap ~/.sqlmap 2>/dev/null; true"

    _step "Wireshark recent/profiles" \
        "rm -f ~/.config/wireshark/recent ~/.config/wireshark/recent_common 2>/dev/null; true"

    _step "Burp Suite data" \
        "rm -rf ~/.BurpSuite ~/.java/.userPrefs/burp 2>/dev/null; true"

    _step "Claude Code (transcripts/session)" \
        "rm -rf ~/.claude/projects ~/.claude/todos \
                ~/.claude/shell-snapshots ~/.claude/statsig 2>/dev/null
         rm -f ~/.claude.json ~/.claude.json.backup 2>/dev/null; true"

    _step "Custom paths" \
        "if [[ -s \"\$GHOSTMODE_CUSTOM_PATHS_FILE\" ]]; then
             while IFS= read -r p; do
                 [[ -z \"\$p\" ]] && continue
                 if [[ -d \"\$p\" ]]; then
                     find \"\$p\" -mindepth 1 -delete 2>/dev/null
                 elif [[ -f \"\$p\" ]]; then
                     : > \"\$p\" 2>/dev/null
                 fi
             done < \"\$GHOSTMODE_CUSTOM_PATHS_FILE\"
         fi; true"

    _step "zsh autosuggestions (disable command history suggestions)" \
        "for f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
                  /usr/share/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh; do
             [[ -f \"\$f\" ]] && echo CHANGEME_PASSWORD | sudo -S mv \"\$f\" \"\${f}.ghostmode-disabled\" 2>/dev/null
         done; true"

    _step "Claude Desktop app data" \
        "rm -rf ~/.config/Claude/Cache ~/.config/Claude/CachedData \
                ~/.config/Claude/GPUCache ~/.config/Claude/Crashpad \
                ~/.config/Claude/Backups ~/.config/Claude/logs 2>/dev/null
         rm -rf ~/.config/Claude/User/History/* 2>/dev/null
         rm -f ~/.config/Claude/Cookies ~/.config/Claude/Cookies-journal 2>/dev/null; true"
}

_step() {
    local label="$1" cmd="$2"
    eval "$cmd"
    local padded
    padded=$(printf "%-45s" "$label")
    echo -e "  ${GRN}✔${RST}  ${padded} ${GRN}cleared${RST}"
    # Small pause between each step — prevents any run (especially the missed-run
    # catch-up after boot) from hitting the CPU/disk as one heavy burst
    sleep 0.4
}

cmd_clean() {
    local auto="${1:-}"
    if [[ "$auto" == "auto" ]]; then
        # No progress output here on purpose — StandardOutput for this unit
        # is set to null, so printing anything would just accumulate in
        # systemd's own journal, which is exactly the kind of log of the
        # project's own operations this tool is meant to avoid leaving.
        _run_clean >/dev/null 2>&1
    else
        echo ""
        echo -e "${BLD}${BLU}╔══════════════════════════════════════════════════╗${RST}"
        echo -e "${BLD}${BLU}║                   CLEANING                     ║${RST}"
        echo -e "${BLD}${BLU}╚══════════════════════════════════════════════════╝${RST}"
        echo ""
        _run_clean
        echo ""
        echo -e "  ${GRN}${BLD}[+] All tracks cleared.${RST}"
        echo ""
    fi
}

cmd_delete() {
    echo ""
    echo -e "${BLD}${RED}╔══════════════════════════════════════════════════╗${RST}"
    echo -e "${BLD}${RED}║                 DELETE NOW                      ║${RST}"
    echo -e "${BLD}${RED}╚══════════════════════════════════════════════════╝${RST}"
    echo ""
    _run_clean
    echo ""
    echo -e "  ${RED}${BLD}[✘] Delete complete. Everything wiped.${RST}"
    echo ""
}

