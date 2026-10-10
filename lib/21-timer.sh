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

# NextElapseUSecRealtime is empty or 0 while the oneshot is running, and
# unprivileged systemctl show sometimes returns nothing for a system timer.
# Fall back to the last trigger plus the saved interval so the line always
# carries a time when one can be calculated.
_timer_next_text() {
    local scope="$1"
    local show=(systemctl)
    [[ "$scope" == "user" ]] && show=(systemctl --user)

    local next=""
    next=$("${show[@]}" show ghostmode-timer.timer -p NextElapseUSecRealtime --value 2>/dev/null || true)
    next="${next//$'\r'/}"
    next="${next//$'\n'/}"
    next="${next#"${next%%[![:space:]]*}"}"
    next="${next%"${next##*[![:space:]]}"}"
    if [[ "$scope" == "system" && ( -z "$next" || "$next" == "0" || "$next" == "n/a" || "$next" == "infinity" ) ]]; then
        next=$(_gm_sudo systemctl show ghostmode-timer.timer -p NextElapseUSecRealtime --value 2>/dev/null || true)
        next="${next//$'\r'/}"
        next="${next//$'\n'/}"
        next="${next#"${next%%[![:space:]]*}"}"
        next="${next%"${next##*[![:space:]]}"}"
    fi
    if [[ -n "$next" && "$next" != "0" && "$next" != "n/a" && "$next" != "infinity" ]]; then
        printf '%s\n' "$next"
        return 0
    fi

    local line=""
    if [[ "$scope" == "user" ]]; then
        line=$(systemctl --user list-timers --all ghostmode-timer.timer --no-legend --no-pager 2>/dev/null | head -n 1 || true)
    else
        line=$(systemctl list-timers --all ghostmode-timer.timer --no-legend --no-pager 2>/dev/null | head -n 1 || true)
    fi
    if [[ "$line" =~ ^([A-Za-z]{3}[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+[0-9:]{8}[[:space:]]+[^[:space:]]+) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi

    local interval="1h" rel="" last_rt="" active="" est=""
    [[ -f "$GHOSTMODE_TIMER_INTERVAL_FILE" ]] && IFS= read -r interval < "$GHOSTMODE_TIMER_INTERVAL_FILE"
    if [[ "$interval" =~ ^([0-9]+)s$ ]]; then
        rel="${BASH_REMATCH[1]} seconds"
    elif [[ "$interval" =~ ^([0-9]+)min$ ]]; then
        rel="${BASH_REMATCH[1]} minutes"
    elif [[ "$interval" =~ ^([0-9]+)h$ ]]; then
        rel="${BASH_REMATCH[1]} hours"
    elif [[ "$interval" =~ ^([0-9]+)d$ ]]; then
        rel="${BASH_REMATCH[1]} days"
    fi
    last_rt=$("${show[@]}" show ghostmode-timer.timer -p LastTriggerUSecRealtime --value 2>/dev/null || true)
    last_rt="${last_rt//$'\n'/}"
    active=$("${show[@]}" is-active ghostmode-timer.service 2>/dev/null || true)
    if [[ -n "$rel" && -n "$last_rt" && "$last_rt" != "n/a" && "$last_rt" != "0" ]]; then
        est=$(date -d "$last_rt + $rel" '+%a %Y-%m-%d %H:%M:%S %z' 2>/dev/null || true)
        if [[ -n "$est" ]]; then
            if [[ "$active" == "activating" || "$active" == "active" ]]; then
                printf '%s\n' "${est} (about ${interval} after this run)"
            else
                printf '%s\n' "~ ${est}"
            fi
            return 0
        fi
    fi
    if [[ -n "$rel" ]]; then
        printf '%s\n' "within ${interval} of the timer arming"
        return 0
    fi
    printf '%s\n' "not scheduled"
}
