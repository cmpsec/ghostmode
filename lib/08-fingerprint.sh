#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.

# ============================================================
#  FINGERPRINT ROTATION  (MAC address + hostname — local-network level,
#  not in-browser JS fingerprinting, which Tor Browser already handles)
# ============================================================

GHOSTMODE_FP_UNIT="/etc/systemd/system/ghostmode-fingerprint.service"
GHOSTMODE_FP_LEGACY_USER_UNIT="$HOME/.config/systemd/user/ghostmode-fingerprint.service"

cmd_fingerprint() {
    case "${1:-}" in
        rotate) shift; _fingerprint_rotate "$@" ;;
        auto)   shift; _fingerprint_auto "$@" ;;
        *)      echo "Usage: ghostmode fingerprint [rotate [--machine-id]|auto on|auto off]" ;;
    esac
}

_fingerprint_rotate() {
    local rotate_machine_id=0
    if [[ "${1:-}" == "--machine-id" ]]; then
        rotate_machine_id=1
    fi
    echo -e "${BLD}${CYN}[ Rotating device fingerprint ]${RST}"
    local iface
    iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
    if [[ -n "$iface" ]]; then
        local new_mac
        new_mac=$(printf '02:%02x:%02x:%02x:%02x:%02x' \
            $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) \
            $((RANDOM % 256)) $((RANDOM % 256)))
        _gm_sudo ip link set dev "$iface" down 2>/dev/null
        _gm_sudo ip link set dev "$iface" address "$new_mac" 2>/dev/null
        _gm_sudo ip link set dev "$iface" up 2>/dev/null
        echo -e "  ${GRN}✔${RST}  MAC rotated (${iface}) → ${new_mac}"
        echo -e "       ${GRY}WiFi may reconnect automatically via the saved profile${RST}"
    else
        echo -e "  ${YLW}!${RST}  No active network interface found to rotate"
    fi
    local new_host
    new_host="kali-$(tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c6)"
    _gm_sudo hostnamectl set-hostname "$new_host" 2>/dev/null || true
    echo -e "  ${GRN}✔${RST}  Hostname rotated → ${new_host}"
    if [[ "$rotate_machine_id" -eq 1 ]]; then
        echo -e "  ${YLW}This regenerates /etc/machine-id. It drops sessions bound to that id and needs a reboot.${RST}"
        if [[ ! -t 0 ]]; then
            echo -e "  ${RED}✘${RST}  Refusing --machine-id without a terminal."
            return 1
        fi
        local confirm
        read -rp "  Type ROTATE to regenerate machine-id: " confirm
        if [[ "$confirm" != "ROTATE" ]]; then
            echo "  Left machine-id unchanged."
            return 1
        fi
        _gm_sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
        if _gm_sudo systemd-machine-id-setup; then
            echo -e "  ${YLW}!${RST}  machine-id regenerated. Reboot before trusting the new id."
        else
            echo -e "  ${RED}✘${RST}  Could not regenerate machine-id."
            return 1
        fi
    fi
}

_fingerprint_auto() {
    case "${1:-}" in
        on)
            local run_user
            run_user=$(whoami)
            cat > /tmp/ghostmode-fingerprint.service << UNIT
[Unit]
Description=Ghost Mode - Fingerprint rotation on boot
After=network-online.target

[Service]
Type=oneshot
User=${run_user}
ExecStartPre=/bin/sleep 15
ExecStart=$HOME/.local/bin/ghostmode fingerprint rotate

[Install]
WantedBy=multi-user.target
UNIT
            _gm_sudo mv /tmp/ghostmode-fingerprint.service "$GHOSTMODE_FP_UNIT"
            _gm_sudo chown root:root "$GHOSTMODE_FP_UNIT"
            _gm_sudo systemctl daemon-reload
            _gm_sudo systemctl enable ghostmode-fingerprint.service 2>/dev/null
            if [[ -f "$GHOSTMODE_FP_LEGACY_USER_UNIT" ]]; then
                systemctl --user disable ghostmode-fingerprint.service 2>/dev/null
                rm -f "$GHOSTMODE_FP_LEGACY_USER_UNIT"
                systemctl --user daemon-reload 2>/dev/null
            fi
            echo -e "  ${GRN}${BLD}[+] Auto fingerprint rotation enabled — rotates every boot.${RST}"
            ;;
        off)
            _gm_sudo systemctl disable --now ghostmode-fingerprint.service 2>/dev/null
            _gm_sudo rm -f "$GHOSTMODE_FP_UNIT" 2>/dev/null
            _gm_sudo systemctl daemon-reload 2>/dev/null
            if [[ -f "$GHOSTMODE_FP_LEGACY_USER_UNIT" ]]; then
                systemctl --user disable ghostmode-fingerprint.service 2>/dev/null
                rm -f "$GHOSTMODE_FP_LEGACY_USER_UNIT"
                systemctl --user daemon-reload 2>/dev/null
            fi
            echo -e "  ${RED}[-] Auto fingerprint rotation disabled.${RST}"
            ;;
        *)
            echo "Usage: ghostmode fingerprint auto [on|off]"
            ;;
    esac
}

