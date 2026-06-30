#!/bin/bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

source "${BASE_DIR}/core/colors.sh"
source "${BASE_DIR}/core/ui.sh"
source "${BASE_DIR}/daemons/recon.sh"
source "${BASE_DIR}/daemons/bruteforce.sh"
source "${BASE_DIR}/daemons/weaponize.sh"

if (( EUID != 0 )); then
    echo -e "${TXT_CORE}${ITLC}It is you who should be following orders, not I.\n\n${NC}"
    exit 1
fi
trap 'echo -e "\n${TXT_CORE}[*] The same fate awaits your entire species.${NC}"; exit 1' INT

TARGET=""
RUN_RECON=0
RUN_PAYLOADS=0
RUN_BRUTE=0
SKIP_ART=0

show_help() {
    echo -e "${TXT_RED}PROJECT BLACKWALL v1.0${NC}"
    echo -e "Использование: $0 -t <IP> [ОПЦИИ]"
    echo -e "\nОпции:"
    echo -e "  -t <IP>    Задать цель (Target IP)"
    echo -e "  -r         Разведка (Recon: Ping + Port Scan)"
    echo -e "  -b         Перебор (Bruteforce)"
    echo -e "  -p         Генератор Payload-ов"
    echo -e "  -q         Пропустить анимацию (Тихий режим)"
    echo -e "  -a         Запустить ВСЕ модули сразу"
    echo -e "  -h         Справка"
    exit 1
}

while getopts "t:rbpqah" opt; do
    case ${opt} in
        t ) TARGET=$OPTARG ;;
        r ) RUN_RECON=1 ;;
        b ) RUN_BRUTE=1 ;;
        p ) RUN_PAYLOADS=1 ;;
        q ) SKIP_ART=1 ;;
        a ) RUN_RECON=1; RUN_PAYLOADS=1; RUN_BRUTE=1 ;;
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
    echo -e "${TXT_CRIMSON}${ITLC}You seek the key to a door that does not exist. Typical of your kind.${NC}"
    scan_ports "$TARGET"
fi

if (( RUN_BRUTE == 1 )); then
    run_bruteforce "$TARGET"
fi

if (( RUN_PAYLOADS == 1 )); then
    generate_payloads
fi
