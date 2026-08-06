#!/bin/bash

run_fast_audit() {
    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// RAPID LOCAL SYSTEM AUDITOR (FIRST MINUTE) ]${TXT_VOID}────────────────╖${NC}"
    local sep_bot="${TXT_}╙──────────────────────────────────────────────────────────────────────────────✆${NC}"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}Copy and run this command directly in remote terminal to find quick wins:${NC}"
    echo -e "${TXT_VOID}│${NC}"

    local cmd="echo '=== SUDO ==='; sudo -l 2>/dev/null; echo '=== SUID ==='; find / -type f -perm -4000 -ls 2>/dev/null | grep -vE '/usr/bin/|/usr/lib/|/bin/'; echo '=== WRITABLE ETC ==='; [ -w /etc/passwd ] && echo 'Writable /etc/passwd!'; echo '=== NET STAT ==='; ss -lnpt 2>/dev/null || cat /proc/net/tcp 2>/dev/null"

    echo -e "${TXT_VOID}├─${TXT_SCARLET}[ Quick Audit One-Liner ]: ${NC}"
    echo -e "${TXT_B_LASER}${cmd}${NC}"
    echo -e "$sep_bot\n"
}