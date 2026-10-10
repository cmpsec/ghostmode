#!/usr/bin/env bash
# shellcheck shell=bash
# Shell-history root wipe and the zsh guard. There is no on/off command.

_history_write_guard() {
    mkdir -p "$HOME/.config/ghostmode"
    cat > "$GHOSTMODE_HISTORY_GUARD" << 'GUARD'
# Sourced while Ghost Mode is installed. ghostmode destroy removes this
# only after on-disk history has been emptied.
[[ -o interactive ]] || return 0

export HISTFILE=/dev/null
HISTSIZE=0
SAVEHIST=0
setopt NO_INC_APPEND_HISTORY
setopt NO_SHARE_HISTORY
setopt NO_APPEND_HISTORY
setopt HIST_NO_STORE
setopt HIST_IGNORE_SPACE

zshaddhistory() { return 1 }

if (( ${+ZSH_AUTOSUGGEST_STRATEGY} )) || (( ${+functions[_zsh_autosuggest_start]} )); then
    ZSH_AUTOSUGGEST_STRATEGY=()
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=0
fi

_gm_hist_gen_file="${HOME}/.config/ghostmode/history.generation"
_gm_hist_seen=-1

precmd_ghostmode_history() {
    setopt NO_INC_APPEND_HISTORY NO_SHARE_HISTORY NO_APPEND_HISTORY HIST_NO_STORE
    HISTFILE=/dev/null
    HISTSIZE=0
    SAVEHIST=0
    if (( ${+ZSH_AUTOSUGGEST_STRATEGY} )); then
        ZSH_AUTOSUGGEST_STRATEGY=()
        ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=0
    fi
    local gen=0
    [[ -r "$_gm_hist_gen_file" ]] && IFS= read -r gen < "$_gm_hist_gen_file"
    [[ "$gen" == <-> ]] || gen=0
    if (( gen != _gm_hist_seen )); then
        _gm_hist_seen=$gen
        HISTSIZE=0
        SAVEHIST=0
    fi
}

autoload -Uz add-zsh-hook 2>/dev/null
add-zsh-hook precmd precmd_ghostmode_history 2>/dev/null
GUARD
    chmod 644 "$GHOSTMODE_HISTORY_GUARD"
}

_history_save_sizes() {
    mkdir -p "$HOME/.config/ghostmode"
    [[ -f "$GHOSTMODE_HISTORY_SAVED" ]] && return 0
    local histsize=1000 savehist=2000 raw
    if [[ -f "$HOME/.zshrc" ]]; then
        raw=$(sed -n 's/^[[:space:]]*HISTSIZE=//p' "$HOME/.zshrc" | head -1)
        raw="${raw%%#*}"
        raw="${raw// /}"
        [[ "$raw" =~ ^[0-9]+$ ]] && histsize="$raw"
        raw=$(sed -n 's/^[[:space:]]*SAVEHIST=//p' "$HOME/.zshrc" | head -1)
        raw="${raw%%#*}"
        raw="${raw// /}"
        [[ "$raw" =~ ^[0-9]+$ ]] && savehist="$raw"
    fi
    umask 077
    printf 'HISTSIZE=%s\nSAVEHIST=%s\n' "$histsize" "$savehist" > "$GHOSTMODE_HISTORY_SAVED"
    chmod 600 "$GHOSTMODE_HISTORY_SAVED"
}

_history_ensure_zshrc_line() {
    # Single quotes on purpose: zsh expands $HOME when the line runs, not bash.
    # shellcheck disable=SC2016
    local line='source "$HOME/.config/ghostmode/history-guard.zsh" # ghostmode-history-guard'
    local zshrc="$HOME/.zshrc"
    touch "$zshrc"
    if grep -qF "$GHOSTMODE_GUARD_MARK" "$zshrc" 2>/dev/null; then
        return 0
    fi
    local tmp
    tmp=$(mktemp)
    local placed=0
    while IFS= read -r row || [[ -n "$row" ]]; do
        if [[ "$placed" -eq 0 && "$row" =~ ^[[:space:]]*(HISTFILE=|HISTSIZE=|SAVEHIST=|setopt[[:space:]].*hist|if[[:space:]].*zsh-autosuggestions) ]]; then
            printf '%s\n' "$line" >> "$tmp"
            placed=1
        fi
        printf '%s\n' "$row" >> "$tmp"
    done < "$zshrc"
    if [[ "$placed" -eq 0 ]]; then
        printf '%s\n' "$line" | cat - "$tmp" > "${tmp}.2"
        mv "${tmp}.2" "$tmp"
    fi
    mv "$tmp" "$zshrc"
    unset insert_at
}

_history_disable_autosuggest() {
    local f
    for f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
             /usr/share/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh; do
        if [[ -f "$f" ]]; then
            _gm_sudo mv "$f" "${f}.ghostmode-disabled" || return 1
        fi
    done
    return 0
}

_history_plugin_active() {
    local f
    for f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
             /usr/share/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh; do
        [[ -f "$f" ]] && return 0
    done
    return 1
}

_history_unlock_files() {
    local f
    for f in "$HOME/.zsh_history" "$HOME/.bash_history"; do
        [[ -e "$f" ]] || continue
        chattr -i "$f" 2>/dev/null || _gm_sudo chattr -i "$f" 2>/dev/null || true
    done
}

_history_empty_one() {
    local f="$1"
    [[ -e "$f" || "$2" == "create" ]] || return 0
    if [[ -f "$f" || "$2" == "create" ]]; then
        : > "$f" 2>/dev/null || return 1
    elif [[ -d "$f" ]]; then
        find "$f" -mindepth 1 -delete 2>/dev/null || return 1
    fi
    return 0
}

_history_bump_and_wipe() {
    _history_write_guard
    _history_save_sizes
    _history_ensure_zshrc_line
    mkdir -p "$(dirname "$GHOSTMODE_HISTORY_GENERATION")"
    local gen=0
    if [[ -f "$GHOSTMODE_HISTORY_GENERATION" ]]; then
        IFS= read -r gen < "$GHOSTMODE_HISTORY_GENERATION" || gen=0
    fi
    [[ "$gen" =~ ^[0-9]+$ ]] || gen=0
    gen=$((gen + 1))
    printf '%s\n' "$gen" > "$GHOSTMODE_HISTORY_GENERATION"
    chmod 600 "$GHOSTMODE_HISTORY_GENERATION" 2>/dev/null || true

    _history_unlock_files

    local f
    for f in "$HOME/.zsh_history" "$HOME/.bash_history"; do
        : > "$f" 2>/dev/null || {
            _GM_STEP_MSG="could not empty ${f/#$HOME/\~}"
            return 1
        }
    done

    local extra
    shopt -s nullglob
    for extra in "$HOME"/.zsh_history.* "$HOME"/.bash_history.* \
                 "$HOME"/.zhistory "$HOME"/.zcompdump "$HOME"/.zcompdump-* \
                 "$HOME/.local/share/fish/fish_history" \
                 "$HOME/.local/share/mc/history"; do
        [[ -e "$extra" ]] || continue
        if [[ -d "$extra" ]]; then
            find "$extra" -mindepth 1 -delete 2>/dev/null || true
        else
            : > "$extra" 2>/dev/null || rm -f "$extra" 2>/dev/null || true
        fi
    done
    shopt -u nullglob

    if [[ -d "$HOME/.zsh_sessions" ]]; then
        find "$HOME/.zsh_sessions" -mindepth 1 -delete 2>/dev/null || true
    fi
    if [[ -d "$HOME/.local/share/zsh" ]]; then
        find "$HOME/.local/share/zsh" -type f \( -name '*history*' -o -name '.zcompdump*' \) -delete 2>/dev/null || true
    fi
    for extra in "$HOME/.local/share/atuin" "$HOME/.local/share/mcfly" "$HOME/.local/share/hishtory"; do
        if [[ -d "$extra" ]]; then
            find "$extra" -mindepth 1 -delete 2>/dev/null || true
        fi
    done

    if ! _history_disable_autosuggest; then
        _GM_STEP_MSG="could not disable zsh-autosuggestions"
        return 1
    fi

    local immutable_ok=1
    for f in "$HOME/.zsh_history" "$HOME/.bash_history"; do
        if ! chattr +i "$f" 2>/dev/null && ! _gm_sudo chattr +i "$f" 2>/dev/null; then
            immutable_ok=0
        fi
    done

    if [[ -s "$HOME/.zsh_history" || -s "$HOME/.bash_history" ]]; then
        _GM_STEP_MSG="history file still has commands"
        return 1
    fi
    if _history_plugin_active; then
        _GM_STEP_MSG="zsh-autosuggestions is back at its original path"
        return 1
    fi

    _GM_STEP_MSG="Scrollback of an open terminal stays in that window until you close it. This run does not close terminals."
    if [[ "$immutable_ok" -eq 0 ]]; then
        _GM_STEP_MSG="Close open terminals before treating this wipe as final (history file could not be made immutable). ${_GM_STEP_MSG}"
        return 2
    fi
    return 0
}

_history_check() {
    local padded problems=()
    padded=$(printf "%-22s" "shell history root")
    if _history_plugin_active; then
        problems+=("suggestion plugin is installed")
    fi
    local f
    for f in "$HOME/.zsh_history" "$HOME/.bash_history" "$HOME/.zhistory"; do
        if [[ -s "$f" ]]; then
            problems+=("$(basename "$f") has commands")
        fi
    done
    if [[ ! -f "$HOME/.zshrc" ]] || ! grep -qF "$GHOSTMODE_GUARD_MARK" "$HOME/.zshrc" 2>/dev/null; then
        problems+=("guard is not sourced from .zshrc")
    fi
    if [[ ! -f "$GHOSTMODE_HISTORY_GUARD" ]]; then
        problems+=("guard file missing")
    fi
    if [[ ${#problems[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}guard on, histories empty, suggestions off${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${problems[0]}${RST}"
        local p
        for p in "${problems[@]:1}"; do
            echo -e "       ╰ ${p}"
        done
    fi
}

# destroy only: disk is already empty. Unlock, drop the guard, then restore the plugin.
_history_destroy_restore() {
    _history_unlock_files
    : > "$HOME/.zsh_history" 2>/dev/null || true
    : > "$HOME/.bash_history" 2>/dev/null || true

    if [[ -f "$HOME/.zshrc" ]]; then
        sed -i "/${GHOSTMODE_GUARD_MARK}/d" "$HOME/.zshrc" 2>/dev/null || true
    fi
    rm -f "$GHOSTMODE_HISTORY_GUARD" "$GHOSTMODE_HISTORY_GENERATION" 2>/dev/null || true

    local histsize=1000 savehist=2000
    if [[ -f "$GHOSTMODE_HISTORY_SAVED" ]]; then
        # shellcheck disable=SC1090
        source "$GHOSTMODE_HISTORY_SAVED"
        histsize="${HISTSIZE:-1000}"
        savehist="${SAVEHIST:-2000}"
    fi
    if [[ -f "$HOME/.zshrc" ]] && ! grep -qE '^[[:space:]]*HISTSIZE=' "$HOME/.zshrc"; then
        printf '\nHISTSIZE=%s\nSAVEHIST=%s\n' "$histsize" "$savehist" >> "$HOME/.zshrc"
    fi

    local f src
    for f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh.ghostmode-disabled \
             /usr/share/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh.ghostmode-disabled; do
        if [[ -f "$f" ]]; then
            src="${f%.ghostmode-disabled}"
            _gm_sudo mv "$f" "$src" || return 1
        fi
    done
    return 0
}
