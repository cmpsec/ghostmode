#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.

# ============================================================
#  KILL SWITCH  (only enforces while Tor is ON; VPN fallback optional)
# ============================================================

GHOSTMODE_KS_STATE_FILE="$HOME/.config/ghostmode/killswitch_state"
GHOSTMODE_KS_VPN_FILE="$HOME/.config/ghostmode/killswitch_vpn_path"
GHOSTMODE_KS_WATCHDOG="$HOME/.config/ghostmode/killswitch-watchdog.sh"
GHOSTMODE_KS_UNIT="/etc/systemd/system/ghostmode-killswitch.service"
GHOSTMODE_KS_LEGACY_USER_UNIT="$HOME/.config/systemd/user/ghostmode-killswitch.service"

cmd_killswitch() {
    case "${1:-status}" in
        on)     _killswitch_on ;;
        off)    _killswitch_off ;;
        status) _killswitch_status ;;
        *)      echo "Usage: ghostmode killswitch [on|off|status]" ;;
    esac
}

_killswitch_on() {
    echo -e "${BLD}${CYN}[ Arming the kill switch ]${RST}"
    echo "  This only takes effect while Tor is ON (ghostmode tor on)."
    echo "  If Tor is OFF, your connection behaves normally regardless."
    echo ""
    read -rp "  VPN config path for automatic fallback (.ovpn or WireGuard .conf) — leave empty to skip: " vpn_path
    mkdir -p "$(dirname "$GHOSTMODE_KS_STATE_FILE")"
    if [[ -n "$vpn_path" && ! -f "$vpn_path" ]]; then
        echo -e "  ${YLW}!${RST} File not found — continuing without a VPN fallback."
        vpn_path=""
    fi
    echo "$vpn_path" > "$GHOSTMODE_KS_VPN_FILE"
    echo "on" > "$GHOSTMODE_KS_STATE_FILE"

    cat > "$GHOSTMODE_KS_WATCHDOG" << 'WATCHDOG'
#!/usr/bin/env bash
KS_STATE_FILE="$HOME/.config/ghostmode/killswitch_state"
VPN_PATH_FILE="$HOME/.config/ghostmode/killswitch_vpn_path"
ENGAGED=0

_gm_sudo() {
    local passfile="$HOME/.config/ghostmode/sudo.pass"
    if [[ -f "$passfile" ]]; then
        sudo -S -p '' "$@" < "$passfile"
        return
    fi
    if [[ -x /usr/local/libexec/ghostmode-priv ]]; then
        sudo -n /usr/local/libexec/ghostmode-priv "$@"
        return
    fi
    sudo -n "$@"
}

# Double-protection mode: once armed, enforcement depends only on whether
# Tor is actually running — NOT on whether tor_state says "on" or "off".
# This means a manual "ghostmode tor off" while the kill switch is armed
# does NOT restore normal internet by itself; only an explicit
# "ghostmode killswitch off" releases the block. This is intentional,
# confirmed behavior, not an oversight.
while true; do
    ks=$(cat "$KS_STATE_FILE" 2>/dev/null)
    if [[ "$ks" == "on" ]]; then
        if ! pgrep -x tor >/dev/null 2>&1; then
            if [[ "$ENGAGED" -eq 0 ]]; then
                _gm_sudo iptables -P OUTPUT DROP 2>/dev/null
                _gm_sudo iptables -F OUTPUT 2>/dev/null
                _gm_sudo iptables -A OUTPUT -o lo -j ACCEPT 2>/dev/null
                ENGAGED=1
                vpn_path=$(cat "$VPN_PATH_FILE" 2>/dev/null)
                if [[ -n "$vpn_path" && -f "$vpn_path" ]]; then
                    case "$vpn_path" in
                        *.ovpn) _gm_sudo openvpn --config "$vpn_path" --daemon 2>/dev/null ;;
                        *.conf) _gm_sudo wg-quick up "$vpn_path" 2>/dev/null ;;
                    esac
                fi
            fi
        else
            if [[ "$ENGAGED" -eq 1 ]]; then
                _gm_sudo iptables -P OUTPUT ACCEPT 2>/dev/null
                _gm_sudo iptables -F OUTPUT 2>/dev/null
                ENGAGED=0
            fi
        fi
    else
        if [[ "$ENGAGED" -eq 1 ]]; then
            _gm_sudo iptables -P OUTPUT ACCEPT 2>/dev/null
            _gm_sudo iptables -F OUTPUT 2>/dev/null
            ENGAGED=0
        fi
    fi
    sleep 5
done
WATCHDOG
    chmod +x "$GHOSTMODE_KS_WATCHDOG"

    # System-level (not --user/lingering) for the same reliability reason as
    # the Tor boot unit — guaranteed to start at multi-user.target every boot.
    local run_user
    run_user=$(whoami)
    cat > /tmp/ghostmode-killswitch.service << UNIT
[Unit]
Description=Ghost Mode - Kill Switch Watchdog
After=ghostmode-tor-boot.service

[Service]
Type=simple
User=${run_user}
ExecStart=/bin/bash ${GHOSTMODE_KS_WATCHDOG}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
    _gm_sudo mv /tmp/ghostmode-killswitch.service "$GHOSTMODE_KS_UNIT"
    _gm_sudo chown root:root "$GHOSTMODE_KS_UNIT"
    _gm_sudo systemctl daemon-reload
    _gm_sudo systemctl enable --now ghostmode-killswitch.service

    if [[ -f "$GHOSTMODE_KS_LEGACY_USER_UNIT" ]]; then
        systemctl --user disable --now ghostmode-killswitch.service 2>/dev/null
        rm -f "$GHOSTMODE_KS_LEGACY_USER_UNIT"
        systemctl --user daemon-reload 2>/dev/null
    fi

    echo -e "  ${GRN}${BLD}[+] Kill switch armed.${RST}"
    if [[ -n "$vpn_path" ]]; then
        echo -e "  ${GRN}VPN fallback configured: ${vpn_path}${RST}"
    else
        echo -e "  ${YLW}No VPN fallback — if Tor drops, internet is cut entirely until Tor is back.${RST}"
    fi
}

_killswitch_off() {
    echo -e "${BLD}${CYN}[ Disarming the kill switch ]${RST}"
    echo "off" > "$GHOSTMODE_KS_STATE_FILE" 2>/dev/null
    _gm_sudo systemctl disable --now ghostmode-killswitch.service 2>/dev/null
    _gm_sudo rm -f "$GHOSTMODE_KS_UNIT" 2>/dev/null
    _gm_sudo systemctl daemon-reload 2>/dev/null
    if [[ -f "$GHOSTMODE_KS_LEGACY_USER_UNIT" ]]; then
        systemctl --user disable --now ghostmode-killswitch.service 2>/dev/null
        rm -f "$GHOSTMODE_KS_LEGACY_USER_UNIT"
        systemctl --user daemon-reload 2>/dev/null
    fi
    # Release any engaged block just in case
    _gm_sudo iptables -P OUTPUT ACCEPT 2>/dev/null
    _gm_sudo iptables -F OUTPUT 2>/dev/null
    echo -e "  ${RED}[-] Kill switch disarmed. Normal networking restored.${RST}"
}

_killswitch_status() {
    echo -e "${BLD}${CYN}[ Kill switch status ]${RST}"
    local padded state vpn
    state=$(cat "$GHOSTMODE_KS_STATE_FILE" 2>/dev/null)
    padded=$(printf "%-22s" "armed")
    if [[ "$state" == "on" ]]; then
        echo -e "  ${CYN}◉${RST}  ${padded} → ${GRN}${BLD}ON${RST}"
    else
        echo -e "  ${CYN}◉${RST}  ${padded} → ${RED}OFF${RST}"
    fi
    padded=$(printf "%-22s" "watchdog running")
    if systemctl is-active --quiet ghostmode-killswitch.service 2>/dev/null; then
        echo -e "  ${CYN}◉${RST}  ${padded} → ${GRN}yes${RST}"
    else
        echo -e "  ${CYN}◉${RST}  ${padded} → ${RED}no${RST}"
    fi
    vpn=$(cat "$GHOSTMODE_KS_VPN_FILE" 2>/dev/null)
    padded=$(printf "%-22s" "VPN fallback")
    if [[ -n "$vpn" ]]; then
        echo -e "  ${CYN}◉${RST}  ${padded} → ${GRN}${vpn}${RST}"
    else
        echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}none configured${RST}"
    fi
}

