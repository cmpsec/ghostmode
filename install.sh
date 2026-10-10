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
step "1/8  Checking dependencies"
umask 077
mkdir -p "$HOME/.config/ghostmode"
chmod 700 "$HOME/.config/ghostmode"
MANIFEST="$HOME/.config/ghostmode/installed.manifest"
touch "$MANIFEST"
chmod 600 "$MANIFEST"
PKG_BEFORE=$(mktemp)
PKG_AFTER=$(mktemp)
dpkg-query -W -f '${Package}\n' 2>/dev/null | sort -u > "$PKG_BEFORE"

_apt_quiet() {
    DEBIAN_FRONTEND=noninteractive \
        echo "$LAPTOP_PASS" | sudo -S -p '' apt-get "$@" -o Dpkg::Use-Pty=0 -qq >/dev/null 2>&1
}

_dep_bar() {
    local cur="$1" total="$2" label="$3"
    local width=24 filled empty bar pad
    filled=$(( cur * width / total ))
    empty=$(( width - filled ))
    printf -v bar '%*s' "$filled" ''
    bar=${bar// /#}
    printf -v pad '%*s' "$empty" ''
    printf '\r  \033[0;36m[%s%s]\033[0m %2d/%d  %-28s' "$bar" "$pad" "$cur" "$total" "$label"
}

DEP_PKGS=(
    curl ca-certificates git iproute2 iptables pciutils ffmpeg
    libimage-exiftool-perl mat2 tor geoclue-2.0 torbrowser-launcher
    x11-xserver-utils network-manager procps e2fsprogs gnupg fakeroot xz-utils
)
DEP_TOTAL=$(( ${#DEP_PKGS[@]} + 2 ))
DEP_FAIL=()
DEP_I=0
NEED_UPDATE=0
for pkg in "${DEP_PKGS[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        NEED_UPDATE=1
        break
    fi
done
if [[ "$NEED_UPDATE" -eq 1 ]] || ! dpkg -s kali-anonsurf >/dev/null 2>&1; then
    _apt_quiet update || true
fi
for pkg in "${DEP_PKGS[@]}"; do
    DEP_I=$(( DEP_I + 1 ))
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        _dep_bar "$DEP_I" "$DEP_TOTAL" "$pkg"
        continue
    fi
    _dep_bar "$DEP_I" "$DEP_TOTAL" "$pkg"
    if ! _apt_quiet install -y "$pkg"; then
        DEP_FAIL+=("$pkg")
    fi
done

DEP_I=$(( DEP_I + 1 ))
_dep_bar "$DEP_I" "$DEP_TOTAL" "anonsurf"
if ! command -v anonsurf >/dev/null 2>&1; then
    BUILD_DIR=$(mktemp -d /tmp/gm-anonsurf.XXXXXX)
    if git clone --depth 1 -q https://github.com/Und3rf10w/kali-anonsurf.git "$BUILD_DIR/kali-anonsurf" 2>/dev/null; then
        chmod +x "$BUILD_DIR/kali-anonsurf/installer.sh"
        echo "$LAPTOP_PASS" | sudo -S -p '' bash "$BUILD_DIR/kali-anonsurf/installer.sh" >/dev/null 2>&1 \
            || DEP_FAIL+=("anonsurf")
    else
        DEP_FAIL+=("anonsurf")
    fi
    rm -rf "$BUILD_DIR"
fi

DEP_I=$(( DEP_I + 1 ))
_dep_bar "$DEP_I" "$DEP_TOTAL" "Tor Browser"
TB_BIN="$HOME/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/start-tor-browser"
TB_MARK="$HOME/.config/ghostmode/torbrowser.installed"
if [[ ! -x "$TB_BIN" ]]; then
    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64|arm64) TB_MAR=Linux_aarch64-gcc3; TB_NAME=linux-aarch64 ;;
        *) TB_MAR=Linux_x86_64-gcc3; TB_NAME=linux-x86_64 ;;
    esac
    TB_XML=$(curl -fsSL --max-time 40 "https://aus1.torproject.org/torbrowser/update_3/release/${TB_MAR}/x/ALL" 2>/dev/null || true)
    TB_VER=$(printf '%s\n' "$TB_XML" | sed -n 's/.*appVersion="\([^"]*\)".*/\1/p' | head -n 1)
    if [[ -n "$TB_VER" ]]; then
        TB_URL="https://dist.torproject.org/torbrowser/${TB_VER}/tor-browser-${TB_NAME}-${TB_VER}.tar.xz"
        TB_TMP=$(mktemp -d /tmp/gm-tbb.XXXXXX)
        if curl -fsSL --retry 2 --max-time 300 -o "$TB_TMP/tbb.tar.xz" "$TB_URL" 2>/dev/null \
            && curl -fsSL --max-time 40 -o "$TB_TMP/tbb.tar.xz.asc" "${TB_URL}.asc" 2>/dev/null; then
            TB_KEY=""
            for k in /usr/share/torbrowser-launcher/tor-browser-developers.asc \
                     /usr/share/torbrowser-launcher/signing-keys/*.asc; do
                [[ -f "$k" ]] && TB_KEY=$k && break
            done
            TB_OK=0
            if [[ -n "$TB_KEY" ]]; then
                TB_GNUPG=$(mktemp -d /tmp/gm-gpg.XXXXXX)
                if GNUPGHOME="$TB_GNUPG" gpg --batch --import "$TB_KEY" >/dev/null 2>&1 \
                    && GNUPGHOME="$TB_GNUPG" gpg --batch --verify "$TB_TMP/tbb.tar.xz.asc" "$TB_TMP/tbb.tar.xz" >/dev/null 2>&1; then
                    TB_OK=1
                fi
                rm -rf "$TB_GNUPG"
            elif xz -t "$TB_TMP/tbb.tar.xz" >/dev/null 2>&1; then
                TB_OK=1
            fi
            if [[ "$TB_OK" -eq 1 ]]; then
                mkdir -p "$HOME/.local/share/torbrowser/tbb/x86_64"
                tar -xJf "$TB_TMP/tbb.tar.xz" -C "$HOME/.local/share/torbrowser/tbb/x86_64" \
                    && printf '1\n' > "$TB_MARK"
            else
                DEP_FAIL+=("torbrowser")
            fi
        else
            DEP_FAIL+=("torbrowser")
        fi
        rm -rf "$TB_TMP"
    else
        DEP_FAIL+=("torbrowser")
    fi
fi
printf '\n'
dpkg-query -W -f '${Package}\n' 2>/dev/null | sort -u > "$PKG_AFTER"
NEW_PKGS=$(comm -13 "$PKG_BEFORE" "$PKG_AFTER" || true)
if [[ -n "$NEW_PKGS" ]]; then
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] || continue
        grep -qx "pkg:${pkg}" "$MANIFEST" 2>/dev/null || printf 'pkg:%s\n' "$pkg" >> "$MANIFEST"
    done <<< "$NEW_PKGS"
fi
[[ -f "$TB_MARK" ]] && grep -qx 'extra:torbrowser-bundle' "$MANIFEST" 2>/dev/null \
    || { [[ -f "$TB_MARK" ]] && printf 'extra:torbrowser-bundle\n' >> "$MANIFEST"; }
rm -f "$PKG_BEFORE" "$PKG_AFTER"
if [[ ${#DEP_FAIL[@]} -eq 0 ]]; then
    ok "Dependencies ready"
else
    echo -e "  ${YLW}!${RST} Still missing: ${DEP_FAIL[*]}"
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
# shellcheck source=lib/17-extra.sh
source "$DEST_LIB/17-extra.sh"
_documents_prevent || true
_telemetry_quiet || true

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
