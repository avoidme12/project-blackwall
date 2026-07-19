#!/bin/bash

add_to_hosts() {
    local ip=$1
    local domain=$2
    local hosts_file="/etc/hosts"

    if [ -z "$ip" ] || [ -z "$domain" ]; then
        return 1
    fi

    if grep -qE "^[[:space:]]*${ip}[[:space:]]+${domain}" "$hosts_file"; then
        return 0
    fi

    echo -e "${ip}\t${domain}" >> "$hosts_file"

    if [ -z "${STATE[added_hosts]}" ]; then
        STATE[added_hosts]="$domain"
    else
        STATE[added_hosts]="${STATE[added_hosts]},$domain"
    fi

    echo -e "  ${TXT_VOID}├─${TXT_B_ALARM}[ DNS ]${NC} ${TXT_RED_MAGMA}Mapping synchronized:${NC} ${TXT_RED_SUPERNOVA}${ip}${NC} ${TXT_VOID}»${NC} ${TXT_RED_HELLFIRE}${domain}${NC}"
}

cleanup_hosts() {
    local hosts_file="/etc/hosts"
    if [ -z "${STATE[added_hosts]}" ]; then
        return
    fi

    IFS=',' read -ra ADDR <<< "${STATE[added_hosts]}"
    for domain in "${ADDR[@]}"; do
        if [ -n "$domain" ]; then
            sed -i "/[[:space:]]${domain}$/d" "$hosts_file" 2>/dev/null
        fi
    done
}