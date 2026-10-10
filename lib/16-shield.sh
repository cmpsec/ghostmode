#!/usr/bin/env bash
# shellcheck shell=bash
# Fail-closed extras used with Tor. auto never changes these rules.

GHOSTMODE_SHIELD_DROPIN="/etc/NetworkManager/conf.d/ghostmode-shield.conf"

_shield_tor_running() {
    pgrep -x tor >/dev/null 2>&1
}

_shield_ks_armed() {
    [[ "$(cat "$GHOSTMODE_KS_STATE_FILE" 2>/dev/null)" == "on" ]]
}

_shield_write_state() {
    mkdir -p "$HOME/.config/ghostmode"
    umask 077
    {
        printf 'IPV6_ALL=%q\n' "$1"
        printf 'IPV6_DEFAULT=%q\n' "$2"
        printf 'IP6_POLICY=%q\n' "$3"
        printf 'NM_CONN=%q\n' "$4"
        printf 'NM_DHCP4=%q\n' "$5"
        printf 'NM_DHCP6=%q\n' "$6"
        printf 'TIMESYNCD=%q\n' "$7"
    } > "$GHOSTMODE_SHIELD_STATE"
    chmod 600 "$GHOSTMODE_SHIELD_STATE"
}

_shield_ipv6_global() {
    ip -6 -o addr show scope global 2>/dev/null | awk '$2 != "lo" { found=1 } END { exit found ? 0 : 1 }'
}

_shield_dns_public() {
    local ns
    while read -r ns; do
        [[ -z "$ns" ]] && continue
        case "$ns" in
            127.* | ::1 | localhost) continue ;;
            10.* | 192.168.* | 172.1[6-9].* | 172.2[0-9].* | 172.3[0-1].*) continue ;;
        esac
        return 0
    done < <(awk '/^nameserver/ { print $2 }' /etc/resolv.conf 2>/dev/null)
    return 1
}

_shield_output_policy() {
    iptables -S OUTPUT 2>/dev/null | awk 'NR==1 { print $3; exit }'
}

_ipv6_output_policy() {
    ip6tables -S OUTPUT 2>/dev/null | awk 'NR==1 { print $3; exit }'
}

_shield_block_announce() {
    local port
    for port in 5353 1900 137 138; do
        _gm_sudo iptables -C OUTPUT -p udp --dport "$port" -j DROP 2>/dev/null \
            || _gm_sudo iptables -I OUTPUT -p udp --dport "$port" -j DROP
        _gm_sudo ip6tables -C OUTPUT -p udp --dport "$port" -j DROP 2>/dev/null \
            || _gm_sudo ip6tables -I OUTPUT -p udp --dport "$port" -j DROP
    done
}

_shield_unblock_announce() {
    local port
    for port in 5353 1900 137 138; do
        while _gm_sudo iptables -C OUTPUT -p udp --dport "$port" -j DROP 2>/dev/null; do
            _gm_sudo iptables -D OUTPUT -p udp --dport "$port" -j DROP 2>/dev/null || break
        done
        while _gm_sudo ip6tables -C OUTPUT -p udp --dport "$port" -j DROP 2>/dev/null; do
            _gm_sudo ip6tables -D OUTPUT -p udp --dport "$port" -j DROP 2>/dev/null || break
        done
    done
}

_shield_on() {
    if ! _shield_tor_running && ! _shield_ks_armed; then
        echo -e "  ${RED}✘${RST}  Shield refused: Tor is not running. Start it with: ghostmode tor on"
        return 1
    fi
    local ipv6_all ipv6_def ip6_pol
    ipv6_all=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo 0)
    ipv6_def=$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null || echo 0)
    ip6_pol=$(_ipv6_output_policy)
    ip6_pol=${ip6_pol:-ACCEPT}

    local nm_conn="" dhcp4="" dhcp6=""
    if command -v nmcli >/dev/null 2>&1; then
        nm_conn=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | head -1 | cut -d: -f1)
        if [[ -n "$nm_conn" ]]; then
            dhcp4=$(nmcli -g ipv4.dhcp-send-hostname connection show "$nm_conn" 2>/dev/null || true)
            dhcp6=$(nmcli -g ipv6.dhcp-send-hostname connection show "$nm_conn" 2>/dev/null || true)
        fi
    fi
    local timesyncd=0
    if systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
        timesyncd=1
    fi

    _shield_write_state "$ipv6_all" "$ipv6_def" "$ip6_pol" "$nm_conn" "$dhcp4" "$dhcp6" "$timesyncd"

    if ! _gm_sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null; then
        echo -e "  ${RED}✘${RST}  Shield could not disable IPv6"
        return 1
    fi
    if ! _gm_sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null; then
        echo -e "  ${RED}✘${RST}  Shield could not disable IPv6"
        return 1
    fi

    _gm_sudo ip6tables -P OUTPUT DROP || return 1
    _gm_sudo ip6tables -C OUTPUT -o lo -j ACCEPT 2>/dev/null \
        || _gm_sudo ip6tables -A OUTPUT -o lo -j ACCEPT

    _shield_block_announce || return 1

    if [[ -n "$nm_conn" ]]; then
        _gm_sudo nmcli connection modify "$nm_conn" ipv4.dhcp-send-hostname no ipv6.dhcp-send-hostname no \
            && echo -e "  ${GRY}DHCP hostname suppressed on ${nm_conn}${RST}"
    fi

    local drop
    drop=$(mktemp)
    printf '%s\n' '[connectivity]' 'enabled=false' > "$drop"
    _gm_sudo mv "$drop" "$GHOSTMODE_SHIELD_DROPIN"
    _gm_sudo chmod 644 "$GHOSTMODE_SHIELD_DROPIN"

    if [[ "$timesyncd" -eq 1 ]]; then
        _gm_sudo systemctl stop systemd-timesyncd
        echo -e "  ${YLW}!${RST}  systemd-timesyncd stopped while the shield is on. The clock can drift."
    fi

    echo -e "  ${GRN}✔${RST}  Shield is on. Local printers and device discovery (mDNS/SSDP/NetBIOS) are blocked."
    echo -e "  ${GRY}IPv4 kill switch, if armed, is unchanged.${RST}"
    return 0
}

_shield_off() {
    if [[ ! -f "$GHOSTMODE_SHIELD_STATE" && ! -f "$GHOSTMODE_SHIELD_DROPIN" ]]; then
        return 0
    fi
    if [[ ! -f "$GHOSTMODE_SHIELD_STATE" ]]; then
        echo -e "  ${RED}✘${RST}  Shield state file is gone. Restoring IPv6 defaults only."
        _gm_sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null || true
        _gm_sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null || true
        _gm_sudo ip6tables -P OUTPUT ACCEPT || true
        _shield_unblock_announce || true
        _gm_sudo rm -f "$GHOSTMODE_SHIELD_DROPIN" 2>/dev/null || true
        echo -e "  ${RED}✘${RST}  Previous state was lost. IPv4 OUTPUT was not opened."
        return 1
    fi

    # shellcheck disable=SC1090
    source "$GHOSTMODE_SHIELD_STATE"
    _gm_sudo sysctl -w "net.ipv6.conf.all.disable_ipv6=${IPV6_ALL:-0}" >/dev/null || true
    _gm_sudo sysctl -w "net.ipv6.conf.default.disable_ipv6=${IPV6_DEFAULT:-0}" >/dev/null || true
    _gm_sudo ip6tables -P OUTPUT "${IP6_POLICY:-ACCEPT}" || true
    _shield_unblock_announce || true

    if [[ -n "${NM_CONN:-}" ]] && command -v nmcli >/dev/null 2>&1; then
        _gm_sudo nmcli connection modify "$NM_CONN" \
            ipv4.dhcp-send-hostname "${NM_DHCP4:-yes}" \
            ipv6.dhcp-send-hostname "${NM_DHCP6:-yes}" || true
    fi
    _gm_sudo rm -f "$GHOSTMODE_SHIELD_DROPIN" 2>/dev/null || true
    if [[ "${TIMESYNCD:-0}" == "1" ]]; then
        _gm_sudo systemctl start systemd-timesyncd || true
    fi
    rm -f "$GHOSTMODE_SHIELD_STATE"
    echo -e "  ${GRN}✔${RST}  Shield restored the saved IPv6, DHCP hostname, captive-portal, and NTP state."
    if _shield_ks_armed; then
        echo -e "  ${YLW}!${RST}  Kill switch is still armed. IPv4 OUTPUT was left as the kill switch set it."
    fi
    return 0
}

_conn_line_sensitive() {
    local raw="$1"
    printf '%s' "$raw" | grep -Eiq 'crsr_|api[-_]?key|token|password|ghp_|github_pat_|gho_'
}

_shield_foreign_established() {
    local line peer proc
    ss -H -tpn state established 2>/dev/null | while IFS= read -r line; do
        [[ "$line" == *" 127."* || "$line" == *"[::1]"* ]] && continue
        peer=$(awk '{ print $4 }' <<< "$line")
        [[ "$peer" == 127.* || "$peer" == "[::1]"* || "$peer" == "::1"* ]] && continue
        proc=$(sed -n 's/.*users:(("\([^"]*\).*/\1/p' <<< "$line")
        case "$proc" in
            tor | debian-tor) continue ;;
        esac
        local pid user
        pid=$(sed -n 's/.*pid=\([0-9]*\).*/\1/p' <<< "$line")
        user=""
        if [[ -n "$pid" ]]; then
            user=$(ps -o user= -p "$pid" 2>/dev/null | awk '{ print $1 }')
        fi
        case "$user" in
            debian-tor | tor | torbrowser) continue ;;
        esac
        if _conn_line_sensitive "$line"; then
            printf '%s\n' "ESTAB ${peer} [redacted]"
        else
            printf '%s\n' "ESTAB ${peer} ${proc:-unknown}"
        fi
    done
}

_shield_print_row() {
    local ok="$1" label="$2" detail="$3"
    local padded
    padded=$(printf "%-22s" "$label")
    if [[ "$ok" == "green" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}${detail}${RST}"
    elif [[ "$ok" == "yellow" ]]; then
        echo -e "  ${YLW}!${RST}  ${padded} → ${YLW}${detail}${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${detail}${RST}"
    fi
}

_shield_status() {
    echo -e "${BLD}${CYN}[ Shield ]${RST}"
    local tor=0
    _shield_tor_running && tor=1

    if [[ "$tor" -eq 0 ]]; then
        _shield_print_row green "IPv6" "Tor is off"
    elif _shield_ipv6_global; then
        _shield_print_row red "IPv6" "global address on a non-loopback interface"
    else
        _shield_print_row green "IPv6" "no global address"
    fi

    if [[ "$tor" -eq 0 ]]; then
        _shield_print_row green "DNS" "Tor is off"
    elif _shield_dns_public; then
        _shield_print_row red "DNS" "resolv.conf lists a public resolver outside the tunnel"
    else
        _shield_print_row green "DNS" "no public resolver in resolv.conf"
    fi

    local announce=1 port
    for port in 5353 1900 137 138; do
        if ! iptables -C OUTPUT -p udp --dport "$port" -j DROP 2>/dev/null \
            && ! _gm_sudo iptables -C OUTPUT -p udp --dport "$port" -j DROP 2>/dev/null; then
            announce=0
        fi
    done
    if [[ "$tor" -eq 1 && -f "$GHOSTMODE_SHIELD_STATE" ]]; then
        if [[ "$announce" -eq 1 ]]; then
            _shield_print_row green "LAN announce" "mDNS/SSDP/NetBIOS blocked"
        else
            _shield_print_row red "LAN announce" "discovery ports are not blocked"
        fi
    else
        _shield_print_row green "LAN announce" "shield not engaged"
    fi

    if [[ "$tor" -eq 1 && -f "$GHOSTMODE_SHIELD_STATE" ]]; then
        if systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
            _shield_print_row red "NTP" "systemd-timesyncd is still running"
        else
            _shield_print_row green "NTP" "systemd-timesyncd is not running"
        fi
        if [[ -f "$GHOSTMODE_SHIELD_DROPIN" ]]; then
            _shield_print_row green "captive portal" "NetworkManager check disabled by the shield"
        else
            _shield_print_row red "captive portal" "shield drop-in is missing"
        fi
    else
        _shield_print_row green "NTP" "shield not engaged"
        _shield_print_row green "captive portal" "shield not engaged"
    fi

    if [[ "$tor" -eq 1 ]]; then
        local foreign
        foreign=$(_shield_foreign_established | head -n 5)
        if [[ -n "$foreign" ]]; then
            _shield_print_row red "non-Tor flows" "established connection outside Tor"
            printf '%s\n' "$foreign" | sed 's/^/       ╰ /'
        else
            _shield_print_row green "non-Tor flows" "none seen"
        fi
    else
        _shield_print_row green "non-Tor flows" "Tor is off"
    fi

    local pol
    pol=$(_shield_output_policy)
    if [[ "$tor" -eq 0 && "$pol" == "DROP" ]]; then
        _shield_print_row red "kill switch" "Tor is off and OUTPUT is DROP. Repair: ghostmode killswitch off"
    elif [[ "$tor" -eq 0 && "$(_shield_ks_armed && echo yes)" == "yes" && "$pol" != "DROP" ]]; then
        _shield_print_row red "kill switch" "armed, Tor is down, and OUTPUT is not DROP"
    elif _shield_ks_armed; then
        _shield_print_row green "kill switch" "armed"
    else
        _shield_print_row green "kill switch" "not armed"
    fi
}

# Read-only. Used by auto. Does not change firewall, IPv6, or NTP.
_shield_audit() {
    _shield_tor_running || return 0
    local bad=0
    if _shield_ipv6_global; then
        echo -e "  ${RED}✘${RST}  Shield: Tor is on and a global IPv6 address is up" >&2
        bad=1
    fi
    if _shield_dns_public; then
        echo -e "  ${RED}✘${RST}  Shield: Tor is on and DNS points at a public resolver" >&2
        bad=1
    fi
    if [[ ! -f "$GHOSTMODE_SHIELD_STATE" ]]; then
        echo -e "  ${RED}✘${RST}  Shield: Tor is on and the shield is not engaged" >&2
        bad=1
    fi
    local foreign
    foreign=$(_shield_foreign_established | head -n 1)
    if [[ -n "$foreign" ]]; then
        echo -e "  ${RED}✘${RST}  Shield: established connection is not a Tor process" >&2
        bad=1
    fi
    return "$bad"
}

cmd_shield() {
    case "${1:-status}" in
        on)     _shield_on ;;
        off)    _shield_off ;;
        status) _shield_status ;;
        *)      echo "Usage: ghostmode shield [on|off|status]" ;;
    esac
}
