#!/usr/bin/env bash
# Ghost Mode — Full laptop setup (Kali) — interactive, step by step
# Run: ./full-setup.sh   (from inside the ghostmode-pack folder)

BOLD='\033[1m'; GRN='\033[0;32m'; RED='\033[0;31m'; YLW='\033[1;33m'; CYN='\033[0;36m'; RST='\033[0m'

step() { echo -e "\n${BOLD}${CYN}==> $1${RST}"; }
ok()   { echo -e "  ${GRN}✔${RST} $1"; }
fail() { echo -e "  ${RED}✘${RST} $1"; exit 1; }

DEST_BIN="$HOME/.local/bin"
DEST_SYSD="$HOME/.config/systemd/user"
UPGRADE=0
[[ -x "$DEST_BIN/ghostmode" ]] && UPGRADE=1

echo -e "${BOLD}Ghost Mode — Full Setup${RST}"
if [[ "$UPGRADE" -eq 1 ]]; then
    echo "Existing installation detected — this will UPDATE it to the latest version."
else
    echo "This installs the tool + the auto-cleanup timer + customizes the script for this machine."
fi
echo ""

# ---------- Collect info ----------
read -rp "Username on this laptop [default: $USER]: " LAPTOP_USER
LAPTOP_USER="${LAPTOP_USER:-$USER}"

read -rsp "sudo password for this user: " LAPTOP_PASS
echo ""
[[ -z "$LAPTOP_PASS" ]] && fail "Password is required, run again"

step "Verifying the password"
if echo "$LAPTOP_PASS" | sudo -S -k true 2>/dev/null; then
    ok "Password correct"
else
    fail "Incorrect password"
fi

# ---------- Summary and confirmation ----------
echo ""
echo -e "${BOLD}Summary before running:${RST}"
echo "  • User: $LAPTOP_USER"
if [[ "$UPGRADE" -eq 1 ]]; then
    echo "  • Mode: UPDATE — overwrites ~/.local/bin/ghostmode, keeps your saved state"
    echo "    (cleanup log, Tor on/off state) untouched"
else
    echo "  • Script will be copied to: ~/.local/bin/ghostmode (customized for this machine)"
fi
echo "  • systemd timer: low priority, interval chosen below (default 1 hour)"
echo "  • sudo password: saved once in ~/.config/ghostmode/sudo.pass (mode 600)"
echo "    so the timer and later commands do not ask for it again"
echo "  • lingering: enabled so the timer runs even without an open session"
echo ""
read -rp "Proceed? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && fail "Cancelled by user"

PACK_DIR="$(dirname "$(realpath "$0")")"
BIN_SRC="$PACK_DIR/bin/ghostmode"
LIB_SRC="$PACK_DIR/lib"
DEST_LIB="$HOME/.local/share/ghostmode/lib"

[[ -f "$BIN_SRC" ]] || fail "bin/ghostmode not found — make sure you're running this from inside the project folder"
[[ -d "$LIB_SRC" ]] || fail "lib/ not found — make sure you're running this from inside the project folder"

# ---------- 1/8: Dependencies ----------
step "1/8  Checking dependencies, installing anything missing"
NEED_PKGS=()
command -v curl     >/dev/null 2>&1 || NEED_PKGS+=("curl")
command -v ss       >/dev/null 2>&1 || NEED_PKGS+=("iproute2")
command -v iptables >/dev/null 2>&1 || NEED_PKGS+=("iptables")
command -v lspci    >/dev/null 2>&1 || NEED_PKGS+=("pciutils")
if [[ ${#NEED_PKGS[@]} -eq 0 ]]; then
    ok "All dependencies already present"
else
    echo "  Installing: ${NEED_PKGS[*]}"
    echo "$LAPTOP_PASS" | sudo -S apt-get update -qq 2>/dev/null
    echo "$LAPTOP_PASS" | sudo -S apt-get install -y "${NEED_PKGS[@]}" 2>/dev/null \
        && ok "Installed: ${NEED_PKGS[*]}" \
        || echo -e "  ${YLW}!${RST} Some failed to install — you can install them manually later"
fi

# ---------- 2/8: Install entry point + modules ----------
step "2/8  Installing Ghost Mode"
mkdir -p "$DEST_BIN" "$DEST_LIB"
# Saved once, on this machine only. Not written into the git checkout.
_old_umask=$(umask)
umask 077
mkdir -p "$HOME/.config/ghostmode"
printf '%s\n' "$LAPTOP_PASS" > "$HOME/.config/ghostmode/sudo.pass"
chmod 700 "$HOME/.config/ghostmode"
chmod 600 "$HOME/.config/ghostmode/sudo.pass"
umask "$_old_umask"
unset _old_umask
ok "Password saved for automatic sudo — you will not be asked again"
cp -a "$LIB_SRC"/*.sh "$DEST_LIB/"
ok "Installed $(ls "$DEST_LIB" | wc -l) modules to $DEST_LIB"

sed -e "s|GHOSTMODE_LIB_DIR:-.*}\"|GHOSTMODE_LIB_DIR:-$DEST_LIB}\"|" \
    "$BIN_SRC" > "$DEST_BIN/ghostmode"
chmod +x "$DEST_BIN/ghostmode"
ok "Done: $DEST_BIN/ghostmode"

step "Installing the privileged helper (fallback if the saved password file is removed)"
echo "$LAPTOP_PASS" | sudo -S install -m 755 -o root -g root \
    "$PACK_DIR/bin/ghostmode-priv" /usr/local/libexec/ghostmode-priv
SUDOERS_TMP=$(mktemp)
printf '%s\n' \
    "# Ghost Mode — removed by ghostmode destroy." \
    "${LAPTOP_USER} ALL=(root) NOPASSWD: /usr/local/libexec/ghostmode-priv" \
    > "$SUDOERS_TMP"
if echo "$LAPTOP_PASS" | sudo -S visudo -cf "$SUDOERS_TMP" >/dev/null; then
    echo "$LAPTOP_PASS" | sudo -S install -m 440 -o root -g root "$SUDOERS_TMP" /etc/sudoers.d/ghostmode
    ok "sudoers drop-in installed"
else
    rm -f "$SUDOERS_TMP"
    fail "sudoers check failed — nothing was installed to /etc/sudoers.d"
fi
rm -f "$SUDOERS_TMP"

# ---------- 3/8: systemd units (system-level, not --user) ----------
step "3/8  Installing systemd units (power-saving settings, system-level for reliability)"
# System-level + multi-user.target is used instead of a --user unit so the
# timer is guaranteed to start on every boot regardless of the user's
# systemd/D-Bus session coming up cleanly via lingering — that extra
# dependency is what made boot-time persistence unreliable before.
cat > /tmp/ghostmode-timer.service << UNIT
[Unit]
Description=Ghost Mode — Auto Privacy Cleaner
After=multi-user.target

[Service]
Type=oneshot
User=${LAPTOP_USER}
# --- power/battery load reduction ---
Nice=19
IOSchedulingClass=idle
CPUSchedulingPolicy=idle
CPUQuota=15%
MemoryMax=200M
# settle delay: keeps a missed-run catch-up (Persistent=true) from firing
# immediately at boot, giving the system time to settle first
ExecStartPre=/bin/sleep 30
# -------------------------------------
ExecStart=${DEST_BIN}/ghostmode auto
StandardOutput=null
StandardError=journal
RemainAfterExit=no
UNIT
# shellcheck source=lib/01-globals.sh
source "$DEST_LIB/01-globals.sh"
# shellcheck source=lib/21-timer.sh
source "$DEST_LIB/21-timer.sh"
read -rp "Auto-clean interval [default: 1h] (examples: 30min, 2h, 1d): " CLEAN_EVERY
CLEAN_EVERY="${CLEAN_EVERY:-1h}"
if ! TIMER_SPEC=$(_timer_normalize "$CLEAN_EVERY"); then
    fail "Interval not understood. Use 30min, 2h, or 1d"
fi
mkdir -p "$HOME/.config/ghostmode"
printf '%s\n' "$TIMER_SPEC" > "$HOME/.config/ghostmode/timer.interval"
TIMER_DELAY=3min
if [[ "$TIMER_SPEC" =~ ^([0-9]+)min$ && "${BASH_REMATCH[1]}" -lt 10 ]]; then
    TIMER_DELAY=30s
fi
cat > /tmp/ghostmode-timer.timer << EOF
[Unit]
Description=Ghost Mode Timer — every ${TIMER_SPEC}

[Timer]
OnBootSec=2min
OnUnitActiveSec=${TIMER_SPEC}
AccuracySec=1min
RandomizedDelaySec=${TIMER_DELAY}
Persistent=true

[Install]
WantedBy=timers.target
EOF
echo "$LAPTOP_PASS" | sudo -S mv /tmp/ghostmode-timer.service /tmp/ghostmode-timer.timer /etc/systemd/system/
echo "$LAPTOP_PASS" | sudo -S chown root:root /etc/systemd/system/ghostmode-timer.service /etc/systemd/system/ghostmode-timer.timer
ok "Installed to /etc/systemd/system/"

# Clean up an older --user unit from a previous version, if present
if [[ -f "$DEST_SYSD/ghostmode-timer.service" ]]; then
    systemctl --user disable --now ghostmode-timer.timer 2>/dev/null
    rm -f "$DEST_SYSD/ghostmode-timer.service" "$DEST_SYSD/ghostmode-timer.timer"
    systemctl --user daemon-reload 2>/dev/null
    ok "Removed the older --user timer unit"
fi

# ---------- 4/8: Enable the timer ----------
step "4/8  Enabling and starting the timer"
echo "$LAPTOP_PASS" | sudo -S systemctl daemon-reload
echo "$LAPTOP_PASS" | sudo -S systemctl enable --now ghostmode-timer.timer
ok "Timer enabled (${TIMER_SPEC})"

# ---------- 5/8: lingering ----------
step "5/8  Enabling lingering (runs without an open session)"
if loginctl show-user "$LAPTOP_USER" 2>/dev/null | grep -q 'Linger=yes'; then
    ok "Lingering already enabled"
else
    echo "$LAPTOP_PASS" | sudo -S loginctl enable-linger "$LAPTOP_USER" \
        && ok "Lingering enabled" \
        || fail "Failed to enable lingering"
fi

# ---------- 6/8 (extra): zsh-autosuggestions ----------
step "Disabling the 'show previous commands as you type' feature (zsh-autosuggestions)"
# Repair any .zshrc broken by an older buggy version of this fix (it used to
# comment out the "if [ -f .../zsh-autosuggestions.zsh ]; then" line too,
# since that path also contains the word "zsh-autosuggestions", leaving a
# dangling "fi" and breaking the shell with a parse error).
if [[ -f "$HOME/.zshrc" ]] && grep -qE '^#[[:space:]]*.*zsh-autosuggestions' "$HOME/.zshrc" 2>/dev/null; then
    sed -i -E '/^#[[:space:]]*.*zsh-autosuggestions/ s/^#[[:space:]]*//' "$HOME/.zshrc"
    ok "Repaired a broken .zshrc from an older version of this fix"
fi
# Current method: disable by renaming the actual plugin file instead of
# touching .zshrc at all — safe regardless of how the if/then/fi is written.
AS_DISABLED=0
for f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
         /usr/share/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh; do
    if [[ -f "$f" ]]; then
        echo "$LAPTOP_PASS" | sudo -S mv "$f" "${f}.ghostmode-disabled" 2>/dev/null
        AS_DISABLED=1
    fi
done
if [[ "$AS_DISABLED" -eq 1 ]]; then
    ok "Disabled"
else
    ok "Already disabled / not installed"
fi

# shellcheck source=lib/14-history.sh
source "$DEST_LIB/14-history.sh"
_history_write_guard
_history_save_sizes
_history_ensure_zshrc_line
ok "Shell history guard installed. New terminals will not record commands."

CORE_TMP=$(mktemp)
printf '%s\n' '* hard core 0' > "$CORE_TMP"
echo "$LAPTOP_PASS" | sudo -S install -m 644 -o root -g root "$CORE_TMP" /etc/security/limits.d/ghostmode-nocore.conf
rm -f "$CORE_TMP"
ok "Core dumps disabled for new logins"

WIFI_TMP=$(mktemp)
printf '%s\n' '[device]' 'wifi.scan-rand-mac-address=yes' > "$WIFI_TMP"
echo "$LAPTOP_PASS" | sudo -S install -m 644 -o root -g root "$WIFI_TMP" /etc/NetworkManager/conf.d/ghostmode-wifi-rand.conf
rm -f "$WIFI_TMP"
ok "Wi-Fi scan MAC randomization drop-in installed"

# ---------- 6/8: Tor (optional) ----------
step "6/8  Tor — full anonymity for all device connections (optional)"
if [[ "$UPGRADE" -eq 1 && -f "$HOME/.config/ghostmode/tor_state" ]] \
   && [[ "$(cat "$HOME/.config/ghostmode/tor_state" 2>/dev/null)" == "on" ]]; then
    echo "  Tor was already ON before this update — refreshing it with the latest fixes"
    "$DEST_BIN/ghostmode" tor on
else
    read -rp "Enable Tor now for all connections? (y/n): " ENABLE_TOR
    if [[ "$ENABLE_TOR" == "y" || "$ENABLE_TOR" == "Y" ]]; then
        "$DEST_BIN/ghostmode" tor on
    else
        ok "Skipped — enable later with: ghostmode tor on"
    fi
fi

# ---------- 7/8: Optional shell alias ----------
step "7/8  Adding command shortcuts to ~/.bashrc or ~/.zshrc (optional)"
read -rp "Add 'ghostmode' and 'gs' aliases to your shell config? (y/n): " ADD_ALIAS
if [[ "$ADD_ALIAS" == "y" || "$ADD_ALIAS" == "Y" ]]; then
    SHRC="$HOME/.bashrc"
    [[ -n "$ZSH_VERSION" || -f "$HOME/.zshrc" ]] && SHRC="$HOME/.zshrc"
    if ! grep -q "alias ghostmode=" "$SHRC" 2>/dev/null; then
        {
            echo ""
            echo "# --- Ghost Mode ---"
            echo "alias ghostmode=\"\$HOME/.local/bin/ghostmode\""
            echo "alias gs='ghostmode status'"
        } >> "$SHRC"
        ok "Added to $SHRC (activate with: source $SHRC)"
    else
        ok "Already present in $SHRC"
    fi
else
    ok "Skipped — use the full path: ~/.local/bin/ghostmode"
fi

# ---------- 8/9: Smoke test ----------
step "8/9  Running a quick check to confirm everything works"
if [[ ! -x "$DEST_BIN/ghostmode" ]]; then
    fail "Installation incomplete — $DEST_BIN/ghostmode not found or not executable"
fi
"$DEST_BIN/ghostmode" status | head -15
echo "  ..."
echo ""
systemctl list-timers ghostmode-timer.timer --no-pager
ok "Installation working — ~/.local/bin/ghostmode is now the active copy"

# ---------- 9/9: Delete the original install source (leave no trace) ----------
step "9/9  Deleting the original source folder (where this script was run from)"
echo -e "  ${YLW}This will permanently delete: $PACK_DIR${RST}"
echo "  (the real script now lives at ~/.local/bin/ghostmode — this folder is no longer needed)"
read -rp "  Confirm permanent deletion? This cannot be undone (y/n): " CONFIRM_WIPE
if [[ "$CONFIRM_WIPE" == "y" || "$CONFIRM_WIPE" == "Y" ]]; then
    # Safety checks against deleting the wrong path by mistake
    if [[ -z "$PACK_DIR" || "$PACK_DIR" == "$HOME" || "$PACK_DIR" == "/" \
          || "$PACK_DIR" == "/home" || "$PACK_DIR" == "$HOME/" ]]; then
        echo -e "  ${RED}✘${RST}  Unsafe path to delete — skipped this step to protect you"
    elif [[ ! -f "$DEST_BIN/ghostmode" ]]; then
        echo -e "  ${RED}✘${RST}  Installation not confirmed — will not delete the source"
    else
        cd "$HOME" || exit 1
        rm -rf -- "$PACK_DIR"
        ok "Deleted $PACK_DIR permanently — no trace of the original source left"
    fi
else
    ok "Kept the original folder at: $PACK_DIR (delete it manually later if you want)"
fi

echo ""
echo -e "${GRN}${BOLD}[+] Setup finished.${RST}"
echo -e "  ${YLW}This is not 100% protection. The router, ISP, cloud accounts, firmware, and SSD spare area stay out of reach.${RST}"
echo -e "  Commands: ${BOLD}ghostmode${RST} | ${BOLD}ghostmode status${RST} | ${BOLD}ghostmode delete${RST} | ${BOLD}ghostmode help${RST}"
echo ""

unset LAPTOP_PASS
