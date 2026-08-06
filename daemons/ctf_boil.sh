#!/bin/bash

run_ctf_boilerplate() {
    local target="${STATE[target_ip]}"
    local domain="${STATE[target_domain]}"
    local host_target="${target}"

    if [ -n "$domain" ]; then
        host_target="$domain"
    fi

    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// CTF BOILERPLATE GENERATOR ACTIVE ]${TXT_VOID}──────────────────────────╖${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✆${NC}"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// GENERATING EXPLOIT TEMPLATES FOR TARGET...${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[1] Pwn / Binary Exploitation (pwntools template)${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[2] Web / API Exploitation (requests + Burp proxy template)${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}Select template [1/2]: ${NC}"
    read -r tmpl_choice

    if [ "$tmpl_choice" == "1" ]; then
        local out_pwn="solve.py"
        cat << 'EOF_PWN' > "$out_pwn"
#!/usr/bin/env python3
from pwn import *

context.binary = './chall'
context.log_level = 'info' # 'debug' for raw traffic

elf = ELF(context.binary.path)
rop = ROP(elf)

# local execution
p = process(context.binary.path)

# remote execution (uncomment and fill)
# p = remote('TARGET_IP', 1337)

# --- TARGET METADATA ---
# offset = 72
# target_addr = elf.symbols['win']

# --- CONSTRUCT PAYLOAD ---
# payload = b"A" * offset + p64(target_addr)

# --- SEND & INTERACT ---
# p.sendlineafter(b"> ", payload)
p.interactive()
EOF_PWN
        chmod +x "$out_pwn"
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] SUCCESS: generated executable binary exploit template: ${TXT_RED_SUPERNOVA}${out_pwn}${NC}"

    elif [ "$tmpl_choice" == "2" ]; then
        local out_web="exploit.py"
        cat << EOF_WEB > "$out_web"
#!/usr/bin/env python3
import requests
import urllib3

# Отключаем предупреждения об отсутствии SSL-сертификата
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

TARGET_URL = "http://${host_target}"
# Проксирование трафика через Burp Suite для дебага запросов на лету
PROXIES = {
    "http": "http://127.0.0.1:8080",
    "https": "http://127.0.0.1:8080"
}

session = requests.Session()
session.proxies.update(PROXIES)
session.verify = False  # Игнорировать SSL-ошибки

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Blackwall/1.0",
}

def exploit():
    # --- STEP 1: Auth / Leak ---
    # response = session.get(f"{TARGET_URL}/api/endpoint", headers=headers)
    # print(response.text)

    # --- STEP 2: Attack ---
    # payload = {"input": "test"}
    # r = session.post(f"{TARGET_URL}/submit", json=payload, headers=headers)
    pass

if __name__ == "__main__":
    exploit()
EOF_WEB
        chmod +x "$out_web"
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] SUCCESS: generated web/api exploit template: ${TXT_RED_SUPERNOVA}${out_web}${NC}"
    fi
    echo -e "$sep_bot\n"
}