#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.

# ============================================================
#  CONNECTIONS
# ============================================================

_is_in_array() {
    local needle="$1"; shift
    local x
    for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
    return 1
}

_conn_public_info() {
    local padded json
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "  ${GRY}~${RST}  Public IP/Country     → ${GRY}curl not installed${RST}"
        return
    fi
    json=$(curl -s --max-time 4 https://ipinfo.io/json 2>/dev/null)
    if [[ -z "$json" ]]; then
        echo -e "  ${GRY}~${RST}  Public IP/Country     → ${GRY}no internet connection${RST}"
        return
    fi
    local pub_ip pub_country pub_city pub_org
    pub_ip=$(echo "$json"      | grep -oP '"ip"\s*:\s*"\K[^"]+')
    pub_country=$(echo "$json" | grep -oP '"country"\s*:\s*"\K[^"]+')
    pub_city=$(echo "$json"    | grep -oP '"city"\s*:\s*"\K[^"]+')
    pub_org=$(echo "$json"     | grep -oP '"org"\s*:\s*"\K[^"]+')
    padded=$(printf "%-22s" "Public IP")
    echo -e "  ${CYN}◉${RST}  ${padded} → ${BLD}${pub_ip:-?}${RST}"
    padded=$(printf "%-22s" "Country/City")
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${pub_country:-?} / ${pub_city:-?}${RST}"
    padded=$(printf "%-22s" "ISP")
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${pub_org:-?}${RST}"
}

_conn_local_info() {
    local padded iface local_ip gateway dns
    iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
    local_ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d.]+')
    gateway=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
    dns=$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | paste -sd, -)

    padded=$(printf "%-22s" "Interface")
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${iface:-?}${RST}"
    padded=$(printf "%-22s" "Local IP")
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${local_ip:-?}${RST}"
    padded=$(printf "%-22s" "Gateway")
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${gateway:-?}${RST}"
    padded=$(printf "%-22s" "DNS servers")
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${dns:-?}${RST}"

    padded=$(printf "%-22s" "Tor")
    if pgrep -x tor >/dev/null 2>&1; then
        echo -e "  ${CYN}◉${RST}  ${padded} → ${GRN}${BLD}ON${RST}"
    else
        echo -e "  ${CYN}◉${RST}  ${padded} → ${RED}OFF${RST}"
    fi
}

# Prints one connection row in a unified format, returns 0 if flagged suspicious (to add to the review list)
_conn_print_row() {
    local local_addr="$1" peer_addr="$2" state="$3" pname="$4" pid="$5" tag="$6"
    local lpad ppad spad
    lpad=$(printf "%-22s" "$local_addr")
    ppad=$(printf "%-22s" "$peer_addr")
    spad=$(printf "%-9s" "$state")
    local proc_disp="${pname:-?}${pid:+(${pid})}"
    if [[ "$tag" == "red" ]]; then
        echo -e "  ${RED}✘${RST}  ${lpad} → ${ppad} ${spad} ${RED}${proc_disp:-?}${RST}"
        return 0
    elif [[ "$tag" == "yellow" ]]; then
        echo -e "  ${YLW}!${RST}  ${lpad} → ${ppad} ${spad} ${YLW}${proc_disp:-?}${RST}"
        return 1
    else
        echo -e "  ${GRN}✔${RST}  ${lpad} → ${ppad} ${spad} ${GRY}${proc_disp:-?}${RST}"
        return 1
    fi
}

cmd_connections() {
    case "${1:-}" in
        block) shift; _conn_block "$@"; return ;;
        kill)  shift; _conn_kill "$@";  return ;;
    esac

    echo ""
    echo -e "${BLD}${BLU}╔══════════════════════════════════════════════════╗${RST}"
    echo -e "${BLD}${BLU}║                NETWORK CONNECTIONS              ║${RST}"
    echo -e "${BLD}${BLU}╚══════════════════════════════════════════════════╝${RST}"
    echo -e "  ${GRY}$(date '+%Y-%m-%d %H:%M:%S')${RST}"
    echo ""

    echo -e "${BLD}${CYN}[ Public IP & Location ]${RST}"
    _conn_public_info

    echo ""
    echo -e "${BLD}${CYN}[ Local Network ]${RST}"
    _conn_local_info

    local ss_out
    ss_out=$(echo CHANGEME_PASSWORD | sudo -S ss -4 -tunap 2>/dev/null | tail -n +2)

    # Collect local LISTEN ports first to classify connections later as Incoming/Outgoing
    local -a listen_ports=()
    echo ""
    echo -e "${BLD}${CYN}[ Listening (services accepting connections) ]${RST}"
    local found_listen=0
    while read -r netid state recvq sendq local peer proc; do
        [[ "$state" != "LISTEN" ]] && continue
        found_listen=1
        local lport="${local##*:}"
        listen_ports+=("$lport")
        local pname pid
        pname=$(echo "$proc" | grep -oP '\(\("\K[^"]+' | head -1)
        pid=$(echo "$proc"   | grep -oP 'pid=\K[0-9]+' | head -1)
        local tag="green"
        if ! _is_in_array "$lport" "${GHOSTMODE_WHITELIST_LISTEN_PORTS[@]}"; then
            tag="yellow"
        fi
        _conn_print_row "$local" "0.0.0.0/*" "LISTEN" "$pname" "$pid" "$tag"
    done <<< "$ss_out"
    [[ "$found_listen" -eq 0 ]] && echo -e "  ${GRN}✔${RST}  No open listening ports"

    echo ""
    echo -e "${BLD}${CYN}[ Incoming (connections into your device) ]${RST}"
    local found_in=0
    local -a flagged=()
    while read -r netid state recvq sendq local peer proc; do
        [[ "$state" != "ESTAB" ]] && continue
        local lport="${local##*:}"
        _is_in_array "$lport" "${listen_ports[@]}" || continue
        found_in=1
        local pname pid
        pname=$(echo "$proc" | grep -oP '\(\("\K[^"]+' | head -1)
        pid=$(echo "$proc"   | grep -oP 'pid=\K[0-9]+' | head -1)
        local rport="${peer##*:}" ripaddr="${peer%:*}"
        local tag="green"
        if _is_in_array "$rport" "${GHOSTMODE_BAD_PORTS[@]}" || [[ -z "$pname" ]]; then
            tag="red"
        fi
        _conn_print_row "$local" "$peer" "ESTAB" "$pname" "$pid" "$tag"
        [[ "$tag" == "red" ]] && flagged+=("IN|$peer|$ripaddr|$pid|$pname")
    done <<< "$ss_out"
    [[ "$found_in" -eq 0 ]] && echo -e "  ${GRN}✔${RST}  No active incoming connections"

    echo ""
    echo -e "${BLD}${CYN}[ Outgoing (connections from your device) ]${RST}"
    local found_out=0
    while read -r netid state recvq sendq local peer proc; do
        [[ "$state" != "ESTAB" ]] && continue
        local lport="${local##*:}"
        _is_in_array "$lport" "${listen_ports[@]}" && continue
        found_out=1
        local pname pid
        pname=$(echo "$proc" | grep -oP '\(\("\K[^"]+' | head -1)
        pid=$(echo "$proc"   | grep -oP 'pid=\K[0-9]+' | head -1)
        local rport="${peer##*:}" ripaddr="${peer%:*}"
        local tag="green"
        if _is_in_array "$rport" "${GHOSTMODE_BAD_PORTS[@]}" || [[ -z "$pname" ]]; then
            tag="red"
        fi
        _conn_print_row "$local" "$peer" "ESTAB" "$pname" "$pid" "$tag"
        [[ "$tag" == "red" ]] && flagged+=("OUT|$peer|$ripaddr|$pid|$pname")
    done <<< "$ss_out"
    [[ "$found_out" -eq 0 ]] && echo -e "  ${GRN}✔${RST}  No active outgoing connections"

    echo ""
    echo -e "${BLD}${CYN}[ Suspicious / Needs Review ]${RST}"
    if [[ ${#flagged[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  Nothing flagged as suspicious right now"
    else
        echo -e "  ${YLW}Note: these are heuristic indicators, not definitive proof of a compromise.${RST}"
        local item
        for item in "${flagged[@]}"; do
            IFS='|' read -r dir peer ripaddr pid pname <<< "$item"
            echo -e "  ${RED}✘${RST}  [$dir] ${peer} — ${pname:-unknown}${pid:+ (PID $pid)}"
            [[ -n "$pid" ]] && echo -e "       ╰ To kill the process:  ${BLD}ghostmode connections kill $pid${RST}"
            echo -e "       ╰ To block the IP:      ${BLD}ghostmode connections block $ripaddr${RST}"
        done
    fi
    echo ""
    echo -e "${BLD}${BLU}══════════════════════════════════════════════════${RST}"
    echo ""
}

_conn_block() {
    local ip="$1"
    if [[ -z "$ip" ]]; then
        echo "Usage: ghostmode connections block <ip>"
        return 1
    fi
    echo CHANGEME_PASSWORD | sudo -S iptables -A INPUT  -s "$ip" -j DROP 2>/dev/null
    echo CHANGEME_PASSWORD | sudo -S iptables -A OUTPUT -d "$ip" -j DROP 2>/dev/null
    echo -e "  ${GRN}✔${RST}  Blocked ${ip} (INPUT + OUTPUT)"
}

_conn_kill() {
    local pid="$1"
    if [[ -z "$pid" ]]; then
        echo "Usage: ghostmode connections kill <pid>"
        return 1
    fi
    if echo CHANGEME_PASSWORD | sudo -S kill -9 "$pid" 2>/dev/null; then
        echo -e "  ${GRN}✔${RST}  Process ${pid} killed"
    else
        echo -e "  ${RED}✘${RST}  Could not kill process ${pid} (check the PID)"
    fi
}

