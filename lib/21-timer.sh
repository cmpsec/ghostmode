#!/usr/bin/env bash
# shellcheck shell=bash

_timer_normalize() {
    local raw="${1// /}"
    raw="${raw,,}"
    if [[ "$raw" =~ ^([0-9]+)(s|sec|secs|second|seconds)$ ]]; then
        echo "${BASH_REMATCH[1]}s"
    elif [[ "$raw" =~ ^([0-9]+)(m|min|mins|minute|minutes)$ ]]; then
        echo "${BASH_REMATCH[1]}min"
    elif [[ "$raw" =~ ^([0-9]+)(h|hr|hrs|hour|hours)$ ]]; then
        echo "${BASH_REMATCH[1]}h"
    elif [[ "$raw" =~ ^([0-9]+)(d|day|days)$ ]]; then
        echo "${BASH_REMATCH[1]}d"
    else
        return 1
    fi
}

_timer_write_unit() {
    local spec="$1"
    local delay="3min"
    if [[ "$spec" =~ ^([0-9]+)s$ && "${BASH_REMATCH[1]}" -lt 120 ]]; then
        delay="10s"
    elif [[ "$spec" =~ ^([0-9]+)min$ && "${BASH_REMATCH[1]}" -lt 10 ]]; then
        delay="30s"
    fi
    local tmp
    tmp=$(mktemp)
    cat > "$tmp" << EOF
[Unit]
Description=Ghost Mode Timer — every ${spec}

[Timer]
OnBootSec=2min
OnUnitActiveSec=${spec}
AccuracySec=1min
RandomizedDelaySec=${delay}
Persistent=true

[Install]
WantedBy=timers.target
EOF
    _gm_sudo mv "$tmp" /etc/systemd/system/ghostmode-timer.timer
    _gm_sudo chmod 644 /etc/systemd/system/ghostmode-timer.timer
    _gm_sudo systemctl daemon-reload
    _gm_sudo systemctl restart ghostmode-timer.timer
}

cmd_timer() {
    local spec="${1:-}"
    if [[ -z "$spec" ]]; then
        local current="1h"
        [[ -f "$GHOSTMODE_TIMER_INTERVAL_FILE" ]] && IFS= read -r current < "$GHOSTMODE_TIMER_INTERVAL_FILE"
        echo "Auto-clean interval: ${current}"
        echo "Change it with: ghostmode timer 30min    or 2h    or 1d"
        return 0
    fi
    local norm
    if ! norm=$(_timer_normalize "$spec"); then
        echo "Usage: ghostmode timer <interval>    examples: 15min, 2h, 1d"
        return 1
    fi
    mkdir -p "$HOME/.config/ghostmode"
    printf '%s\n' "$norm" > "$GHOSTMODE_TIMER_INTERVAL_FILE"
    if [[ -f /etc/systemd/system/ghostmode-timer.timer ]]; then
        if _timer_write_unit "$norm"; then
            echo -e "  ${GRN}✔${RST}  Auto-clean interval is now ${norm}"
        else
            echo -e "  ${RED}✘${RST}  Saved ${norm}, but the systemd timer was not updated"
            return 1
        fi
    else
        echo -e "  ${YLW}!${RST}  Saved ${norm}. It is applied the next time install.sh writes the timer."
    fi
}
