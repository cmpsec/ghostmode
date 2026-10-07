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

_location_apply() {
    local lat="$1" lon="$2"
    printf "%s\n%s\n%s\n%s\n" "$lat" "$lon" "0.0" "10.0" > /tmp/ghostmode-geolocation
    echo CHANGEME_PASSWORD | sudo -S mv /tmp/ghostmode-geolocation /etc/geolocation
    echo CHANGEME_PASSWORD | sudo -S chmod 644 /etc/geolocation
    echo CHANGEME_PASSWORD | sudo -S bash -c '
        CONF=/etc/geoclue/geoclue.conf
        if ! grep -q "\[static-source\]" "$CONF" 2>/dev/null; then
            printf "\n[static-source]\nenable=true\n" >> "$CONF"
        else
            sed -i "/\[static-source\]/,/^\[/ s/^enable=.*/enable=true/" "$CONF"
        fi
        sed -i "/\[wifi\]/,/^\[/ s/^enable=.*/enable=false/" "$CONF" 2>/dev/null
    ' 2>/dev/null
    echo CHANGEME_PASSWORD | sudo -S systemctl restart geoclue 2>/dev/null
    echo -e "  ${GRN}${BLD}[+] Fake location set: ${lat}, ${lon}${RST}"
    echo -e "  ${GRY}All apps using system location services will now see this instead of the real one.${RST}"
}

_location_off() {
    echo CHANGEME_PASSWORD | sudo -S rm -f /etc/geolocation
    echo CHANGEME_PASSWORD | sudo -S bash -c '
        CONF=/etc/geoclue/geoclue.conf
        sed -i "/\[static-source\]/,/^\[/ s/^enable=.*/enable=false/" "$CONF" 2>/dev/null
        sed -i "/\[wifi\]/,/^\[/ s/^enable=.*/enable=true/" "$CONF" 2>/dev/null
    ' 2>/dev/null
    echo CHANGEME_PASSWORD | sudo -S systemctl restart geoclue 2>/dev/null
    echo -e "  ${RED}[-] Real location restored.${RST}"
}

