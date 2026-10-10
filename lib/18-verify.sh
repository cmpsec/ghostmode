#!/usr/bin/env bash
# shellcheck shell=bash

cmd_verify() {
    local hits=0 line
    echo -e "${BLD}${CYN}[ Verify ]${RST}"
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        hits=$((hits + 1))
        echo -e "  ${RED}✘${RST}  ${line/#$HOME/\~}"
    done < <(
        find "$HOME/.cursor/chats" "$HOME/.cursor/projects" "$HOME/.cursor/ai-tracking" \
            "$HOME/.config/Cursor/User/globalStorage" \
            "$HOME/.config/Cursor/User/workspaceStorage" \
            "$HOME/.config/Cursor/snapshots" \
            "$HOME/.local/state/cursor/agent-stores" \
            \( -name 'state.vscdb' -o -name 'state.vscdb-wal' -o -name 'state.vscdb-shm' \
               -o -name 'store.db' -o -name 'store.db-wal' -o -name 'store.db-shm' \
               -o -name 'conversation-search.db' -o -name 'conversation-search.db-wal' \
               -o -name '*.jsonl' -o -name 'prompt_history.json' \) \
            -size +0c -print 2>/dev/null
    )
    local f
    for f in "$HOME/.zsh_history" "$HOME/.bash_history" "$HOME/.zhistory" \
             "$HOME/.git-credentials" "$HOME/.config/git/credentials" \
             "$HOME/.config/gh/hosts.yml"; do
        if [[ -s "$f" ]]; then
            hits=$((hits + 1))
            echo -e "  ${RED}✘${RST}  ${f/#$HOME/\~}"
        fi
    done
    if _history_plugin_active; then
        hits=$((hits + 1))
        echo -e "  ${RED}✘${RST}  zsh-autosuggestions is at its original path"
    fi
    if [[ "$hits" -eq 0 ]]; then
        echo -e "  ${GRN}✔${RST}  No Cursor conversation files or shell-history commands found"
        echo -e "  ${GRY}This does not cover the router, the ISP, firmware, or SSD spare area.${RST}"
        return 0
    fi
    echo -e "  ${RED}${hits} trace(s) still present${RST}"
    return 1
}
