#!/usr/bin/env bash
# shellcheck shell=bash
# Extra trace layers. Missing paths are clean. A live owner is a yellow skip.

_extra_worst=0
_extra_notes=""

_extra_bump() {
    local rc="$1" note="$2"
    if [[ "$rc" -gt "$_extra_worst" ]]; then
        _extra_worst=$rc
    fi
    if [[ -n "$note" ]]; then
        _extra_notes="${_extra_notes}${note}; "
    fi
}

_truncate_if_present() {
    local f
    for f in "$@"; do
        [[ -e "$f" ]] || continue
        if [[ -d "$f" ]]; then
            find "$f" -type f -exec truncate -s 0 {} + 2>/dev/null \
                || _gm_sudo find "$f" -type f -exec truncate -s 0 {} + 2>/dev/null \
                || return 1
        else
            : > "$f" 2>/dev/null || _gm_sudo truncate -s 0 "$f" || return 1
        fi
    done
    return 0
}

_dir_has_entries() {
    [[ -d "$1" ]] && [[ -n "$(find "$1" -mindepth 1 -print -quit 2>/dev/null)" ]]
}

_proc_running() {
    local name
    for name in "$@"; do
        pgrep -u "$UID" -x "$name" >/dev/null 2>&1 && return 0
    done
    return 1
}

_clean_browser_base() {
    local base="$1"
    shift
    [[ -d "$base" ]] || return 0
    local globbing=0
    shopt -q nullglob && globbing=1
    shopt -s nullglob
    if _proc_running "$@"; then
        [[ "$globbing" -eq 0 ]] && shopt -u nullglob
        _extra_bump 2 "skipped open browser profile ${base/#$HOME/\~}"
        return 0
    fi
    local prof
    for prof in "$base/Default" "$base"/Profile*; do
        [[ -d "$prof" ]] || continue
        rm -f -- "$prof/History" "$prof/History-journal" "$prof/Cookies" "$prof/Cookies-journal" \
            "$prof/Web Data" "$prof/Web Data-journal" "$prof/Login Data" "$prof/Login Data-journal" 2>/dev/null || true
        rm -rf -- "$prof/Sessions" "$prof/Session Storage" "$prof/Local Storage" "$prof/IndexedDB" "$prof/Cache" "$prof/Code Cache" 2>/dev/null || true
    done
    rm -rf -- "$base/Crash Reports" 2>/dev/null || true
    [[ "$globbing" -eq 0 ]] && shopt -u nullglob
}

_clean_git_traces() {
    local f
    for f in "$HOME/.git-credentials" "$HOME/.config/git/credentials" "$HOME/.config/gh/hosts.yml"; do
        rm -f -- "$f" 2>/dev/null || true
    done
    if [[ -d "$HOME/.cache/gh" ]]; then
        find "$HOME/.cache/gh" -mindepth 1 -delete 2>/dev/null || true
    fi
    if [[ -f "$HOME/.gitconfig" ]]; then
        sed -i -E '/ghp_|github_pat_|gho_|glpat-|token/d' "$HOME/.gitconfig" 2>/dev/null || true
    fi
    git config --global --unset-all credential.helper >/dev/null 2>&1 || true
    git credential-cache exit >/dev/null 2>&1 || true
    local host
    for host in github.com gitlab.com bitbucket.org; do
        printf 'protocol=https\nhost=%s\n\n' "$host" | git credential reject >/dev/null 2>&1 || true
    done
    for f in "$HOME/.git-credentials" "$HOME/.config/git/credentials" "$HOME/.config/gh/hosts.yml"; do
        if [[ -s "$f" ]]; then
            _extra_bump 1 "git credential file remains: ${f/#$HOME/\~}"
            return 0
        fi
    done
}

_clean_login_logs() {
    local logs=(/var/log/wtmp /var/log/btmp /var/log/lastlog /var/log/faillog)
    local f
    for f in "${logs[@]}"; do
        [[ -e "$f" ]] || continue
        _gm_sudo truncate -s 0 "$f" || _extra_bump 1 "could not empty $f"
    done
}

_clean_audit_logs() {
    [[ -d /var/log/audit ]] || return 0
    if [[ "$GHOSTMODE_MODE" != "auto" ]]; then
        _gm_sudo systemctl stop auditd 2>/dev/null || true
    fi
    if ! _gm_sudo find /var/log/audit -type f -exec truncate -s 0 {} + 2>/dev/null; then
        _extra_bump 1 "could not empty audit logs"
        return 0
    fi
    if systemctl is-active --quiet auditd 2>/dev/null; then
        local left
        left=$(find /var/log/audit -type f -size +0c 2>/dev/null | head -n 1)
        if [[ -n "$left" ]]; then
            _extra_bump 2 "auditd is running and rewrote a log"
        fi
    fi
}

_clean_networkmanager_traces() {
    [[ -d /var/lib/NetworkManager ]] || return 0
    _gm_sudo find /var/lib/NetworkManager -maxdepth 1 -type f \
        \( -name '*.lease' -o -name 'timestamps' -o -name 'seen-bssids' \) \
        -exec truncate -s 0 {} + 2>/dev/null || _extra_bump 2 "could not empty NetworkManager leases"
    [[ "$GHOSTMODE_MODE" != "delete" ]] && return 0
    command -v nmcli >/dev/null 2>&1 || return 0
    local active
    active=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | head -1 | cut -d: -f1)
    local uuid name
    while IFS=: read -r name uuid; do
        [[ -z "$uuid" ]] && continue
        [[ -n "$active" && "$name" == "$active" ]] && continue
        _gm_sudo nmcli connection delete uuid "$uuid" >/dev/null 2>&1 || true
    done < <(nmcli -t -f NAME,UUID connection show 2>/dev/null)
    if [[ -n "$active" ]]; then
        _extra_bump 0 "kept the active connection: ${active}"
    fi
}

_bluetooth_connected() {
    command -v bluetoothctl >/dev/null 2>&1 || return 1
    bluetoothctl devices Connected 2>/dev/null | grep -q .
}

_clean_bluetooth() {
    [[ -d /var/lib/bluetooth ]] || return 0
    if [[ "$GHOSTMODE_MODE" == "auto" ]] && _bluetooth_connected; then
        _extra_bump 2 "Bluetooth device is connected, skipped pairing cache"
        return 0
    fi
    _gm_sudo find /var/lib/bluetooth -mindepth 1 -delete 2>/dev/null \
        || _extra_bump 1 "could not clear Bluetooth cache"
}

_clean_named_subdirs() {
    local root="$1"
    shift
    [[ -d "$root" ]] || return 0
    local name path
    for name in "$@"; do
        path="$root/$name"
        if [[ -d "$path" ]]; then
            find "$path" -mindepth 1 -delete 2>/dev/null || true
        elif [[ -f "$path" ]]; then
            : > "$path" 2>/dev/null || rm -f -- "$path" 2>/dev/null || true
        fi
    done
}

_clean_messengers() {
    _clean_named_subdirs "$HOME/.local/share/TelegramDesktop" cache logs media_cache Cache
    _clean_named_subdirs "$HOME/.config/Element" Cache logs media_cache "Code Cache"
    _clean_named_subdirs "$HOME/.config/discord" Cache logs "Code Cache" GPUCache
    _clean_named_subdirs "$HOME/.config/Signal" logs Cache "Code Cache"
}

_clean_thunderbird() {
    local prof
    [[ -d "$HOME/.thunderbird" ]] || return 0
    while IFS= read -r prof; do
        rm -rf -- "$prof/cache2" "$prof/startupCache" 2>/dev/null || true
        rm -f -- "$prof/session.json" 2>/dev/null || true
    done < <(find "$HOME/.thunderbird" -mindepth 1 -maxdepth 2 -type d -name '*.default*' 2>/dev/null)
}

_clean_docker_logs() {
    [[ -d /var/lib/docker/containers ]] || return 0
    if ! _gm_sudo find /var/lib/docker/containers -name '*-json.log' -type f -exec truncate -s 0 {} + 2>/dev/null; then
        _extra_bump 2 "no permission to empty Docker container logs"
    fi
}

_clean_editor_scratch() {
    rm -rf -- "$HOME/.local/share/nano" 2>/dev/null || true
    find "$HOME" -maxdepth 3 -type f \
        \( -name '*.swp' -o -name '*~' -o -name '.*.swo' -o -name '*.swo' \) \
        -not -path "$HOME/.config/ghostmode/*" \
        -not -path "$HOME/.local/share/ghostmode/*" \
        -delete 2>/dev/null || true
}

_clean_terminal_histories() {
    local d f
    for d in "$HOME/.config/qterminal.org" "$HOME/.config/xfce4/terminal" \
             "$HOME/.local/share/konsole" "$HOME/.config/tilix" "$HOME/.local/share/kitty"; do
        [[ -d "$d" ]] || continue
        find "$d" -type f \( -iname '*history*' -o -iname '*scrollback*' -o -iname '*session*' \) \
            -delete 2>/dev/null || true
    done
}

_clean_libreoffice() {
    [[ -d "$HOME/.config/libreoffice" ]] || return 0
    find "$HOME/.config/libreoffice" -type d \( -name backup -o -name sessions \) \
        -exec find {} -mindepth 1 -delete \; 2>/dev/null || true
    local xcu
    xcu=$(find "$HOME/.config/libreoffice" -name 'registrymodifications.xcu' -type f 2>/dev/null | head -n 1)
    if [[ -n "$xcu" ]] && grep -q 'History' "$xcu" 2>/dev/null; then
        _extra_bump 2 "LibreOffice recent-file list inside settings was left in place"
    fi
}

_clean_document_readers() {
    rm -rf -- "$HOME/.local/share/okular/docdata" 2>/dev/null || true
    rm -rf -- "$HOME/.local/share/atril" 2>/dev/null || true
    _clean_named_subdirs "$HOME/.local/share/vlc" 
    if [[ -d "$HOME/.local/share/vlc" ]]; then
        find "$HOME/.local/share/vlc" -mindepth 1 -delete 2>/dev/null || true
    fi
    rm -rf -- "$HOME/.config/transmission/resume" "$HOME/.config/transmission/dht.dat" 2>/dev/null || true
    rm -f -- "$HOME/.config/transmission/stats.json" 2>/dev/null || true
    rm -rf -- "$HOME/.config/deluge/state" 2>/dev/null || true
    local d
    for d in "$HOME/.config/flameshot" "$HOME/.config/spectacle" "$HOME/.local/share/spectacle"; do
        [[ -d "$d" ]] || continue
        find "$d" -type f \( -iname '*history*' -o -iname '*recent*' \) -delete 2>/dev/null || true
    done
}

_clean_torbrowser_profile() {
    if pgrep -u "$UID" -f 'tor-browser' >/dev/null 2>&1 || pgrep -u torbrowser >/dev/null 2>&1; then
        _extra_bump 2 "Tor Browser is open, skipped its profile"
        return 0
    fi
    [[ "$GHOSTMODE_MODE" == "auto" ]] && return 0
    local root
    for root in "$HOME/.local/share/torbrowser" /home/torbrowser "$HOME/tor-browser"; do
        [[ -d "$root" ]] || continue
        find "$root" -type d \( -name cache2 -o -name startupCache \) -exec rm -rf {} + 2>/dev/null || true
        find "$root" -type f -name 'sessionstore*.jsonlz4' -delete 2>/dev/null || true
    done
}

_clean_memory_files() {
    find /dev/shm -mindepth 1 -maxdepth 2 -user "$USER" -type f -delete 2>/dev/null || true
    local runtime="/run/user/${UID}"
    [[ -d "$runtime" ]] || return 0
    local f
    while IFS= read -r f; do
        case "$f" in
            "$runtime"/systemd/* | "$runtime"/pulse/* | "$runtime"/pipewire* | \
            "$runtime"/bus | "$runtime"/bus/* | "$runtime"/wayland-* | \
            "$runtime"/dconf/* | "$runtime"/gnupg/* | "$runtime"/keyring/*)
                continue
                ;;
        esac
        if [[ -S "$f" ]]; then
            continue
        fi
        rm -f -- "$f" 2>/dev/null || _extra_bump 2 "left live file $(basename "$f")"
    done < <(find "$runtime" -mindepth 1 -type f 2>/dev/null)
}

_clean_clipboard_managers() {
    local running=0
    _proc_running copyq klipper parcellite gpaste && running=1
    rm -f -- "$HOME/.config/copyq/copyq.db" "$HOME/.local/share/klipper/history2.lst" \
        "$HOME/.local/share/parcellite/history" 2>/dev/null || true
    if [[ -d "$HOME/.local/share/gpaste" ]]; then
        find "$HOME/.local/share/gpaste" -mindepth 1 -delete 2>/dev/null || true
    fi
    if [[ "$running" -eq 1 ]]; then
        _extra_bump 2 "a clipboard manager is open; its memory stays until you close it"
    fi
}

_clean_hibernate_image() {
    [[ "$GHOSTMODE_MODE" == "auto" ]] && return 0
    if [[ -d /var/lib/systemd/pstore ]]; then
        _gm_sudo find /var/lib/systemd/pstore -type f -delete 2>/dev/null || true
    fi
}

_clean_flatpak_snap() {
    if [[ -d "$HOME/.var/app" ]]; then
        find "$HOME/.var/app" -mindepth 2 -maxdepth 2 -type d -name cache \
            -exec find {} -mindepth 1 -delete \; 2>/dev/null || true
    fi
    if [[ -d "$HOME/snap" ]]; then
        find "$HOME/snap" -path '*/common/.cache' -type d \
            -exec find {} -mindepth 1 -delete \; 2>/dev/null || true
    fi
}

_clean_vm_logs() {
    rm -rf -- "$HOME/.config/VirtualBox/Logs" 2>/dev/null || true
    _gm_sudo find /var/log/libvirt -type f -exec truncate -s 0 {} + 2>/dev/null || true
}

_clean_adb_logs() {
    [[ -d "$HOME/.android" ]] || return 0
    find "$HOME/.android" -type f \
        ! -name 'adbkey' ! -name 'adbkey.pub' \
        \( -name '*.log' -o -name 'adb.5037' -o -name '*.txt' \) \
        -delete 2>/dev/null || true
}

_clean_pkg_caches() {
    rm -rf -- "$HOME/.npm/_logs" "$HOME/.cache/pip" 2>/dev/null || true
    rm -f -- "$HOME/.wget-hsts" 2>/dev/null || true
}

_clean_system_logs_extra() {
    local f
    for f in /var/log/daemon.log /var/log/debug /var/log/messages /var/log/user.log \
             /var/log/alternatives.log /var/log/unattended-upgrades/unattended-upgrades.log \
             /var/log/wpa_supplicant.log /var/log/iwd.log; do
        [[ -f "$f" ]] || continue
        _gm_sudo truncate -s 0 "$f" || _extra_bump 2 "could not empty $f"
    done
    if [[ -d /var/log/fwupd ]]; then
        _gm_sudo find /var/log/fwupd -type f -exec truncate -s 0 {} + 2>/dev/null || true
    fi
    if [[ -d /var/log/cups ]]; then
        _gm_sudo find /var/log/cups -type f -exec truncate -s 0 {} + 2>/dev/null || true
    fi
    if [[ -d "$HOME/.cups" ]]; then
        find "$HOME/.cups" -type f -delete 2>/dev/null || true
    fi
    if [[ -d /var/log/sysstat ]]; then
        if ! _gm_sudo find /var/log/sysstat -type f -exec truncate -s 0 {} + 2>/dev/null; then
            _extra_bump 2 "sysstat files could not be emptied"
        elif systemctl is-active --quiet sysstat 2>/dev/null; then
            _extra_bump 2 "sysstat service is running"
        fi
    fi
    if [[ -f /var/account/pacct ]]; then
        _gm_sudo truncate -s 0 /var/account/pacct 2>/dev/null || true
    fi
    if [[ -d /var/log/atop ]]; then
        _gm_sudo find /var/log/atop -type f -exec truncate -s 0 {} + 2>/dev/null || true
    fi
    if [[ -d /var/lib/systemd/coredump ]]; then
        _gm_sudo find /var/lib/systemd/coredump -type f -delete 2>/dev/null \
            || _extra_bump 2 "could not remove coredumps"
    fi
}

_extra_traces() {
    _extra_worst=0
    _extra_notes=""
    _clean_login_logs
    _clean_audit_logs
    _clean_networkmanager_traces
    _clean_bluetooth
    _clean_system_logs_extra
    _clean_terminal_histories
    _clean_editor_scratch
    _clean_libreoffice
    _clean_document_readers
    _clean_messengers
    _clean_thunderbird
    _clean_docker_logs
    _clean_git_traces
    _clean_pkg_caches
    _clean_browser_base "$HOME/.config/vivaldi" vivaldi vivaldi-bin
    _clean_browser_base "$HOME/.config/microsoft-edge" microsoft-edge msedge
    _clean_browser_base "$HOME/.config/opera" opera
    _clean_browser_base "$HOME/.librewolf" librewolf
    _clean_browser_base "$HOME/.config/librewolf" librewolf
    _clean_torbrowser_profile
    _clean_flatpak_snap
    _clean_vm_logs
    _clean_adb_logs
    _clean_clipboard_managers
    _clean_memory_files
    _clean_hibernate_image
    _GM_STEP_MSG="${_extra_notes% }"
    return "$_extra_worst"
}

_check_git_credentials() {
    local padded f found=0
    padded=$(printf "%-22s" "git credentials")
    for f in "$HOME/.git-credentials" "$HOME/.config/git/credentials" "$HOME/.config/gh/hosts.yml"; do
        if [[ -s "$f" ]]; then
            found=1
            echo -e "  ${RED}✘${RST}  $(printf "%-22s" "${f/#$HOME/\~}") → ${YLW}present${RST}"
        fi
    done
    if [[ "$found" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not stored locally${RST}"
    fi
}

_check_disk_encryption() {
    local padded src typ
    padded=$(printf "%-22s" "disk encryption")
    if ! command -v lsblk >/dev/null 2>&1 || ! command -v findmnt >/dev/null 2>&1; then
        echo -e "  ${YLW}!${RST}  ${padded} → ${YLW}could not check${RST}"
        return
    fi
    local mnt encrypted=0
    for mnt in / /home; do
        src=$(findmnt -n -o SOURCE "$mnt" 2>/dev/null) || continue
        [[ -z "$src" ]] && continue
        typ=$(lsblk -sno TYPE "$src" 2>/dev/null)
        if printf '%s\n' "$typ" | grep -qx crypt; then
            encrypted=1
        fi
    done
    if [[ "$encrypted" -eq 1 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}root or home is on a crypt device${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}root and home are not encrypted; physical access bypasses the rest${RST}"
    fi
}

_check_screen_lock() {
    local padded locked=0
    padded=$(printf "%-22s" "screen lock")
    if command -v gsettings >/dev/null 2>&1; then
        local en delay
        en=$(gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null || true)
        delay=$(gsettings get org.gnome.desktop.session idle-delay 2>/dev/null || true)
        if [[ "$en" == "true" && "$delay" != "uint32 0" ]]; then
            locked=1
        fi
    fi
    if command -v xfconf-query >/dev/null 2>&1; then
        local xf
        xf=$(xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lock-screen-suspend-hibernate 2>/dev/null || true)
        [[ "$xf" == "true" ]] && locked=1
    fi
    if [[ "$locked" -eq 1 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}a lock setting is enabled${RST}"
    else
        echo -e "  ${YLW}!${RST}  ${padded} → ${YLW}no automatic screen lock detected${RST}"
    fi
}

_check_core_limit() {
    local padded file=/etc/security/limits.d/ghostmode-nocore.conf
    padded=$(printf "%-22s" "core dumps")
    if [[ -f "$file" ]] && grep -qE '^[[:space:]]*\*[[:space:]]+hard[[:space:]]+core[[:space:]]+0' "$file"; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}hard core is 0${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}core dumps are allowed${RST}"
    fi
}

_check_home_perms() {
    local padded mode
    padded=$(printf "%-22s" "home permissions")
    mode=$(stat -c '%a' "$HOME" 2>/dev/null || echo "")
    if [[ -z "$mode" ]]; then
        echo -e "  ${YLW}!${RST}  ${padded} → ${YLW}could not read${RST}"
        return
    fi
    if (( (8#$mode & ~8#750) != 0 )); then
        echo -e "  ${YLW}!${RST}  ${padded} → ${YLW}${mode} is wider than 750${RST}"
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}${mode}${RST}"
    fi
}

_check_hibernate() {
    local padded resume
    padded=$(printf "%-22s" "hibernate image")
    resume=$(cat /sys/power/resume 2>/dev/null || echo "0:0")
    local pstore=0
    if _dir_has_entries /var/lib/systemd/pstore; then
        pstore=1
    fi
    if [[ "$resume" != "0:0" && -n "$resume" ]] || [[ "$pstore" -eq 1 ]]; then
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}a resume image or pstore data is present${RST}"
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}none found${RST}"
    fi
}

_check_fingerprint_auto() {
    local padded
    padded=$(printf "%-22s" "fingerprint auto")
    if systemctl is-enabled --quiet ghostmode-fingerprint.service 2>/dev/null; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}rotates on boot${RST}"
    else
        echo -e "  ${YLW}!${RST}  ${padded} → ${YLW}off — a stable hostname identifies this device on the network${RST}"
    fi
    padded=$(printf "%-22s" "machine-id")
    echo -e "  ${GRY}~${RST}  ${padded} → ${GRY}stable. Not touched by auto. fingerprint rotate --machine-id changes it${RST}"
}
