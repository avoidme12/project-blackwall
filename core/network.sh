#!/bin/bash

detect_local_ip() {
    local vpn_ip=$(ip -o -4 addr show dev tun0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)

    if [ -n "$vpn_ip" ]; then
        STATE[lhost]="$vpn_ip"
        return 0
    fi

    local default_ip=$(ip -o -4 addr show | grep -vE '127.0.0.1|tun0' | head -n 1 | awk '{print $4}' | cut -d/ -f1)

    if [ -n "$default_ip" ]; then
        STATE[lhost]="$default_ip"
        return 0
    fi

    STATE[lhost]="127.0.0.1"
}

configure_network_parameters() {
    detect_local_ip

    echo -e "${TXT_DRK_RED}============================================================${NC}"
    echo -e "${TXT_PULSE_RED}[///] CONFIGURING CONNECTION PARAMETERS...${NC}"

    echo -ne "${TXT_MID_RED}[ ? ] Confirm LHOST [${TXT_CORE}${STATE[lhost]}${TXT_MID_RED}] (Press Enter or type new IP): ${NC}"
    read -r user_ip
    if [ -n "$user_ip" ]; then
        STATE[lhost]="$user_ip"
    fi

    STATE[lport]="4444"
    echo -ne "${TXT_MID_RED}[ ? ] Confirm LPORT [${TXT_CORE}${STATE[lport]}${TXT_MID_RED}] (Press Enter or type new port): ${NC}"
    read -r user_port
    if [ -n "$user_port" ]; then
        STATE[lport]="$user_port"
    fi
    echo -e "${TXT_DRK_RED}============================================================${NC}\n"
}