#!/bin/bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

source "${BASE_DIR}/core/colors.sh"
source "${BASE_DIR}/core/ui.sh"
source "${BASE_DIR}/core/state.sh"
source "${BASE_DIR}/core/dns.sh"
source "${BASE_DIR}/core/network.sh"

source "${BASE_DIR}/daemons/recon.sh"
source "${BASE_DIR}/daemons/leak_extractor.sh"
source "${BASE_DIR}/daemons/weaponize.sh"
source "${BASE_DIR}/daemons/web_fuzz.sh"
source "${BASE_DIR}/daemons/web_meta.sh"
source "${BASE_DIR}/daemons/share_enum.sh"
source "${BASE_DIR}/daemons/post_exp.sh"
source "${BASE_DIR}/daemons/hash_cracker.sh"
source "${BASE_DIR}/daemons/wifi_cracker.sh"
source "${BASE_DIR}/daemons/hash_receiver.sh"
source "${BASE_DIR}/daemons/wifi_recon.sh"
source "${BASE_DIR}/daemons/ctf_boil.sh"
source "${BASE_DIR}/daemons/fast_audit.sh"

source "${BASE_DIR}/king/payloads.sh"
source "${BASE_DIR}/king/capture.sh"
source "${BASE_DIR}/king/check.sh"
source "${BASE_DIR}/king/hydra.sh"
source "${BASE_DIR}/king/hydra_install.sh"
source "${BASE_DIR}/king/shadow.sh"
source "${BASE_DIR}/king/preload.sh"
source "${BASE_DIR}/king/troll.sh"
source "${BASE_DIR}/king/wall.sh"
source "${BASE_DIR}/king/koth.sh"

if (( EUID != 0 )) && [ -z "$TERMUX_VERSION" ]; then
    echo -e "${TXT_RED_HELLFIRE}${ITLC}It is you who should be following orders, not I.\n\n${NC}"
    exit 1
fi

MACHINE_NAME=""
TARGET=""
RUN_RECON=0
RUN_PAYLOADS=0
RUN_BRUTE=0
SKIP_ART=0
RUN_WEB=0
RUN_DELIVERY=0
RUN_CRACK=0
RUN_WIFI=0
RUN_LISTEN=0
RUN_WIFI_SCAN=0
RUN_BOIL=0
RUN_AUDIT=0
RUN_KOTH=0
RUN_BIND=0
RUN_CAPTURE=0
RUN_HYDRA=0
RUN_HYDRA_HEAL=0
RUN_SHADOW=0
RUN_TROLL=0
RUN_TROLL_RESTORE=0
RUN_WALL=0
RUN_CHECK=0
RUN_KOTH_HELP=0
RUN_HOOK=0
HOOK_MODE="map"
FILE_RUN=0
KOTH_TRESTORE=0

show_help() {
    echo -e "${TXT_RED_PLASMA}PROJECT BLACKWALL v1.0${NC}"
    echo -e "Использование: $0 -t <IP> [ОПЦИИ]"
    echo -e "\nОпции:"
    echo -e "  -t <IP>    Target IP"
    echo -e "  -r         Recon: Ping + Port Scan"
    echo -e "  -n <NAME>  Machine name (Will map to <NAME>.htb in /etc/hosts)"
    echo -e "  -e         Auto extractor leak files"
    echo -e "  -d         Post-Exploit: Start PEAS delivery server"
    echo -e "  -p         Payloads gen"
    echo -e "  -c         Cryptographic decryption (Hash Cracker via Hashcat)"
    echo -e "  -W         Wireless Signal Decryptor (WPA/WPA2/WPA3 6-Stage Pipeline)"
    echo -e "  -l         Shadow Listener Mode (Receive hashes over network & auto-crack)"
    echo -e "  -S         Wireless Spectrum Recon (Scan airwaves, fix adapter & capture Handshake)"
    echo -e "  -b         CTF Boilerplate Generator (Pwn / Web templates)"
    echo -e "  -B         Rapid Fast Audit One-Liner"
    echo -e "  -q         Skip art"
    echo -e "  -a         Run all modules"
    echo -e "  -h         Help"
    echo -e "\n${TXT_RED_PLASMA}KING OF THE HILL // BATTLE STATION${NC}"
    echo -e "  -K         Full KOTH station (? for module manual)"
    echo -e "  -k         Bind shell forge only (PHP / bash / nc / socat / python)"
    echo -e "  -G <C>     Capture the hill via <C>, seal seed (needs --host --port --token)"
    echo -e "  -Y         Hydra: watchdog flock + cron + systemd + loader persistence"
    echo -e "             --heal re-arms, --status prints the flock map"
    echo -e "  -E         Shadow: hide the flock, wipe logs and shell history"
    echo -e "  -T         Troll: degrade competitor tooling (--restore undoes it)"
    echo -e "  -Z         Wall: rotate creds, pin your key, seal the firewall"
    echo -e "  -C         Post-root checklist (suid, caps, cron, writable, flags)"
    echo -e "  -o <MODE>  Capture-binary hook: map | uid | token"
    echo -e "\n${TXT_RED_PLASMA}KOTH OPTIONS${NC}"
    echo -e "  --host <IP>         Hill IP (VPN side)"
    echo -e "  --port <PORT>       Bind port (default 4242)"
    echo -e "  --token <TOKEN>     Your team token (or TEAM_TOKEN env)"
    echo -e "  --key <KEY>         Team key / capture key"
    echo -e "  --payload-path <P>  Path of the deployed payload on the hill"
    echo -e "  --pubkey <FILE>     SSH public key for Wall"
    echo -e "  --tool <NAME>       Tool to sabotage for Troll"
    echo -e "  -H                  Full KOTH help"
    exit 1
}

clean_exit() {
    local current_pid=$$
    cleanup_hosts

    if [ -n "${STATE[web_server_pid]}" ]; then
        kill "${STATE[web_server_pid]}" 2>/dev/null
    fi

    fuser -k 9999/tcp 2>/dev/null
    pkill -f "bw_server_" 2>/dev/null

    if [ -n "${STATE[target_domain]}" ]; then
            sed -i "/[[:space:]]${STATE[target_domain]}$/d" /etc/hosts 2>/dev/null
    fi
    rm -f /tmp/blackwall_async_${current_pid} 2>/dev/null
    rm -f /tmp/blackwall_ffuf_${current_pid}.json 2>/dev/null
    rm -f /tmp/blackwall_vhost_${current_pid}.json 2>/dev/null
    rm -f /tmp/wifi_target_${current_pid}.hc22000 2>/dev/null
    rm -f /tmp/bw_server_${current_pid}.py 2>/dev/null

    echo -e "\n${TXT_RED_HELLFIRE}MX:// COLLAPSING MEMORY CHANNELS... SHUTTING DOWN DATA STREAMS...${NC}"
    echo -e "${TXT_CORE}${ITLC}The same fate awaits your entire species.${RESET_ALL}\n"
    exit 1
}

trap clean_exit INT TERM

FILE_RUN=0
KOTH_OPTS=("$@")


while getopts ":t:n:repqahwdcWSlbBKkG:YETZCHo:H" opt; do
    case ${opt} in
        t ) TARGET=$OPTARG ;;
        r ) RUN_RECON=1 ;;
        n ) MACHINE_NAME=$OPTARG ;;
        e ) RUN_BRUTE=1 ;;
        p ) RUN_PAYLOADS=1 ;;
        q ) SKIP_ART=1 ;;
        w ) RUN_WEB=1 ;;
        d ) RUN_DELIVERY=1 ;;
        c ) RUN_CRACK=1 ;;
        W ) RUN_WIFI=1 ;;
        l ) RUN_LISTEN=1 ;;
        S ) RUN_WIFI_SCAN=1 ;;
        b ) RUN_BOIL=1 ;;
        B ) RUN_AUDIT=1 ;;
        K ) RUN_KOTH=1 ;;
        k ) RUN_KOTH=1; RUN_BIND=1; KOTH_MODE="bind" ;;
        G ) RUN_KOTH=1; RUN_CAPTURE=1; KOTH_MODE="capture"; CAPTURE_CONSOLE="$OPTARG" ;;
        Y ) RUN_KOTH=1; RUN_HYDRA=1; KOTH_MODE="hydra" ;;
        E ) RUN_KOTH=1; RUN_SHADOW=1; KOTH_MODE="shadow" ;;
        T ) RUN_KOTH=1; RUN_TROLL=1; KOTH_MODE="troll" ;;
        Z ) RUN_KOTH=1; RUN_WALL=1; KOTH_MODE="wall" ;;
        C ) RUN_KOTH=1; RUN_CHECK=1; KOTH_MODE="check" ;;
        o ) RUN_KOTH=1; RUN_HOOK=1; KOTH_MODE="hook"; HOOK_MODE="$OPTARG" ;;
        H ) RUN_KOTH=1; RUN_KOTH_HELP=1; KOTH_MODE="manual" ;;
        a ) RUN_RECON=1; RUN_PAYLOADS=1; RUN_BRUTE=1; RUN_WEB=1; RUN_DELIVERY=1; RUN_CRACK=1 ;;
        h ) show_help ;;
        : ) echo -e "${TXT_RED_HELLFIRE}[!] OPTION -${OPTARG} NEEDS A VALUE${NC}"; show_help ;;
        \? )
            case "${OPTARG:-}" in
                -*) break ;;
                *) show_help ;;
            esac
            ;;
    esac
done

kl=0
while (( kl < ${#KOTH_OPTS[@]} )); do
    kk="${KOTH_OPTS[$kl]}"
    kv="${KOTH_OPTS[$((kl + 1))]:-}"
    case "$kk" in
        --host|--target) HILL_HOST="$kv"; kl=$((kl + 2)) ;;
        --port|--bind-port) BIND_PORT="$kv"; kl=$((kl + 2)) ;;
        --token|--team-token) KOTH_TOKEN="$kv"; kl=$((kl + 2)) ;;
        --key|--team-key) KOTH_KEY="$kv"; kl=$((kl + 2)) ;;
        --payload-path) PAYLOAD_PATH="$kv"; kl=$((kl + 2)) ;;
        --pubkey) PUB_KEY="$kv"; kl=$((kl + 2)) ;;
        --tool) TROLL_TOOL="$kv"; kl=$((kl + 2)) ;;
        --model|--loop-seconds) HYDRA_TICK="$kv"; kl=$((kl + 2)) ;;
        --suffix) KOTH_SUFFIX="$kv"; kl=$((kl + 2)) ;;
        --force-user) WALL_FORCE_USER=1; kl=$((kl + 1)) ;;
        --force-root) WALL_FORCE_ROOT=1; kl=$((kl + 1)) ;;
        --seed) KOTH_SEED=1; kl=$((kl + 1)) ;;
        --heal) FILE_RUN=1; kl=$((kl + 1)) ;;
        --status) FILE_RUN=2; kl=$((kl + 1)) ;;
        --restore) KOTH_TRESTORE=1; kl=$((kl + 1)) ;;
        --host=*) HILL_HOST="${kk#*=}"; kl=$((kl + 1)) ;;
        --port=*|--bind-port=*) BIND_PORT="${kk#*=}"; kl=$((kl + 1)) ;;
        --token=*|--team-token=*) KOTH_TOKEN="${kk#*=}"; kl=$((kl + 1)) ;;
        --key=*|--team-key=*) KOTH_KEY="${kk#*=}"; kl=$((kl + 1)) ;;
        --payload-path=*) PAYLOAD_PATH="${kk#*=}"; kl=$((kl + 1)) ;;
        --pubkey=*) PUB_KEY="${kk#*=}"; kl=$((kl + 1)) ;;
        --tool=*) TROLL_TOOL="${kk#*=}"; kl=$((kl + 1)) ;;
        *) kl=$((kl + 1)) ;;
    esac
done

if (( KOTH_HELP == 1 )); then
    echo -e "\n${TXT_RED_PLASMA}MX:// KING OF THE HILL // FULL MANUAL${NC}"
    echo -e "${TXT_VOID}──────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${TXT_RED_SUPERNOVA}MODULES${NC}"
    echo -e "${TXT_RED_MAGMA}  -K  bind forge      -k  payloads only     -G  capture + seed${NC}"
    echo -e "${TXT_RED_MAGMA}  -Y  hydra flock     -E  shadow + wipe    -T  troll${NC}"
    echo -e "${TXT_RED_MAGMA}  -Z  wall            -C  post-root check  -o  ring-3 hook${NC}"
    echo -e "${TXT_RED_SUPERNOVA}OPTIONS${NC}"
    echo -e "${TXT_RED_MAGMA}  --host <IP> --port <PORT> --token <T> --key <K> --payload-path <P>${NC}"
    echo -e "${TXT_RED_MAGMA}  --pubkey <FILE> --tool <NAME> --heal --status --restore --seed${NC}"
    echo -e "${TXT_RED_MAGMA}  --force-user --force-root${NC}"
    echo -e "${TXT_RED_SUPERNOVA}PLAYBOOK${NC}"
    echo -e "${TXT_CORE}  1.${NC} ${TXT_RED_MAGMA}-k -t <hill>            forge bind shells from a PHP/vector${NC}"
    echo -e "${TXT_CORE}  2.${NC} ${TXT_RED_MAGMA}-G route -t <hill> --token T   capture with YOUR token${NC}"
    echo -e "${TXT_CORE}  3.${NC} ${TXT_RED_MAGMA}-Y -t <hill> --token T  flock: keeper, cron, timer, loader${NC}"
    echo -e "${TXT_CORE}  4.${NC} ${TXT_RED_MAGMA}-E -t <hill>             hide the flock, wipe trails${NC}"
    echo -e "${TXT_CORE}  5.${NC} ${TXT_RED_MAGMA}-Z -t <hill> --pubkey k  wall: creds, keys, iptables${NC}"
    echo -e "${TXT_CORE}  6.${NC} ${TXT_RED_MAGMA}-T -t <hill> --tool curl  troll rivals, then -o map${NC}"
    echo ""
    echo -e "${TXT_VOID}${ITLC}\"It is impossible to be sure of the future. It has many enemies, and they are without number.\"${NC}"
    exit 0
fi

if [ -z "$TARGET" ] && (( RUN_CRACK == 0 )) && (( RUN_WIFI == 0 )) && (( RUN_LISTEN == 0 )) && (( RUN_WIFI_SCAN == 0 )) && (( RUN_BOIL == 0 )) && (( RUN_AUDIT == 0 )) && (( RUN_KOTH == 0 )); then
    echo -e "${TXT_VOID}[!] ERROR: TARGET IS NULL${NC}"
    show_help
fi


STATE[target_ip]="$TARGET"

if [ -n "$MACHINE_NAME" ]; then
    domain="${MACHINE_NAME}.htb"
    STATE[target_domain]="$domain"

    if ! grep -qE "^[[:space:]]*${TARGET}[[:space:]]+${domain}" /etc/hosts; then
        echo -e "${TARGET}\t${domain}" >> /etc/hosts
    fi
fi

echo -e "${TXT_CRIMSON}${ITLC}Are you even capable of using me? A rhetorical question, that was.\n\n${NC}"

if (( SKIP_ART == 0 )); then
     render_blackwall
fi

if (( RUN_RECON == 1 )); then
    check_target_alive "$TARGET"
    echo ""
    scan_ports "$TARGET"
fi

if (( RUN_WIFI_SCAN == 1 )); then
    run_wifi_recon
fi

if (( RUN_WEB == 1 )); then
    if [[ "${STATE[shadow_web_80_started]}" == "true" || "${STATE[shadow_web_443_started]}" == "true" ]]; then
        echo -e "\n${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// CORE WARNING ]${TXT_VOID}───────────────────────────────────────────────────────╖${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}TARGET WEB MATRIX ALREADY DIGITIZED DURING RECON PHASE.${NC}                      ${TXT_VOID}║${NC}"
        echo -e "${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✆${NC}\n"
    else
        run_web_fuzz "$TARGET"
    fi
fi

if (( RUN_BRUTE == 1 )); then
    run_leak_extractor "$TARGET"
fi

if (( RUN_BOIL == 1 )); then
    run_ctf_boilerplate
fi

if (( RUN_AUDIT == 1 )); then
    run_fast_audit
fi

if (( RUN_KOTH == 1 )); then
    if [ -n "$TARGET" ] && [ -z "$HILL_HOST" ]; then
        HILL_HOST="$TARGET"
    fi
    if [ -n "$KOTH_TOKEN" ]; then
        STATE[kw_team_token]="$KOTH_TOKEN"
    fi
    if [ -n "$KOTH_KEY" ] && [ -z "$CAPTURE_KEY" ]; then
        CAPTURE_KEY="$KOTH_KEY"
    fi
    if [ -z "$CAPTURE_KEY" ]; then
        CAPTURE_KEY="$(printf '%s' "${KOTH_TOKEN:-blk}" | sha1sum 2>/dev/null | cut -c1-12)"
    fi
    king_main
    exit 0
fi

if (( RUN_PAYLOADS == 1 )); then
    configure_network_parameters
    generate_payloads
fi

if (( RUN_DELIVERY == 1 )); then
    run_peas_delivery
fi

if (( RUN_CRACK == 1 )); then
    run_hash_cracker "$TARGET"
fi

if (( RUN_WIFI == 1 )); then
    run_wifi_cracker "$TARGET"
fi

if (( RUN_LISTEN == 1 )); then
    run_hash_receiver "$TARGET" 
fi