#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.

# ============================================================
#  CUSTOM PATHS  (unlimited extra folders/files wiped on every
#  clean/delete/auto run, shown in status)
# ============================================================

cmd_paths() {
    case "${1:-list}" in
        add)    shift; _paths_add "$@" ;;
        remove) shift; _paths_remove "$@" ;;
        list)   _paths_list ;;
        *)      echo "Usage: ghostmode paths [add <path>|remove <path>|list]" ;;
    esac
}

_paths_add() {
    local p="$1"
    if [[ -z "$p" ]]; then
        echo "Usage: ghostmode paths add <path>"
        return 1
    fi
    p=$(realpath -m "$p" 2>/dev/null || echo "$p")
    mkdir -p "$(dirname "$GHOSTMODE_CUSTOM_PATHS_FILE")"
    touch "$GHOSTMODE_CUSTOM_PATHS_FILE"
    if grep -qxF "$p" "$GHOSTMODE_CUSTOM_PATHS_FILE" 2>/dev/null; then
        echo -e "  ${YLW}!${RST}  Already added: $p"
        return 0
    fi
    echo "$p" >> "$GHOSTMODE_CUSTOM_PATHS_FILE"
    echo -e "  ${GRN}✔${RST}  Added: $p"
    echo -e "  ${GRY}Its contents will now be wiped on every clean/delete/auto run.${RST}"
}

_paths_remove() {
    local p="$1"
    if [[ -z "$p" ]]; then
        echo "Usage: ghostmode paths remove <path>"
        return 1
    fi
    p=$(realpath -m "$p" 2>/dev/null || echo "$p")
    if [[ -f "$GHOSTMODE_CUSTOM_PATHS_FILE" ]] && grep -qxF "$p" "$GHOSTMODE_CUSTOM_PATHS_FILE" 2>/dev/null; then
        grep -vxF "$p" "$GHOSTMODE_CUSTOM_PATHS_FILE" > "${GHOSTMODE_CUSTOM_PATHS_FILE}.tmp" 2>/dev/null
        mv "${GHOSTMODE_CUSTOM_PATHS_FILE}.tmp" "$GHOSTMODE_CUSTOM_PATHS_FILE"
        echo -e "  ${RED}✘${RST}  Removed: $p"
    else
        echo -e "  ${YLW}!${RST}  Not in the list: $p"
    fi
}

_paths_list() {
    echo -e "${BLD}${CYN}[ Custom Paths ]${RST}"
    _check_custom_paths
}

