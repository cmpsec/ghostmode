#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.

# ============================================================
#  DESTROY  (fully removes Ghost Mode from this system)
# ============================================================

cmd_destroy() {
    echo -e "${BLD}${RED}╔══════════════════════════════════════════════════╗${RST}"
    echo -e "${BLD}${RED}║               GHOST MODE — DESTROY              ║${RST}"
    echo -e "${BLD}${RED}╚══════════════════════════════════════════════════╝${RST}"
    echo ""
    echo -e "${YLW}This will permanently:${RST}"
    echo "  - Run one final full cleanup (everything ghostmode status flags right now)"
    echo "  - Stop Tor/anonsurf, remove the kill switch, fingerprint rotation, and the"
    echo "    exempted torbrowser user"
    echo "  - Remove every systemd unit this tool created"
    echo "  - Restore zsh-autosuggestions and GeoClue to their original state"
    echo "  - Delete all Ghost Mode config/state under ~/.config/ghostmode"
    echo "  - Remove the shell aliases it added, if any"
    echo "  - Delete this script itself (~/.local/bin/ghostmode)"
    echo ""
    echo -e "${RED}${BLD}This cannot be undone.${RST}"
    read -rp "Type DESTROY (all caps) to confirm: " confirm
    if [[ "$confirm" != "DESTROY" ]]; then
        echo "Cancelled — nothing was touched."
        return 1
    fi

    echo ""
    echo -e "${BLD}${CYN}[ 1/7 ] Final full cleanup ]${RST}"
    _run_clean

    echo -e "${BLD}${CYN}[ 2/7 ] Stopping Tor / anonsurf / removing the torbrowser user ]${RST}"
    if command -v anonsurf >/dev/null 2>&1; then
        echo CHANGEME_PASSWORD | sudo -S anonsurf stop 2>/dev/null
    fi
    if id -u torbrowser >/dev/null 2>&1; then
        echo CHANGEME_PASSWORD | sudo -S pkill -u torbrowser 2>/dev/null
        echo CHANGEME_PASSWORD | sudo -S userdel -r torbrowser 2>/dev/null
    fi
    echo CHANGEME_PASSWORD | sudo -S iptables -P OUTPUT ACCEPT 2>/dev/null
    echo CHANGEME_PASSWORD | sudo -S iptables -F OUTPUT 2>/dev/null
    echo CHANGEME_PASSWORD | sudo -S iptables -t nat -F OUTPUT 2>/dev/null

    echo -e "${BLD}${CYN}[ 3/7 ] Removing systemd units ]${RST}"
    local unit
    for unit in ghostmode-timer.timer ghostmode-timer.service \
                ghostmode-tor-boot.service ghostmode-killswitch.service \
                ghostmode-fingerprint.service; do
        echo CHANGEME_PASSWORD | sudo -S systemctl disable --now "$unit" 2>/dev/null
        echo CHANGEME_PASSWORD | sudo -S rm -f "/etc/systemd/system/$unit" 2>/dev/null
        systemctl --user disable --now "$unit" 2>/dev/null
        rm -f "$HOME/.config/systemd/user/$unit" 2>/dev/null
    done
    echo CHANGEME_PASSWORD | sudo -S systemctl daemon-reload 2>/dev/null
    systemctl --user daemon-reload 2>/dev/null

    echo -e "${BLD}${CYN}[ 4/7 ] Restoring GeoClue to normal ]${RST}"
    echo CHANGEME_PASSWORD | sudo -S rm -f /etc/geolocation 2>/dev/null
    echo CHANGEME_PASSWORD | sudo -S bash -c '
        CONF=/etc/geoclue/geoclue.conf
        sed -i "/\[static-source\]/,/^\[/ s/^enable=.*/enable=false/" "$CONF" 2>/dev/null
        sed -i "/\[wifi\]/,/^\[/ s/^enable=.*/enable=true/" "$CONF" 2>/dev/null
    ' 2>/dev/null
    echo CHANGEME_PASSWORD | sudo -S systemctl restart geoclue 2>/dev/null

    echo -e "${BLD}${CYN}[ 5/7 ] Restoring zsh-autosuggestions ]${RST}"
    local f
    for f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh.ghostmode-disabled \
             /usr/share/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh.ghostmode-disabled; do
        [[ -f "$f" ]] && echo CHANGEME_PASSWORD | sudo -S mv "$f" "${f%.ghostmode-disabled}" 2>/dev/null
    done

    echo -e "${BLD}${CYN}[ 6/7 ] Removing config, state, and shell aliases ]${RST}"
    rm -rf "$HOME/.config/ghostmode" 2>/dev/null
    local rc
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [[ -f "$rc" ]] && sed -i '/# --- Ghost Mode ---/,+2d' "$rc" 2>/dev/null
    done

    echo -e "${BLD}${CYN}[ 7/7 ] Removing the script itself ]${RST}"
    echo -e "  ${RED}${BLD}[-] Ghost Mode has fully removed itself. Goodbye.${RST}"
    rm -f -- "$HOME/.local/bin/ghostmode"
}

