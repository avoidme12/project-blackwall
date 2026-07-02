#!/bin/bash

run_shadow_share_enum() {
    local target=$1
    local port=$2
    local log_file=$3

    if [ "$port" == "2049" ]; then
        echo -e "${TXT_DRK_RED}[ INFO:2049 ]${NC} Launching NFS export scanner..." >> "$log_file"

        local nfs_out=$(showmount -e "$target" 2>/dev/null | tail -n +2)
        if [ -n "$nfs_out" ]; then
            echo -e "${TXT_GLITCH_BLUE}[ NFS ]${NC} Accessible exports found:" >> "$log_file"
            echo "$nfs_out" | while read -r line; do
                echo -e "  ${TXT_CORE}-> ${line}${NC}" >> "$log_file"
            done
        fi
    fi

    if [ "$port" == "445" ]; then
        echo -e "${TXT_DRK_RED}[ INFO:445 ]${NC} Launching SMB NULL-session check..." >> "$log_file"

        local smb_out=$(smbclient -L "//$target" -N 2>/dev/null | grep -E 'Disk|Backup|Share')
        if [ -n "$smb_out" ]; then
            echo -e "${TXT_GLITCH_BLUE}[ SMB ]${NC} Anonymous shares listed:" >> "$log_file"
            echo "$smb_out" | while read -r line; do
                echo -e "  ${TXT_CORE}-> ${line}${NC}" >> "$log_file"
            done
        fi
    fi
}