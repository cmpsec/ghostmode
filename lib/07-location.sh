#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.

# ============================================================
#  FAKE LOCATION  (GeoClue2 static-source)
# ============================================================

cmd_location() {
    case "${1:-}" in
        fake)   shift; _location_fake "$@" ;;
        random) _location_random ;;
        off)    _location_off ;;
        *)      echo "Usage: ghostmode location [fake <lat> <lon>|random|off]" ;;
    esac
}

_location_fake() {
    local lat="$1" lon="$2"
    if [[ -z "$lat" || -z "$lon" ]]; then
        echo "Usage: ghostmode location fake <lat> <lon>"
        return 1
    fi
    _location_apply "$lat" "$lon"
}

_location_random() {
    local lat lon
    lat=$(awk -v s="$RANDOM" 'BEGIN{srand(s); printf "%.4f", (rand()*180)-90}')
    lon=$(awk -v s="$RANDOM$RANDOM" 'BEGIN{srand(s); printf "%.4f", (rand()*360)-180}')
    _location_apply "$lat" "$lon"
}

_geoclue_set() {
    local static_enable="$1" wifi_enable="$2"
    local conf=/etc/geoclue/geoclue.conf
    [[ -f "$conf" ]] || return 0
    if ! _gm_sudo grep -q '\[static-source\]' "$conf"; then
        printf '\n[static-source]\nenable=%s\n' "$static_enable" | _gm_sudo tee -a "$conf" >/dev/null
    else
        _gm_sudo sed -i "/\\[static-source\\]/,/^\\[/ s/^enable=.*/enable=${static_enable}/" "$conf"
    fi
    _gm_sudo sed -i "/\\[wifi\\]/,/^\\[/ s/^enable=.*/enable=${wifi_enable}/" "$conf"
}

_location_apply() {
    local lat="$1" lon="$2"
    printf "%s\n%s\n%s\n%s\n" "$lat" "$lon" "0.0" "10.0" > /tmp/ghostmode-geolocation
    _gm_sudo mv /tmp/ghostmode-geolocation /etc/geolocation
    _gm_sudo chmod 644 /etc/geolocation
    _geoclue_set true false
    _gm_sudo systemctl restart geoclue 2>/dev/null || true
    echo -e "  ${GRN}${BLD}[+] Fake location set: ${lat}, ${lon}${RST}"
    echo -e "  ${GRY}All apps using system location services will now see this instead of the real one.${RST}"
}

_location_off() {
    _gm_sudo rm -f /etc/geolocation
    _geoclue_set false true
    _gm_sudo systemctl restart geoclue 2>/dev/null || true
    echo -e "  ${RED}[-] Real location restored.${RST}"
}

