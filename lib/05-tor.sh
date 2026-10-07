#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.

# ============================================================
#  TOR
# ============================================================

cmd_tor() {
    case "${1:-status}" in
        on)     _tor_on ;;
        off)    _tor_off ;;
        status) _tor_status ;;
        *)      echo "Usage: ghostmode tor [on|off|status]" ;;
    esac
}

_tor_on() {
    echo -e "${BLD}${CYN}[ Enabling Tor for all device connections ]${RST}"
    if ! command -v anonsurf >/dev/null 2>&1; then
        echo "  anonsurf is not installed — installing from source now (no official apt package exists)..."
        echo CHANGEME_PASSWORD | sudo -S apt-get update -qq 2>/dev/null
        echo CHANGEME_PASSWORD | sudo -S apt-get install -y git fakeroot 2>/dev/null
        local build_dir
        build_dir=$(mktemp -d)
        if git clone --depth 1 https://github.com/Und3rf10w/kali-anonsurf.git "$build_dir/kali-anonsurf" 2>/dev/null; then
            (cd "$build_dir/kali-anonsurf" && chmod +x installer.sh \
                && echo CHANGEME_PASSWORD | sudo -S ./installer.sh) 2>/dev/null
        fi
        rm -rf "$build_dir"
    fi
    if ! command -v anonsurf >/dev/null 2>&1; then
        echo -e "  ${RED}✘${RST}  Automatic anonsurf install failed — install it manually:"
        echo -e "       git clone https://github.com/Und3rf10w/kali-anonsurf.git"
        echo -e "       cd kali-anonsurf && sudo ./installer.sh"
        return 1
    fi
    echo CHANGEME_PASSWORD | sudo -S anonsurf start
    mkdir -p "$(dirname "$GHOSTMODE_TOR_STATE_FILE")"
    echo "on" > "$GHOSTMODE_TOR_STATE_FILE"

    # Exempt a dedicated "torbrowser" user from anonsurf's system-wide
    # redirect, the same way anonsurf itself exempts debian-tor (its own
    # Tor process) — "owner UID match" RETURN/ACCEPT rules inserted before
    # anonsurf's catch-all REDIRECT/REJECT rules. Without this, Tor Browser's
    # own bundled Tor gets redirected into anonsurf's tunnel too, nesting
    # Tor-over-Tor and breaking its TLS handshake to relays (TLS_ERROR).
    # anonsurf resets iptables fresh on every "start", so this is re-applied
    # every time _tor_on runs, including the boot-time persistence unit.
    if ! id -u torbrowser >/dev/null 2>&1; then
        # -m (with a real home dir) instead of -M: it needs somewhere it
        # actually owns to keep its own private copy of the browser, since
        # it can't traverse into the regular user's home directory at all
        # (Debian/Kali home dirs block other users by default).
        echo CHANGEME_PASSWORD | sudo -S useradd -r -m -d /home/torbrowser -s /usr/sbin/nologin torbrowser 2>/dev/null
    elif [[ ! -d /home/torbrowser ]]; then
        # Repairs a 'torbrowser' user left over from an older version of
        # this script, which was created without a home directory (-M).
        echo CHANGEME_PASSWORD | sudo -S mkdir -p /home/torbrowser 2>/dev/null
        echo CHANGEME_PASSWORD | sudo -S chown torbrowser:torbrowser /home/torbrowser 2>/dev/null
        echo CHANGEME_PASSWORD | sudo -S usermod -d /home/torbrowser torbrowser 2>/dev/null
    fi
    local tb_uid
    tb_uid=$(id -u torbrowser 2>/dev/null)
    if [[ -n "$tb_uid" ]]; then
        echo CHANGEME_PASSWORD | sudo -S iptables -t nat -I OUTPUT 1 -m owner --uid-owner "$tb_uid" -j RETURN 2>/dev/null
        echo CHANGEME_PASSWORD | sudo -S iptables -I OUTPUT 1 -m owner --uid-owner "$tb_uid" -j ACCEPT 2>/dev/null
    fi

    # Persistence after reboot: a SYSTEM-level service (not user/lingering)
    # that runs as the real user via User=, and calls "ghostmode tor on"
    # itself — the exact same code path as running the command by hand, not
    # a separate "anonsurf start" shortcut. Any future fix to _tor_on()
    # automatically applies to the boot-time run too. System-level + multi-
    # user.target is guaranteed to start on every boot, unlike a --user unit
    # which depends on the user's systemd instance/D-Bus session coming up
    # cleanly via lingering — that extra dependency is what made it unreliable.
    local ghostmode_path="$HOME/.local/bin/ghostmode"
    local run_user
    run_user=$(whoami)
    cat > /tmp/ghostmode-tor-boot.service << UNIT
[Unit]
Description=Ghost Mode - Auto Tor on boot (runs: ghostmode tor on)
After=network-online.target NetworkManager-wait-online.service
Wants=network-online.target NetworkManager-wait-online.service
StartLimitIntervalSec=300
StartLimitBurst=10

[Service]
Type=oneshot
User=${run_user}
ExecStartPre=/bin/sleep 10
ExecStart=${ghostmode_path} tor on
Restart=on-failure
RestartSec=15
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
    echo CHANGEME_PASSWORD | sudo -S mv /tmp/ghostmode-tor-boot.service "$GHOSTMODE_TOR_UNIT"
    echo CHANGEME_PASSWORD | sudo -S chown root:root "$GHOSTMODE_TOR_UNIT"
    echo CHANGEME_PASSWORD | sudo -S systemctl daemon-reload
    echo CHANGEME_PASSWORD | sudo -S systemctl enable ghostmode-tor-boot.service 2>/dev/null

    # Clean up the older --user unit from a previous version, if present
    if [[ -f "$GHOSTMODE_TOR_LEGACY_USER_UNIT" ]]; then
        systemctl --user disable ghostmode-tor-boot.service 2>/dev/null
        rm -f "$GHOSTMODE_TOR_LEGACY_USER_UNIT"
        systemctl --user daemon-reload 2>/dev/null
    fi

    echo -e "  ${GRN}${BLD}[+] Tor is now active for all device connections and browsers.${RST}"
    echo -e "  ${GRN}It will stay active automatically even after rebooting the laptop.${RST}"
}

_tor_off() {
    echo -e "${BLD}${CYN}[ Disabling Tor ]${RST}"
    if [[ "$(cat "$GHOSTMODE_KS_STATE_FILE" 2>/dev/null)" == "on" ]]; then
        echo -e "  ${YLW}${BLD}Kill switch is armed in double-protection mode.${RST}"
        echo -e "  ${YLW}Internet will stay CUT after Tor stops, until you also run:${RST} ${BLD}ghostmode killswitch off${RST}"
    fi
    if command -v anonsurf >/dev/null 2>&1; then
        echo CHANGEME_PASSWORD | sudo -S anonsurf stop
    fi
    mkdir -p "$(dirname "$GHOSTMODE_TOR_STATE_FILE")"
    echo "off" > "$GHOSTMODE_TOR_STATE_FILE"
    echo CHANGEME_PASSWORD | sudo -S systemctl disable --now ghostmode-tor-boot.service 2>/dev/null
    echo CHANGEME_PASSWORD | sudo -S rm -f "$GHOSTMODE_TOR_UNIT"
    echo CHANGEME_PASSWORD | sudo -S systemctl daemon-reload
    # Clean up any leftover units from older versions of this script
    if [[ -f "$GHOSTMODE_TOR_LEGACY_UNIT" ]]; then
        echo CHANGEME_PASSWORD | sudo -S systemctl disable --now ghostmode-tor.service 2>/dev/null
        echo CHANGEME_PASSWORD | sudo -S rm -f "$GHOSTMODE_TOR_LEGACY_UNIT" 2>/dev/null
        echo CHANGEME_PASSWORD | sudo -S systemctl daemon-reload 2>/dev/null
    fi
    if [[ -f "$GHOSTMODE_TOR_LEGACY_USER_UNIT" ]]; then
        systemctl --user disable --now ghostmode-tor-boot.service 2>/dev/null
        rm -f "$GHOSTMODE_TOR_LEGACY_USER_UNIT"
        systemctl --user daemon-reload 2>/dev/null
    fi
    echo -e "  ${RED}[-] Tor is now stopped.${RST}"
}

_tor_status() {
    echo -e "${BLD}${CYN}[ Tor status ]${RST}"
    local padded state
    state=$(cat "$GHOSTMODE_TOR_STATE_FILE" 2>/dev/null)
    padded=$(printf "%-22s" "saved state")
    if [[ "$state" == "on" ]]; then
        echo -e "  ${CYN}◉${RST}  ${padded} → ${GRN}${BLD}ON${RST}"
    else
        echo -e "  ${CYN}◉${RST}  ${padded} → ${RED}OFF${RST}"
    fi
    padded=$(printf "%-22s" "tor process running now")
    if pgrep -x tor >/dev/null 2>&1; then
        echo -e "  ${CYN}◉${RST}  ${padded} → ${GRN}yes${RST}"
    else
        echo -e "  ${CYN}◉${RST}  ${padded} → ${RED}no${RST}"
    fi
    padded=$(printf "%-22s" "persists after reboot")
    if systemctl is-enabled --quiet ghostmode-tor-boot.service 2>/dev/null; then
        echo -e "  ${CYN}◉${RST}  ${padded} → ${GRN}enabled (system-level)${RST}"
    else
        echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}disabled${RST}"
    fi
    if command -v anonsurf >/dev/null 2>&1; then
        echo ""
        echo CHANGEME_PASSWORD | sudo -S anonsurf status 2>/dev/null
    fi
}

