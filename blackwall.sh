#!/bin/bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

source "${BASE_DIR}/core/colors.sh"
source "${BASE_DIR}/core/ui.sh"
source "${BASE_DIR}/daemons/recon.sh"
source "${BASE_DIR}/daemons/bruteforce.sh"
source "${BASE_DIR}/daemons/weaponize.sh"
source "${BASE_DIR}/core/state.sh"
source "${BASE_DIR}/daemons/web_fuzz.sh"

if (( EUID != 0 )); then
    echo -e "${TXT_CORE}${ITLC}It is you who should be following orders, not I.\n\n${NC}"
    exit 1
fi

TARGET=""
RUN_RECON=0
RUN_PAYLOADS=0
RUN_BRUTE=0
SKIP_ART=0
RUN_WEB=0

show_help() {
    echo -e "${TXT_RED}PROJECT BLACKWALL v1.0${NC}"
    echo -e "Использование: $0 -t <IP> [ОПЦИИ]"
    echo -e "\nОпции:"
    echo -e "  -t <IP>    Target IP"
    echo -e "  -r         Recon: Ping + Port Scan"
    echo -e "  -b         Bruteforce"
    echo -e "  -p         Payloads gen"
    echo -e "  -q         Skip art"
    echo -e "  -a         Run all modules"
    echo -e "  -h         Help"
    exit 1
}

clean_exit() {
    local current_pid=$$
    rm -f /tmp/blackwall_async_${current_pid}.log 2>/dev/null
    rm -f /tmp/blackwall_ffuf_${current_pid}.json 2>/dev/null
    rm -f /tmp/blackwall_vhost_${current_pid}.json 2>/dev/null
    echo -e "\n${TXT_CORE}${ITLC}The same fate awaits your entire species.${NC}"
    exit 1
}

trap clean_exit INT TERM

while getopts "t:rbpqahw" opt; do
    case ${opt} in
        t ) TARGET=$OPTARG ;;
        r ) RUN_RECON=1 ;;
        b ) RUN_BRUTE=1 ;;
        p ) RUN_PAYLOADS=1 ;;
        q ) SKIP_ART=1 ;;
        w ) RUN_WEB=1 ;;
        a ) RUN_RECON=1; RUN_PAYLOADS=1; RUN_BRUTE=1; RUN_WEB=1 ;;
        h ) show_help ;;
        \? ) show_help ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo -e "${TXT_VOID}[!] ERROR: TARGET IS NULL${NC}"
    show_help
fi

clear
echo -e "${TXT_CRIMSON}${ITLC}Are you even capable of using me? A rhetorical question, that was.\n\n${NC}"

if (( SKIP_ART == 0 )); then
     render_blackwall
fi

if (( RUN_RECON == 1 )); then
    check_target_alive "$TARGET"
    echo ""
    scan_ports "$TARGET"
fi

if (( RUN_WEB == 1 )); then
    run_web_fuzz "$TARGET"
fi

if (( RUN_BRUTE == 1 )); then
    run_bruteforce "$TARGET"
fi

if (( RUN_PAYLOADS == 1 )); then
    generate_payloads
fi
