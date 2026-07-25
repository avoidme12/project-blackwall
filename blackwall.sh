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
source "${BASE_DIR}/daemons/wifi_cracker.sh" # Новый демон

if (( EUID != 0 )); then
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
RUN_WIFI=0 # Переменная управления Wi-Fi дешифратором

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
    echo -e "  -q         Skip art"
    echo -e "  -a         Run all modules"
    echo -e "  -h         Help"
    exit 1
}

clean_exit() {
    local current_pid=$$
    cleanup_hosts

    if [ -n "${STATE[web_server_pid]}" ]; then
        kill "${STATE[web_server_pid]}" 2>/dev/null
    fi

    if [ -n "${STATE[target_domain]}" ]; then
            sed -i "/[[:space:]]${STATE[target_domain]}$/d" /etc/hosts 2>/dev/null
    fi
    rm -f /tmp/blackwall_async_${current_pid} 2>/dev/null
    rm -f /tmp/blackwall_ffuf_${current_pid}.json 2>/dev/null
    rm -f /tmp/blackwall_vhost_${current_pid}.json 2>/dev/null
    rm -f /tmp/wifi_target_${current_pid}.hc22000 2>/dev/null

    echo -e "\n${TXT_RED_HELLFIRE}MX:// COLLAPSING MEMORY CHANNELS... SHUTTING DOWN DATA STREAMS...${NC}"
    echo -e "${TXT_CORE}${ITLC}The same fate awaits your entire species.${RESET_ALL}\n"
    exit 1
}

trap clean_exit INT TERM

while getopts "t:n:repqahwdcW" opt; do
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
        W ) RUN_WIFI=1 ;; # Обработка флага -W
        a ) RUN_RECON=1; RUN_PAYLOADS=1; RUN_BRUTE=1; RUN_WEB=1; RUN_DELIVERY=1; RUN_CRACK=1 ;;
        h ) show_help ;;
        \? ) show_help ;;
    esac
done

# Если выбран автономный запуск хэшкракера (-c) или вайфай-кракера (-W), IP цели можно не задавать
if [ -z "$TARGET" ] && (( RUN_CRACK == 0 )) && (( RUN_WIFI == 0 )); then
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