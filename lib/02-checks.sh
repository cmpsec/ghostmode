#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.

_check_file() {
    local path="$1" label="$2"
    local padded
    padded=$(printf "%-22s" "$label")
    if [[ ! -f "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
    elif [[ ! -s "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        local lines size
        lines=$(wc -l < "$path" 2>/dev/null)
        size=$(du -sh "$path" 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${lines} lines${RST} (${size})"
    fi
}

_check_dir() {
    local path="$1" label="$2"
    local padded
    padded=$(printf "%-22s" "$label")
    if [[ ! -d "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
        return
    fi
    local count size
    count=$(find "$path" -maxdepth 2 -not -path "$path" 2>/dev/null | wc -l)
    count=$(( count + 0 ))
    size=$(du -sh "$path" 2>/dev/null | cut -f1)
    if [[ "$count" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} items${RST} (${size})"
        ls "$path" 2>/dev/null | head -5 | sed 's/^/       ╰ /'
    fi
}

_check_tmp() {
    local path="$1" label="$2"
    local padded
    padded=$(printf "%-22s" "$label")
    if [[ ! -d "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
        return
    fi
    local _tmp_arr=()
    mapfile -t _tmp_arr < <(find "$path" -maxdepth 1 \
        -not -name "$(basename "$path")" \
        -not -name "systemd-private*" \
        -not -name ".X*" \
        -not -name ".ICE*" \
        -not -name ".font-unix" \
        -not -name ".org.chromium.*" \
        -not -name ".mount_cursor*" \
        -not -name "*-cursor-zsh" \
        -not -name "_gh_hist_tmp" \
        -not -name "snap-private-tmp" \
        -not -type s \
        2>/dev/null)
    local count=${#_tmp_arr[@]}
    if [[ "$count" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        local size
        size=$(du -sh "$path" 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} user files${RST} (${size})"
        printf '%s\n' "${_tmp_arr[@]}" | head -5 | xargs -I{} basename {} | sed 's/^/       ╰ /'
    fi
}

_check_log() {
    local path="$1" label="$2"
    local padded
    padded=$(printf "%-22s" "$label")
    if [[ ! -f "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found${RST}"
    elif [[ ! -s "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        local size
        size=$(du -sh "$path" 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}has content${RST} (${size})"
    fi
}

_check_trace_paths() {
    local padded found=0
    for pat in "${GHOSTMODE_TRACE_PATHS[@]}"; do
        local -a matches=()
        if [[ "$pat" == *"*"* ]]; then
            mapfile -t matches < <(eval "ls -d $pat 2>/dev/null")
        else
            [[ -e "$pat" ]] && matches=("$pat")
        fi
        for p in "${matches[@]}"; do
            [[ -e "$p" ]] || continue
            local label count size
            label="${p#$HOME/}"
            [[ ${#label} -gt 42 ]] && label="${label:0:39}..."
            padded=$(printf "%-42s" "$label")
            if [[ -f "$p" ]]; then
                [[ ! -s "$p" ]] && continue
                size=$(du -sh "$p" 2>/dev/null | cut -f1)
                found=$((found + 1))
                echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${size}${RST}"
            elif [[ -d "$p" ]]; then
                count=$(find "$p" -mindepth 1 2>/dev/null | wc -l)
                count=$((count + 0))
                [[ "$count" -eq 0 ]] && continue
                size=$(du -sh "$p" 2>/dev/null | cut -f1)
                found=$((found + 1))
                echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} items ${size}${RST}"
            fi
        done
    done
    if [[ "$found" -eq 0 ]]; then
        padded=$(printf "%-42s" "trace paths")
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    fi
}

_clean_trace_paths() {
    for pat in "${GHOSTMODE_TRACE_PATHS[@]}"; do
        local -a matches=()
        if [[ "$pat" == *"*"* ]]; then
            mapfile -t matches < <(eval "ls -d $pat 2>/dev/null")
        else
            [[ -e "$pat" ]] && matches=("$pat")
        fi
        for p in "${matches[@]}"; do
            [[ -e "$p" ]] || continue
            if [[ -f "$p" ]]; then
                : > "$p" 2>/dev/null || rm -f "$p" 2>/dev/null
            elif [[ -d "$p" ]]; then
                rm -rf "$p" 2>/dev/null
            fi
        done
    done
    [[ -f "$HOME/.ssh/known_hosts" ]] && : > "$HOME/.ssh/known_hosts" 2>/dev/null
    rm -f "$HOME/.ssh/known_hosts.old" 2>/dev/null
}

_check_recently_used() {
    local path=~/.local/share/recently-used.xbel
    local padded
    padded=$(printf "%-22s" "recently-used.xbel")
    if [[ ! -f "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
    elif [[ -L "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}linked to /dev/null${RST}"
    elif [[ ! -s "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        local items
        items=$(grep -c '<bookmark' "$path" 2>/dev/null)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${items} recent items${RST}"
    fi
    padded=$(printf "%-22s" "recently-used.xbel.*")
    local xbel_extra
    xbel_extra=$(find ~/.local/share -maxdepth 1 -name 'recently-used.xbel.*' -type f 2>/dev/null)
    if [[ -z "$xbel_extra" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
    else
        local n
        n=$(echo "$xbel_extra" | wc -l)
        n=$(( n + 0 ))
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${n} backup/extra files${RST}"
        echo "$xbel_extra" | head -3 | xargs -I{} basename {} | sed 's/^/       ╰ /'
    fi
}

_check_cursor_cache() {
    local path=~/.config/Cursor/Cache
    local padded
    padded=$(printf "%-22s" "Cursor/Cache")
    if [[ ! -d "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
        return
    fi
    local cursor_running=0
    pgrep -x "cursor" -a 2>/dev/null | grep -qv "grep" && cursor_running=1
    pgrep -f "cursor.appimage" 2>/dev/null | grep -qv "grep" && cursor_running=1
    local count sz
    count=$(find "$path" -maxdepth 2 -not -path "$path" 2>/dev/null | wc -l)
    count=$(( count + 0 ))
    sz=$(du -sh "$path" 2>/dev/null | cut -f1)
    if [[ "$count" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    elif [[ "$cursor_running" -eq 1 ]]; then
        echo -e "  ${GRY}~${RST}  ${padded} → ${GRY}active (Cursor running, ${count} items, ${sz})${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} items${RST} (${sz})"
        ls "$path" 2>/dev/null | head -5 | sed 's/^/       ╰ /'
    fi
}

_check_cursor_projects() {
    local path="$HOME/.cursor/projects"
    local padded
    padded=$(printf "%-22s" "cursor/projects")
    if [[ ! -d "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
        return
    fi
    local count size
    count=$(find "$path" -mindepth 1 2>/dev/null | wc -l)
    count=$((count + 0))
    size=$(du -sh "$path" 2>/dev/null | cut -f1)
    if [[ "$count" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} items${RST} (${size})"
    fi
}

_check_cursor_plans() {
    local path=~/.cursor/plans
    local padded
    padded=$(printf "%-22s" "cursor/plans")
    if [[ ! -d "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
        return
    fi
    local count size
    count=$(find "$path" -mindepth 1 2>/dev/null | wc -l)
    count=$(( count + 0 ))
    size=$(du -sh "$path" 2>/dev/null | cut -f1)
    if [[ "$count" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} items${RST} (${size})"
        find "$path" -maxdepth 1 -mindepth 1 2>/dev/null | head -5 | sed 's/^/       ╰ /'
    fi
}

_check_cursor_ai() {
    local path=~/.cursor/ai-tracking
    local padded
    padded=$(printf "%-22s" "cursor/ai-tracking")
    if [[ ! -d "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
        return
    fi
    local count size
    count=$(find "$path" -mindepth 1 -type f -size +0c 2>/dev/null | wc -l)
    count=$((count + 0))
    if [[ "$count" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        size=$(du -sh "$path" 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} files${RST} (${size})"
    fi
}

_check_journal() {
    local path=/var/log/journal
    local padded
    padded=$(printf "%-22s" "systemd journal")
    if [[ ! -d "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
        return
    fi
    local old_count=0 active_count=0
    old_count=$(find "$path" -name "*.journal~" 2>/dev/null | wc -l)
    old_count=$(( old_count + 0 ))
    active_count=$(find "$path" -name "*.journal" 2>/dev/null | wc -l)
    active_count=$(( active_count + 0 ))
    local size
    size=$(du -sh "$path" 2>/dev/null | cut -f1)
    if [[ "$old_count" -gt 0 ]]; then
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${old_count} archived journals${RST} (${size})"
    elif [[ "$active_count" -gt 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST} (${active_count} active, ${size} — live)"
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    fi
}

_check_ssh_keys() {
    local ssh_dir=~/.ssh
    local padded
    padded=$(printf "%-22s" "ssh keys/config")
    if [[ ! -d "$ssh_dir" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
    else
        local -a key_files=()
        while IFS= read -r f; do
            if [[ "$(basename "$f")" == known_hosts* ]]; then
                [[ -s "$f" ]] && key_files+=("$f")
            else
                key_files+=("$f")
            fi
        done < <(find "$ssh_dir" -maxdepth 1 -type f \
            \( -name "id_*" -o -name "*.pem" -o -name "*.key" \
               -o -name "known_hosts*" -o -name "authorized_keys" \
               -o -name "config" \) 2>/dev/null)
        local count=${#key_files[@]}
        if [[ "$count" -eq 0 ]]; then
            echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
        else
            local size
            size=$(du -sh "$ssh_dir" 2>/dev/null | cut -f1)
            echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} files${RST} (${size})"
            printf '       ╰ %s\n' "${key_files[@]}" | sed "s|$HOME/||" | head -8
        fi
    fi
    padded=$(printf "%-22s" "known_hosts entries")
    local kh=~/.ssh/known_hosts
    if [[ ! -f "$kh" ]] || [[ ! -s "$kh" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        local entries
        entries=$(wc -l < "$kh" 2>/dev/null)
        entries=$(( entries + 0 ))
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${entries} hosts recorded${RST}"
        awk '{print $1}' "$kh" 2>/dev/null | head -5 | sed 's/^/       ╰ /'
    fi
}

_check_clipboard() {
    local padded
    padded=$(printf "%-22s" "clipboard (X11)")
    local clip_content
    clip_content=$(xclip -selection clipboard -o 2>/dev/null)
    if [[ -z "$clip_content" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}has content${RST}"
    fi
    padded=$(printf "%-22s" "clipboard (primary)")
    local prim_content
    prim_content=$(xclip -selection primary -o 2>/dev/null)
    if [[ -z "$prim_content" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}has content${RST}"
    fi
    padded=$(printf "%-22s" "clipman/history file")
    local clipman_file=~/.cache/xfce4/clipman/textsrc
    if [[ ! -f "$clipman_file" || ! -s "$clipman_file" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        local sz
        sz=$(du -sh "$clipman_file" 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}has entries${RST} (${sz})"
    fi
}

_check_home_dir() {
    local padded
    padded=$(printf "%-22s" "home scripts (~)")
    local -a scripts=()
    mapfile -t scripts < <(find "$HOME" -maxdepth 1 -type f \
        \( -name "*.sh" -o -name "*.py" -o -name "*.pl" \
           -o -name "*.rb" -o -name "*.bash" -o -name "*.zsh" \) \
        -not -name ".*" 2>/dev/null)
    local -a exec_files=()
    mapfile -t exec_files < <(find "$HOME" -maxdepth 1 -type f \
        -perm /111 -not -name ".*" \
        -not -name "*.sh" -not -name "*.py" -not -name "*.pl" \
        -not -name "*.rb" -not -name "*.bash" -not -name "*.zsh" \
        2>/dev/null)
    local -a all_scripts=("${scripts[@]}" "${exec_files[@]}")
    local sc_count=${#all_scripts[@]}
    if [[ "$sc_count" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty (clean)${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${sc_count} scripts found${RST}"
        printf '       ╰ %s\n' "${all_scripts[@]}" | sed "s|$HOME/||" | head -8
    fi
    padded=$(printf "%-22s" "home hidden files")
    local -a hidden=()
    mapfile -t hidden < <(find "$HOME" -maxdepth 1 -type f -name ".*" \
        -not -name ".zsh_history" -not -name ".bash_history" \
        -not -name ".bashrc" -not -name ".zshrc" \
        -not -name ".profile" -not -name ".bash_profile" \
        -not -name ".bash_logout" -not -name ".zlogout" \
        -not -name ".vimrc" -not -name ".nanorc" \
        -not -name ".gitconfig" -not -name ".gitignore" \
        -not -name ".dmrc" -not -name ".ICEauthority" \
        -not -name ".Xauthority" -not -name ".xsessionrc" \
        2>/dev/null)
    if [[ ${#hidden[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        echo -e "  ${YLW}!${RST}  ${padded} → ${YLW}${#hidden[@]} non-standard hidden files${RST}"
        printf '       ╰ %s\n' "${hidden[@]}" | sed "s|$HOME/||" | head -8
    fi
    _check_dir ~/Downloads  "Downloads"
    _check_dir ~/Documents  "Documents"
    _check_dir ~/Music      "Music"
    _check_dir ~/Videos     "Videos"
    _check_dir ~/Pictures   "Pictures"
    _check_dir ~/Desktop    "Desktop"
    _check_dir ~/Templates  "Templates"
    _check_dir ~/Public     "Public"
}

_check_firefox() {
    local ff_profile
    ff_profile=$(find ~/.mozilla/firefox -maxdepth 1 -type d \
        \( -name "*.default-esr" -o -name "*.default" \) 2>/dev/null | head -1)
    local padded
    if [[ -z "$ff_profile" ]]; then
        padded=$(printf "%-22s" "firefox profile")
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
        return
    fi
    padded=$(printf "%-22s" "firefox/places (hist)")
    local places="$ff_profile/places.sqlite"
    if [[ -f "$places" ]]; then
        local sz pages
        sz=$(du -sh "$places" 2>/dev/null | cut -f1)
        pages=$(sqlite3 "$places" "SELECT COUNT(*) FROM moz_places;" 2>/dev/null || echo "0")
        if [[ "$pages" -gt 0 ]] 2>/dev/null; then
            echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${pages} history entries${RST} (${sz})"
        else
            echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
        fi
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found${RST}"
    fi
    padded=$(printf "%-22s" "firefox/cookies")
    local cookies="$ff_profile/cookies.sqlite"
    if [[ -f "$cookies" && -s "$cookies" ]]; then
        local ck_count sz
        ck_count=$(sqlite3 "$cookies" "SELECT COUNT(*) FROM moz_cookies;" 2>/dev/null || echo "0")
        sz=$(du -sh "$cookies" 2>/dev/null | cut -f1)
        if [[ "$ck_count" -gt 0 ]] 2>/dev/null; then
            echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${ck_count} cookies${RST} (${sz})"
        else
            echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
        fi
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    fi
    padded=$(printf "%-22s" "firefox/session")
    local sess="$ff_profile/sessionstore.jsonlz4"
    if [[ -f "$sess" && -s "$sess" ]]; then
        local sz
        sz=$(du -sh "$sess" 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}session saved${RST} (${sz})"
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    fi
    padded=$(printf "%-22s" "firefox/cache")
    local fc
    fc=$(find ~/.cache -maxdepth 2 -type d -name "firefox" 2>/dev/null | head -1)
    if [[ -d "$fc" ]]; then
        local sz
        sz=$(du -sh "$fc" 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}cache exists${RST} (${sz})"
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    fi
}

_check_gnome_shell() {
    local padded
    padded=$(printf "%-22s" "gnome/app_state")
    local appstate=~/.local/share/gnome-shell/application_state
    if [[ ! -f "$appstate" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found${RST}"
    else
        local count
        count=$(grep -c '<application' "$appstate" 2>/dev/null)
        if [[ "$count" -gt 0 ]]; then
            echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} apps tracked${RST}"
            grep 'id=' "$appstate" 2>/dev/null | sed 's/.*id="//;s/".*//' | head -5 | sed 's/^/       ╰ /'
        else
            echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
        fi
    fi
    padded=$(printf "%-22s" "gnome/session-history")
    local sesshist=~/.local/share/gnome-shell/session-active-history.json
    if [[ ! -f "$sesshist" || ! -s "$sesshist" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        local sz
        sz=$(du -sh "$sesshist" 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}session timestamps recorded${RST} (${sz})"
    fi
}

_check_text_editors() {
    local padded
    padded=$(printf "%-22s" "TextEditor/recent")
    local te_recent=~/.local/share/org.gnome.TextEditor/recently-used.xbel
    if [[ ! -f "$te_recent" || ! -s "$te_recent" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        local count
        count=$(grep -c '<bookmark' "$te_recent" 2>/dev/null)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} recent files${RST}"
        grep 'href=' "$te_recent" 2>/dev/null | sed 's/.*href="//;s/".*//' | \
            sed 's|file://||' | head -5 | sed 's/^/       ╰ /'
    fi
    padded=$(printf "%-22s" "TextEditor/session")
    local te_sess=~/.local/share/org.gnome.TextEditor/session.gvariant
    if [[ ! -f "$te_sess" || ! -s "$te_sess" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        local sz
        sz=$(du -sh "$te_sess" 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}session data${RST} (${sz})"
    fi
    padded=$(printf "%-22s" "cherrytree/recent")
    local ct_cfg=~/.config/cherrytree/config.cfg
    if [[ ! -f "$ct_cfg" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found${RST}"
    else
        local recent_val pick_dir
        recent_val=$(grep "^recent_docs=" "$ct_cfg" 2>/dev/null | cut -d= -f2)
        pick_dir=$(grep "^pick_dir_file=" "$ct_cfg" 2>/dev/null | cut -d= -f2)
        if [[ "$recent_val" == "true" || -n "$pick_dir" ]]; then
            echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}recent docs enabled${RST} (last dir: ${pick_dir:-unknown})"
        else
            echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
        fi
    fi
}

_check_sqlite_wal_shm() {
    local padded
    padded=$(printf "%-22s" "sqlite WAL/SHM (user)")
    local -a wal_shm=()
    mapfile -t wal_shm < <(find ~/.config ~/.local/share -maxdepth 4 \
        \( -name "*.db-wal" -o -name "*.db-shm" -o -name "*.sqlite-wal" -o -name "*.sqlite-shm" \) \
        -type f 2>/dev/null)
    if [[ ${#wal_shm[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        local sz
        sz=$(du -ch "${wal_shm[@]}" 2>/dev/null | tail -1 | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${#wal_shm[@]} files${RST} (${sz})"
        printf '       ╰ %s\n' "${wal_shm[@]}" | sed "s|$HOME/||" | head -5
    fi
}

_check_trash() {
    local padded
    padded=$(printf "%-22s" "Trash")
    local trash_dir=~/.local/share/Trash/files
    if [[ ! -d "$trash_dir" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found${RST}"
        return
    fi
    local count sz
    count=$(find "$trash_dir" -maxdepth 1 -not -path "$trash_dir" 2>/dev/null | wc -l)
    count=$(( count + 0 ))
    if [[ "$count" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        sz=$(du -sh ~/.local/share/Trash 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} items${RST} (${sz})"
        ls "$trash_dir" 2>/dev/null | head -5 | sed 's/^/       ╰ /'
    fi
}

_check_service_logs() {
    local padded
    padded=$(printf "%-22s" "postgresql log")
    local pg_log
    pg_log=$(find /var/log/postgresql -name "*.log" -type f 2>/dev/null | head -1)
    if [[ -z "$pg_log" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found${RST}"
    elif [[ ! -s "$pg_log" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        local sz
        sz=$(du -sh "$pg_log" 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}has content${RST} (${sz})"
    fi
    padded=$(printf "%-22s" "apache2 access.log")
    if [[ ! -f /var/log/apache2/access.log ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found${RST}"
    elif ! _gm_sudo test -s /var/log/apache2/access.log 2>/dev/null; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        local sz
        sz=$(_gm_sudo du -sh /var/log/apache2/access.log 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}has content${RST} (${sz})"
    fi
    padded=$(printf "%-22s" "nginx access.log")
    if [[ ! -f /var/log/nginx/access.log ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found${RST}"
    elif ! _gm_sudo test -s /var/log/nginx/access.log 2>/dev/null; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        local sz
        sz=$(_gm_sudo du -sh /var/log/nginx/access.log 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}has content${RST} (${sz})"
    fi
    padded=$(printf "%-22s" "macchanger.log")
    if [[ ! -f /var/log/macchanger.log ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found${RST}"
    elif ! _gm_sudo grep -qv "disabled" /var/log/macchanger.log 2>/dev/null; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}only disabled entries${RST}"
    else
        local sz
        sz=$(_gm_sudo du -sh /var/log/macchanger.log 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}has entries${RST} (${sz})"
    fi
}

_check_network_manager() {
    local padded
    padded=$(printf "%-22s" "WiFi SSIDs saved")
    local nm_dir=/etc/NetworkManager/system-connections
    local count=0
    count=$(_gm_sudo ls "$nm_dir" 2>/dev/null | wc -l)
    count=$(( count + 0 ))
    if [[ "$count" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}none saved${RST}"
    else
        echo -e "  ${YLW}!${RST}  ${padded} → ${YLW}${count} WiFi profiles${RST}"
        _gm_sudo ls "$nm_dir" 2>/dev/null | \
            sed 's/.nmconnection//' | head -5 | sed 's/^/       ╰ /'
    fi
}

_check_vnc_traces() {
    local padded
    padded=$(printf "%-22s" "ssh known_hosts")
    local kh=~/.ssh/known_hosts
    if [[ ! -f "$kh" ]] || [[ ! -s "$kh" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        local n=0
        n=$(wc -l < "$kh" 2>/dev/null)
        n=$(( n + 0 ))
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${n} IPs/hosts stored${RST}"
        awk '{print $1}' "$kh" 2>/dev/null | head -5 | sed 's/^/       ╰ /'
    fi
    padded=$(printf "%-22s" "vnc server files")
    local -a vnc_files=()
    mapfile -t vnc_files < <(find "$HOME" -maxdepth 3 \
        \( -path "*/.vnc/*" -o -path "*/tightvnc*" -o -name "*.vnc" \
           -o -name "vncpasswd" -o -name "xstartup" \) \
        -type f 2>/dev/null)
    if [[ ${#vnc_files[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${#vnc_files[@]} vnc files${RST}"
        printf '       ╰ %s\n' "${vnc_files[@]}" | sed "s|$HOME/||" | head -8
    fi
    padded=$(printf "%-22s" "vnc logs")
    local -a vnc_logs=()
    if [[ -d "$HOME/.vnc" ]]; then
        mapfile -t vnc_logs < <(find "$HOME/.vnc" -maxdepth 2 \
            \( -name "*.log" -o -name "*.pid" \) -type f 2>/dev/null)
    fi
    if [[ ${#vnc_logs[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${#vnc_logs[@]} log/pid files${RST}"
        printf '       ╰ %s\n' "${vnc_logs[@]}" | sed "s|$HOME/||" | head -5
    fi
    padded=$(printf "%-22s" "remmina/rdp sessions")
    local -a rdp_files=()
    local rdp_args=()
    [[ -d "$HOME/.local/share/remmina" ]] && rdp_args+=("$HOME/.local/share/remmina")
    [[ -d "$HOME/.remmina" ]] && rdp_args+=("$HOME/.remmina")
    if [[ ${#rdp_args[@]} -gt 0 ]]; then
        mapfile -t rdp_files < <(find "${rdp_args[@]}" -type f 2>/dev/null)
    fi
    if [[ ${#rdp_files[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${#rdp_files[@]} saved sessions${RST}"
        printf '       ╰ %s\n' "${rdp_files[@]}" | sed "s|$HOME/||" | head -5
    fi
    padded=$(printf "%-22s" "ssh cmds in history")
    local hist_file="${HISTFILE:-$HOME/.zsh_history}"
    [[ ! -f "$hist_file" ]] && hist_file="$HOME/.bash_history"
    if [[ -f "$hist_file" ]] && [[ -s "$hist_file" ]]; then
        local ssh_cmds=0
        ssh_cmds=$(grep -c 'ssh\|scp\|sshpass\|expect\|@[0-9]' "$hist_file" 2>/dev/null)
        ssh_cmds=$(( ssh_cmds + 0 ))
        if [[ "$ssh_cmds" -gt 0 ]]; then
            echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${ssh_cmds} ssh-related lines${RST}"
        else
            echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
        fi
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    fi
    padded=$(printf "%-22s" "sshpass/expect cache")
    local -a cred_files=()
    mapfile -t cred_files < <(find /tmp "$HOME" -maxdepth 2 \
        \( -name ".sshpass*" -o -name "expect_*" -o -name "*.expect" \) \
        -type f 2>/dev/null)
    if [[ ${#cred_files[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${#cred_files[@]} files found${RST}"
        printf '       ╰ %s\n' "${cred_files[@]}" | head -5
    fi
    padded=$(printf "%-22s" "x11vnc passwd file")
    local -a x11_files=()
    mapfile -t x11_files < <(find "$HOME" /tmp -maxdepth 2 \
        \( -name ".x11vncpass" -o -name "x11vncpass" -o -name "vp" \) \
        -type f 2>/dev/null)
    if [[ ${#x11_files[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${#x11_files[@]} files found${RST}"
        printf '       ╰ %s\n' "${x11_files[@]}" | head -5
    fi
    padded=$(printf "%-22s" "tigervnc config dir")
    if [[ ! -d "$HOME/.config/tigervnc" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        local tv_count
        tv_count=$(find "$HOME/.config/tigervnc" -type f 2>/dev/null | wc -l)
        tv_count=$(( tv_count + 0 ))
        if [[ "$tv_count" -eq 0 ]]; then
            echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
        else
            echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${tv_count} files${RST}"
            find "$HOME/.config/tigervnc" -type f 2>/dev/null | sed "s|$HOME/||" | head -5 | sed 's/^/       ╰ /'
        fi
    fi
    padded=$(printf "%-22s" "setup_vnc.py script")
    if [[ ! -f "$HOME/setup_vnc.py" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}found${RST}"
    fi
}

_check_locate_db() {
    local padded
    padded=$(printf "%-22s" "locate database")
    local -a db_files=()
    for f in /var/lib/mlocate/mlocate.db /var/lib/plocate/plocate.db; do
        [[ -f "$f" ]] && db_files+=("$f")
    done
    if [[ ${#db_files[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
    else
        local sz
        sz=$(du -ch "${db_files[@]}" 2>/dev/null | tail -1 | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}indexes deleted filenames too${RST} (${sz})"
    fi
}

_check_crash_dumps() {
    local padded
    padded=$(printf "%-22s" "crash dumps")
    local sys_count=0 user_count=0
    sys_count=$(_gm_sudo find /var/crash -maxdepth 1 -type f 2>/dev/null | wc -l)
    sys_count=$(( sys_count + 0 ))
    user_count=$(find ~/.cache/apport -maxdepth 1 -type f 2>/dev/null | wc -l)
    user_count=$(( user_count + 0 ))
    local total=$(( sys_count + user_count ))
    if [[ "$total" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        local sz
        sz=$(_gm_sudo du -sh /var/crash 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${total} files, may hold memory dumps${RST} (${sz:-?})"
    fi
}

_check_chromium() {
    local -a profiles=()
    for base in ~/.config/google-chrome ~/.config/chromium ~/.config/BraveSoftware/Brave-Browser; do
        for p in "$base"/Default "$base"/Profile*; do
            [[ -d "$p" ]] && profiles+=("$p")
        done
    done
    local padded
    padded=$(printf "%-22s" "chrome/chromium/brave")
    if [[ ${#profiles[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
        return
    fi
    local found=0
    for p in "${profiles[@]}"; do
        for f in History Cookies "Web Data" "Login Data"; do
            [[ -s "$p/$f" ]] && found=$((found + 1))
        done
    done
    if [[ "$found" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        local sz
        sz=$(du -ch "${profiles[@]}" 2>/dev/null | tail -1 | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${found} data files (history/cookies/logins)${RST} (${sz})"
    fi
}

_check_apt_logs() {
    local padded
    padded=$(printf "%-22s" "apt history logs")
    local -a logs=()
    mapfile -t logs < <(_gm_sudo find /var/log/apt -maxdepth 1 -type f \
        \( -name "history.log*" -o -name "term.log*" \) 2>/dev/null)
    local nonempty=0
    for f in "${logs[@]}"; do
        [[ -s "$f" ]] && nonempty=$((nonempty + 1))
    done
    if [[ "$nonempty" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${nonempty} files with entries${RST}"
    fi
}

_check_user_journal() {
    local path=~/.local/state/journal
    local padded
    padded=$(printf "%-22s" "user journal")
    if [[ ! -d "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
        return
    fi
    local sz
    sz=$(du -sh "$path" 2>/dev/null | cut -f1)
    echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}persistent user journal${RST} (${sz})"
}

_check_pentest_traces() {
    local padded

    padded=$(printf "%-22s" "metasploit (~/.msf4)")
    if [[ -d ~/.msf4 ]]; then
        local sz
        sz=$(du -sh ~/.msf4 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}history/logs/loot/db${RST} (${sz})"
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
    fi

    padded=$(printf "%-22s" "john potfile")
    local john_pot=~/.john/john.pot
    if [[ -s "$john_pot" ]]; then
        local n
        n=$(wc -l < "$john_pot" 2>/dev/null); n=$(( n + 0 ))
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${n} cracked hashes stored${RST}"
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    fi

    padded=$(printf "%-22s" "hashcat potfile")
    local -a hc_pots=()
    mapfile -t hc_pots < <(find ~/.local/share/hashcat ~/.hashcat -maxdepth 1 \
        -name "*.potfile" -type f 2>/dev/null)
    local hc_found=0
    for f in "${hc_pots[@]}"; do [[ -s "$f" ]] && hc_found=$((hc_found + 1)); done
    if [[ "$hc_found" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}cracked passwords cached${RST}"
    fi

    padded=$(printf "%-22s" "cme/netexec loot")
    local -a cme_dirs=()
    for d in ~/.cme ~/.nxc; do [[ -d "$d" ]] && cme_dirs+=("$d"); done
    if [[ ${#cme_dirs[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
    else
        local sz
        sz=$(du -ch "${cme_dirs[@]}" 2>/dev/null | tail -1 | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}captured creds/hosts${RST} (${sz})"
    fi

    padded=$(printf "%-22s" "responder logs")
    local resp_count=0
    resp_count=$(_gm_sudo find /usr/share/responder/logs -maxdepth 1 -type f 2>/dev/null | wc -l)
    resp_count=$(( resp_count + 0 ))
    if [[ "$resp_count" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${resp_count} files, captured hashes${RST}"
    fi

    padded=$(printf "%-22s" "evil-winrm history")
    if [[ -d ~/.evil-winrm ]]; then
        local sz
        sz=$(du -sh ~/.evil-winrm 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}command history/downloads${RST} (${sz})"
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
    fi

    padded=$(printf "%-22s" "sqlmap output")
    local -a sqlmap_dirs=()
    for d in ~/.local/share/sqlmap ~/.sqlmap; do [[ -d "$d" ]] && sqlmap_dirs+=("$d"); done
    if [[ ${#sqlmap_dirs[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
    else
        local sz
        sz=$(du -ch "${sqlmap_dirs[@]}" 2>/dev/null | tail -1 | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}possible extracted DB dumps${RST} (${sz})"
    fi

    padded=$(printf "%-22s" "wireshark recent")
    if [[ -s ~/.config/wireshark/recent ]]; then
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}recent capture paths saved${RST}"
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    fi

    padded=$(printf "%-22s" "burp suite data")
    local -a burp_dirs=()
    for d in ~/.BurpSuite ~/.java/.userPrefs/burp; do [[ -d "$d" ]] && burp_dirs+=("$d"); done
    if [[ ${#burp_dirs[@]} -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}project/settings present${RST}"
    fi
}

_check_claude_traces() {
    local padded

    padded=$(printf "%-22s" "claude/projects")
    local path=~/.claude/projects
    if [[ -d "$path" ]]; then
        local count sz
        count=$(find "$path" -type f 2>/dev/null | wc -l); count=$(( count + 0 ))
        sz=$(du -sh "$path" 2>/dev/null | cut -f1)
        if [[ "$count" -eq 0 ]]; then
            echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
        else
            echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} conversation logs${RST} (${sz})"
        fi
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
    fi

    padded=$(printf "%-22s" "claude.json (session)")
    if [[ -s ~/.claude.json ]]; then
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}session/config data${RST}"
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}clean${RST}"
    fi
}

_check_system_info() {
    local padded

    padded=$(printf "%-22s" "hostname")
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}$(hostname 2>/dev/null)${RST}"

    padded=$(printf "%-22s" "OS")
    local os_name
    os_name=$(grep -m1 '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${os_name:-unknown}${RST}"

    padded=$(printf "%-22s" "kernel")
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}$(uname -r 2>/dev/null)${RST}"

    padded=$(printf "%-22s" "uptime")
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}$(uptime -p 2>/dev/null)${RST}"

    padded=$(printf "%-22s" "CPU")
    local cpu_model cores
    cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//')
    cores=$(nproc 2>/dev/null)
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${cpu_model:-unknown} (${cores} cores)${RST}"

    padded=$(printf "%-22s" "CPU load (1/5/15m)")
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)${RST}"

    padded=$(printf "%-22s" "RAM")
    local ram_line
    ram_line=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3" / "$2" used"}')
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${ram_line}${RST}"

    padded=$(printf "%-22s" "swap")
    local swap_line
    swap_line=$(free -h 2>/dev/null | awk '/^Swap:/ {print $3" / "$2" used"}')
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${swap_line}${RST}"

    padded=$(printf "%-22s" "disk (/)")
    local disk_line disk_pct
    disk_line=$(df -h / 2>/dev/null | awk 'NR==2 {print $3" / "$2" ("$5")"}')
    disk_pct=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
    local dcolor=$GRN
    [[ "$disk_pct" -ge 80 ]] 2>/dev/null && dcolor=$YLW
    [[ "$disk_pct" -ge 92 ]] 2>/dev/null && dcolor=$RED
    echo -e "  ${CYN}◉${RST}  ${padded} → ${dcolor}${disk_line}${RST}"

    if mountpoint -q /home 2>/dev/null; then
        padded=$(printf "%-22s" "disk (/home)")
        local home_line
        home_line=$(df -h /home 2>/dev/null | awk 'NR==2 {print $3" / "$2" ("$5")"}')
        echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${home_line}${RST}"
    fi

    padded=$(printf "%-22s" "GPU")
    local gpu
    gpu=$(lspci 2>/dev/null | grep -i 'vga\|3d controller' | head -1 | cut -d: -f3 | sed 's/^ *//')
    echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${gpu:-unknown}${RST}"
}

_check_battery() {
    local padded
    local bat_path
    bat_path=$(find /sys/class/power_supply -maxdepth 1 -name 'BAT*' 2>/dev/null | head -1)
    if [[ -z "$bat_path" ]]; then
        padded=$(printf "%-22s" "battery")
        echo -e "  ${GRY}~${RST}  ${padded} → ${GRY}no battery detected (desktop?)${RST}"
        return
    fi

    local status capacity
    status=$(cat "$bat_path/status" 2>/dev/null)
    capacity=$(cat "$bat_path/capacity" 2>/dev/null)
    padded=$(printf "%-22s" "battery charge")
    local ccolor=$GRN
    [[ "$capacity" -lt 20 ]] 2>/dev/null && ccolor=$RED
    [[ "$capacity" -lt 40 ]] 2>/dev/null && [[ "$capacity" -ge 20 ]] 2>/dev/null && ccolor=$YLW
    echo -e "  ${CYN}◉${RST}  ${padded} → ${ccolor}${capacity}%${RST} (${status:-unknown})"

    local full full_design health=""
    if [[ -f "$bat_path/energy_full" && -f "$bat_path/energy_full_design" ]]; then
        full=$(cat "$bat_path/energy_full" 2>/dev/null)
        full_design=$(cat "$bat_path/energy_full_design" 2>/dev/null)
    elif [[ -f "$bat_path/charge_full" && -f "$bat_path/charge_full_design" ]]; then
        full=$(cat "$bat_path/charge_full" 2>/dev/null)
        full_design=$(cat "$bat_path/charge_full_design" 2>/dev/null)
    fi
    padded=$(printf "%-22s" "battery health")
    if [[ -n "$full" && -n "$full_design" ]] && [[ "$full_design" -gt 0 ]] 2>/dev/null; then
        health=$(( full * 100 / full_design ))
        local hcolor=$GRN
        [[ "$health" -lt 80 ]] 2>/dev/null && hcolor=$YLW
        [[ "$health" -lt 60 ]] 2>/dev/null && hcolor=$RED
        echo -e "  ${CYN}◉${RST}  ${padded} → ${hcolor}${health}%${RST} of original capacity"
        if [[ "$health" -lt 70 ]] 2>/dev/null; then
            echo -e "       ╰ ${YLW}Noticeable degradation — check the battery physically (swelling/overheating)${RST}"
        fi
    else
        echo -e "  ${GRY}~${RST}  ${padded} → ${GRY}not available on this device${RST}"
    fi

    if [[ -f "$bat_path/cycle_count" ]]; then
        local cycles
        cycles=$(cat "$bat_path/cycle_count" 2>/dev/null)
        if [[ "$cycles" -gt 0 ]] 2>/dev/null; then
            padded=$(printf "%-22s" "charge cycles")
            echo -e "  ${CYN}◉${RST}  ${padded} → ${GRY}${cycles}${RST}"
        fi
    fi

    if [[ -f "$bat_path/temp" ]]; then
        local temp_raw temp_c
        temp_raw=$(cat "$bat_path/temp" 2>/dev/null)
        temp_c=$(( temp_raw / 10 ))
        padded=$(printf "%-22s" "battery temp")
        local tcolor=$GRN
        [[ "$temp_c" -ge 45 ]] 2>/dev/null && tcolor=$YLW
        [[ "$temp_c" -ge 55 ]] 2>/dev/null && tcolor=$RED
        echo -e "  ${CYN}◉${RST}  ${padded} → ${tcolor}${temp_c}°C${RST}"
    fi
}

_check_zsh_autosuggest() {
    _history_check
}

_check_custom_paths() {
    if [[ ! -s "$GHOSTMODE_CUSTOM_PATHS_FILE" ]]; then
        echo -e "  ${GRY}none added — use: ghostmode paths add <path>${RST}"
        return
    fi
    local p padded has_content
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        padded=$(printf "%-40s" "$p")
        if [[ ! -e "$p" ]]; then
            echo -e "  ${GRY}~${RST}  ${padded} → ${GRY}not found${RST}"
            continue
        fi
        has_content=0
        if [[ -d "$p" ]]; then
            [[ -n "$(find "$p" -mindepth 1 -print -quit 2>/dev/null)" ]] && has_content=1
        elif [[ -f "$p" && -s "$p" ]]; then
            has_content=1
        fi
        if [[ "$has_content" -eq 1 ]]; then
            echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}not empty${RST}"
        else
            echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
        fi
    done < "$GHOSTMODE_CUSTOM_PATHS_FILE"
}

