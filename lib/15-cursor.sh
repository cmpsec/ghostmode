#!/usr/bin/env bash
# shellcheck shell=bash
# Cursor conversation stores. Cache may be cleaned while the app is open.
# Conversation databases are not cleaned while it is open unless --force.

_cursor_running() {
    local pid args exe
    while read -r pid args; do
        [[ -n "$pid" ]] || continue
        exe=${args%% *}
        exe=${exe##*/}
        case "$exe" in
            cursor | cursor-agent | Cursor | cursor.AppImage)
                echo "$pid"
                continue
                ;;
        esac
        if [[ "$args" == *"/cursor-agent"* || "$args" == "cursor-agent "* ]]; then
            echo "$pid"
        fi
    done < <(ps -u "$UID" -o pid=,args= 2>/dev/null)
}

_cursor_force_stop() {
    local pid
    while read -r pid; do
        [[ -n "$pid" ]] || continue
        kill "$pid" 2>/dev/null || true
    done < <(_cursor_running)
    sleep 0.5
    while read -r pid; do
        [[ -n "$pid" ]] || continue
        kill -KILL "$pid" 2>/dev/null || true
    done < <(_cursor_running)
    sleep 0.2
    if [[ -n "$(_cursor_running)" ]]; then
        _GM_STEP_MSG="Cursor is still running for this user; not deleting conversation databases"
        return 1
    fi
    return 0
}

_rm_sqlite_family() {
    local base="$1"
    rm -f -- "$base" "${base}-wal" "${base}-shm" "${base}-journal" 2>/dev/null || true
}

_cursor_db_still_present() {
    local hits
    hits=$(
        find "$HOME/.cursor/chats" "$HOME/.cursor/projects" "$HOME/.cursor/ai-tracking" \
            "$HOME/.config/Cursor/User/globalStorage" \
            "$HOME/.config/Cursor/User/workspaceStorage" \
            "$HOME/.config/Cursor/snapshots" \
            "$HOME/.local/state/cursor/agent-stores" \
            \( -name 'state.vscdb' -o -name 'state.vscdb-wal' -o -name 'state.vscdb-shm' \
               -o -name 'store.db' -o -name 'store.db-wal' -o -name 'store.db-shm' \
               -o -name 'conversation-search.db' -o -name 'conversation-search.db-wal' \
               -o -name '*.jsonl' -o -name 'prompt_history.json' \) \
            -print 2>/dev/null | head -n 1
    )
    [[ -n "$hits" ]]
}

_cursor_clean_conversations() {
    local base
    _rm_sqlite_family "$HOME/.config/Cursor/User/globalStorage/state.vscdb"
    _rm_sqlite_family "$HOME/.config/Cursor/User/globalStorage/conversation-search.db"
    rm -f -- "$HOME/.config/Cursor/User/globalStorage/storage.json" 2>/dev/null || true

    if [[ -d "$HOME/.config/Cursor/User/workspaceStorage" ]]; then
        while IFS= read -r base; do
            _rm_sqlite_family "$base"
            rm -f -- "$(dirname "$base")/workspace.json" 2>/dev/null || true
        done < <(find "$HOME/.config/Cursor/User/workspaceStorage" -name 'state.vscdb' -type f 2>/dev/null)
        find "$HOME/.config/Cursor/User/workspaceStorage" -name 'workspace.json' -type f -delete 2>/dev/null || true
    fi

    if [[ -d "$HOME/.cursor/chats" ]]; then
        find "$HOME/.cursor/chats" -mindepth 1 -delete 2>/dev/null || true
    fi
    if [[ -d "$HOME/.local/state/cursor/agent-stores" ]]; then
        find "$HOME/.local/state/cursor/agent-stores" -mindepth 1 -delete 2>/dev/null || true
    fi
    rm -rf -- "$HOME/.config/Cursor/User/globalStorage/anysphere.cursor-retrieval/checkpoints" \
             "$HOME/.config/Cursor/snapshots" \
             "$HOME/.cursor/projects" \
             "$HOME/.cursor/ai-tracking" \
             "$HOME/.cursor/plans" 2>/dev/null || true
    rm -rf -- "$HOME/.config/Cursor/User/globalStorage/anysphere.cursor-agent-worker/worker-data" \
             "$HOME/.config/Cursor/User/globalStorage/anysphere.cursor-agent-host" 2>/dev/null || true
}

_cursor_clean_caches() {
    rm -rf -- \
        "$HOME/.config/Cursor/logs" \
        "$HOME/.config/Cursor/process-monitor" \
        "$HOME/.config/Cursor/Cache" \
        "$HOME/.config/Cursor/CachedData" \
        "$HOME/.config/Cursor/GPUCache" \
        "$HOME/.config/Cursor/DawnGraphiteCache" \
        "$HOME/.config/Cursor/DawnWebGPUCache" \
        "$HOME/.config/Cursor/Crashpad" \
        "$HOME/.config/Cursor/Backups" \
        "$HOME/.config/Cursor/Partitions" \
        "$HOME/.config/Cursor/IndexedDB" \
        "$HOME/.config/Cursor/Session Storage" \
        "$HOME/.config/Cursor/WebStorage" \
        "$HOME/.config/Cursor/blob_storage" \
        "$HOME/.config/Cursor/Network" \
        "$HOME/.config/Cursor/CachedProfilesData" \
        "$HOME/.config/Cursor/Code Cache" \
        "$HOME/.config/Cursor/Local Storage" \
        2>/dev/null || true
    rm -rf -- "$HOME/.config/Cursor/Session" 2>/dev/null || true
    if [[ -d "$HOME/.config/Cursor/User/History" ]]; then
        find "$HOME/.config/Cursor/User/History" -mindepth 1 -delete 2>/dev/null || true
    fi
    rm -f -- \
        "$HOME/.config/Cursor/Cookies" \
        "$HOME/.config/Cursor/Cookies-journal" \
        "$HOME/.config/Cursor/DIPS" \
        "$HOME/.config/Cursor/DIPS-wal" \
        "$HOME/.config/Cursor/DIPS-shm" \
        2>/dev/null || true
}

_cursor_clean_tmp() {
    local s
    shopt -s nullglob
    for s in /tmp/cursor-agent-worker-*.sock; do
        rm -f -- "$s" 2>/dev/null || true
    done
    for s in /tmp/*cursor*; do
        local base
        base=$(basename "$s")
        [[ "$base" == .mount_cursor* ]] && continue
        [[ "$base" == systemd-private* ]] && continue
        rm -rf -- "$s" 2>/dev/null || true
    done
    shopt -u nullglob
}

_cursor_clean() {
    local running=""
    running=$(_cursor_running)

    if [[ -n "$running" ]]; then
        if [[ "$GHOSTMODE_MODE" == "auto" ]]; then
            _cursor_clean_caches
            _GM_STEP_MSG="Cursor is running, skipped conversation databases"
            return 2
        fi
        if [[ "$GHOSTMODE_FORCE" -eq 1 ]]; then
            if ! _cursor_force_stop; then
                return 1
            fi
        else
            _cursor_clean_caches
            _GM_STEP_MSG="Cursor is running. Close it, or rerun: ghostmode --force"
            return 1
        fi
    fi

    _cursor_clean_conversations
    _cursor_clean_caches
    _cursor_clean_tmp

    if _cursor_db_still_present; then
        _GM_STEP_MSG="a Cursor conversation database or transcript is still on disk"
        return 1
    fi
    _GM_STEP_MSG="state.vscdb holds the Cursor session token, so this logs Cursor out. Empty files on the next launch are expected."
    return 0
}

_check_path_size() {
    local path="$1" label="$2"
    local padded
    padded=$(printf "%-22s" "$label")
    if [[ ! -e "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}not found (clean)${RST}"
        return
    fi
    if [[ -d "$path" ]]; then
        local count size
        count=$(find "$path" -mindepth 1 2>/dev/null | wc -l)
        count=$((count + 0))
        size=$(du -sh "$path" 2>/dev/null | cut -f1)
        if [[ "$count" -eq 0 ]]; then
            echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
        else
            echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} items${RST} (${size})"
        fi
        return
    fi
    if [[ ! -s "$path" ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}empty${RST}"
    else
        local size
        size=$(du -sh "$path" 2>/dev/null | cut -f1)
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${size}${RST}"
    fi
}

_check_cursor_databases() {
    _check_path_size "$HOME/.config/Cursor/User/globalStorage/state.vscdb" "state.vscdb"
    _check_path_size "$HOME/.config/Cursor/User/globalStorage/state.vscdb-wal" "state.vscdb-wal"
    _check_path_size "$HOME/.config/Cursor/User/globalStorage/state.vscdb-shm" "state.vscdb-shm"
    _check_path_size "$HOME/.config/Cursor/User/globalStorage/conversation-search.db" "conversation-search"
    _check_path_size "$HOME/.cursor/chats" "cursor/chats"
    _check_path_size "$HOME/.local/state/cursor/agent-stores" "agent-stores"
    _check_path_size "$HOME/.config/Cursor/snapshots" "Cursor/snapshots"
    local ws
    ws=$(find "$HOME/.config/Cursor/User/workspaceStorage" -name 'state.vscdb' -type f -size +0c 2>/dev/null | head -n 1)
    local padded
    padded=$(printf "%-22s" "workspace state.vscdb")
    if [[ -n "$ws" ]]; then
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}non-empty database${RST}"
    else
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}none${RST}"
    fi
}

_check_cursor_sockets() {
    local padded count=0
    padded=$(printf "%-22s" "cursor sockets")
    local s base
    shopt -s nullglob
    for s in /tmp/*cursor* /tmp/*agent* /tmp/cursor-agent-worker-*.sock; do
        base=$(basename "$s")
        [[ "$base" == .mount_cursor* ]] && continue
        [[ -S "$s" || -e "$s" ]] || continue
        count=$((count + 1))
    done
    shopt -u nullglob
    if [[ "$count" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  ${padded} → ${GRN}none${RST}"
    else
        echo -e "  ${RED}✘${RST}  ${padded} → ${YLW}${count} socket file(s)${RST}"
    fi
}
