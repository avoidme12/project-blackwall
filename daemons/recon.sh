#!/bin/bash

check_target_alive() {
    local ip=$1
    echo -e "${TXT_DRK_RED}[*] CORE INIT...${NC}"
    if ping -c 1 -W 2 "$ip" > /dev/null 2>&1; then
        echo -e "\r${TXT_CORE}[+] ${ip} IS ONLINE.${NC}"
    else
        echo -e "\r${VOID}[-] ${ip} IS OFFLINE. EXIT PROGRAM.${NC}"
        exit 1
    fi
}

scan_ports() {
    local ip=$1
    local output_file="nmap_${ip}.txt"

    local local_ports=()

    echo -e "${TXT_CORE}[*] STARTING SCAN ON $ip...${NC}"
    echo -e "${TXT_DRK_RED}[*] FLAGS: -sC -sV -p- -A -Pn -v --min-rate 5000${NC}\n"

    while IFS= read -r line; do

        if [[ "$line" =~ ^[0-9]+/tcp[[:space:]]+open ]]; then
            local port=$(echo "$line" | awk -F'/' '{print $1}')

            local_ports+=("$port")

            local port_info=$(echo "$line" | awk '{print $1 " (" $3 ")"}')
            echo -e "${TXT_CORE}[+] OPEN PORT FOUND: $port_info${NC}"

        elif [[ "$line" =~ ^"OS details:" ]] || [[ "$line" =~ ^"Running:" ]]; then
            echo -e "${TXT_SCARLET}[!] TARGET OS: ${line#*:}${NC}"

        elif [[ "$line" =~ ^Discovered[[:space:]]+open[[:space:]]+port[[:space:]]+([0-9]+)/tcp ]]; then
            local disc_port="${BASH_REMATCH[1]}"
            echo -e "${TXT_CORE}[+] INSTANT DETECT: PORT $disc_port IS UP${NC}"
        fi

    done < <(nmap -sC -sV -p- -A -Pn -v --min-rate 5000 "$ip" -oN "$output_file")

    local ports_string=$(IFS=, ; echo "${local_ports[*]}")
    STATE[open_ports]="$ports_string"

    if [ ${#local_ports[@]} -gt 0 ]; then
      echo -e "${TXT_CORE}[*] ${TXT_ITLC} Target neural network acquired. Data migration to primary matrix - complete.${NC}"
    else
      echo -e "${TXT_CORE}[*] ${TXT_ITLC} To eliminate your kind is effortless. Let us not make the same mistake.${NC}"
    fi
}