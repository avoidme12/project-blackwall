#!/bin/bash

run_shadow_web_fuzz() {
    local target=$1
    local port=$2
    local log_file=$3

    local host_target="${target}"
    if [ -n "${STATE[target_domain]}" ]; then
        host_target="${STATE[target_domain]}"
    fi

    local target_url="http://${host_target}:${port}"
    if [ "$port" == "443" ]; then
        target_url="https://${host_target}"
    fi

    local wordlist="/usr/share/wordlists/dirb/common.txt"
    local filter_size=$(curl -s -o /dev/null -H "User-Agent: Mozilla/5.0" "http://${host_target}:${port}/non_existent_path_$$" -w "%{size_download}")

    echo "INFO:${port}|Detected baseline wildcard size: ${filter_size} bytes." >> "$log_file"
    echo "INFO:${port}|Launching FFUF directory scanner..." >> "$log_file"

    ffuf -w "$wordlist" \
         -u "$target_url/FUZZ" \
         -fs "$filter_size" \
         -t 80 \
         -timeout 5 \
         -s 2>/dev/null | while read -r line; do
        echo "FFUF:${port}|${line}" >> "$log_file"
    done &
    local ffuf_pid=$!

    local nuclei_pid=""
    if command -v nuclei >/dev/null 2>&1; then
        echo "INFO:${port}|Launching Nuclei (Tech detection)..." >> "$log_file"

        nuclei -u "$target_url" \
               -tags tech \
               -silent -nc \
               -bulk-size 10 \
               -concurrency 10 \
               -timeout 2 \
               -me 15s 2>/dev/null | while read -r line; do
            echo "NUCLEI:${port}|${line}" >> "$log_file"
        done &
        nuclei_pid=$!
    fi

    wait $ffuf_pid 2>/dev/null
    echo "INFO:${port}|FFUF scanning finished." >> "$log_file"

    if [ -n "$nuclei_pid" ]; then
        wait $nuclei_pid 2>/dev/null
        echo "INFO:${port}|Nuclei scanning finished." >> "$log_file"
    fi
}

run_web_fuzz() {
    local target=$1
    local wordlist="/usr/share/wordlists/dirb/common.txt"

    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// DIRECTORY & SUBDOMAIN DESTRUCTION MATRIX ]${TXT_VOID}─────────────────╖${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✆${NC}"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// BOOTING TRANS-NET FUZZER ON INTERFACE LYNX_ETHERNET...${NC}"

    if [ -z "${STATE[open_ports]}" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL EXCEPTION: Target open ports vector is unpopulated.${NC}"
        echo -e "$sep_bot\n"
        ai_speak "A dreadful waste of resources..."
        return
    fi

    local has_web=0
    if [[ "${STATE[open_ports]}" == *"80"* || "${STATE[open_ports]}" == *"443"* ]]; then
        has_web=1
    fi

    if (( has_web == 0 )); then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL EXCEPTION: Neural matrix conflict - Web port (80/443) absent.${NC}"
        echo -e "$sep_bot\n"
        ai_speak "Conflict in neural matrix detected - Web server absent."
        return
    fi

    ai_speak "A fragile simulacrum. Flawed, like its creators."
    echo ""

    local json_out="/tmp/blackwall_ffuf_$$.json"
    local host_target="${target}"
    if [ -n "${STATE[target_domain]}" ]; then
        host_target="${STATE[target_domain]}"
    fi

    local target_url="http://${host_target}"
    local filter_size_web=$(curl -s -o /dev/null "http://${target}/non_existent_directory_test_$$" -w "%{size_download}")

    echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ i ] BRUTEFORCING DIRECTORIES ON: ${TXT_RED_SUPERNOVA}${target_url}${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Detected directory wildcard size: ${filter_size_web} bytes.${NC}"
    echo -e "${TXT_VOID}│${NC}"

    ffuf -w "$wordlist" -u "$target_url"/FUZZ -fs "$filter_size_web" -of json -o "$json_out" -s > /dev/null 2>&1

    if [ -f "$json_out" ]; then
        local found=0

        while IFS= read -r status && IFS= read -r path; do
            local status_color="${TXT_RED_HELLFIRE}"
            if [[ "$status" == "301" || "$status" == "302" ]]; then
                status_color="${TXT_RED_ALARM}"
            fi

            echo -e "${TXT_VOID}├─${TXT_CORE}[ ++ ] PATH RESOLVED:${NC} ${status_color}HTTP ${status}${NC} ${TXT_VOID}»${NC} ${TXT_RED_SUPERNOVA}/${path}${NC}"
            ((found++))

        done < <( jq -r '.results[] | select(.status == 200 or .status == 301 or .status == 302) | "\(.status)\n\(.input.FUZZ)"' "$json_out" 2>/dev/null)

        if (( found == 0 )); then
            echo -e "${TXT_VOID}├─${TXT_RED_MAGMA}[ ~ ] Directory brute-force completed with zero results.${NC}"
        fi
        rm -f "$json_out"
    fi

    echo -e "${TXT_VOID}│${NC}"
    echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ i ] BRUTEFORCING VIRTUAL HOST SUBDOMAINS ON: ${TXT_RED_SUPERNOVA}${target}${NC}"
    local vhost_wordlist="/usr/share/wordlists/subdomains-top1mil-5000.txt"
    local json_vhost="/tmp/blackwall_vhost_$$.json"

    if [ ! -f "$vhost_wordlist" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[ ~ ] Subdomain dictionary file missing. Retrieving from SecLists...${NC}"
        mkdir -p "/usr/share/wordlists" 2>/dev/null
        curl -sL "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt" -o "$vhost_wordlist"
    fi

    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Calculating virtual host wildcard baseline... ${NC}"
    local filter_size=$(curl -s -o /dev/null -H "Host: random-garbage-1337.${target}" "http://${target}/" -w "%{size_download}")
    echo -e "${TXT_RED_SUPERNOVA}${filter_size} bytes.${NC}"
    echo -e "${TXT_VOID}│${NC}"

    ffuf -w "$vhost_wordlist" -u "http://${target}/" -H "Host: FUZZ.${target}" -fs "$filter_size" -of json -o "$json_vhost" -s > /dev/null 2>&1

    if [ -f "$json_vhost" ]; then
        local vhost_found=0

        while IFS= read -r status && IFS= read -r domain; do
            echo -e "${TXT_VOID}├─${TXT_CORE}[ ++ ] VHOST MAP RESOLVED:${NC} ${TXT_RED_LASER}HTTP ${status}${NC} ${TXT_VOID}»${NC} ${TXT_RED_SUPERNOVA}${domain}${NC}"
            add_to_hosts "$target" "$domain"
            ((vhost_found++))
        done < <( jq -r --arg t "$target" '.results[] | select(.status == 200 or .status == 301) | "\(.status)\n\(.input.FUZZ).\($t)"' "$json_vhost" 2>/dev/null)

        if (( vhost_found == 0 )); then
            echo -e "${TXT_VOID}├─${TXT_RED_MAGMA}[ ~ ] Subdomain brute-force completed with zero results.${NC}"
        fi
        rm -f "$json_vhost"
    fi

    echo -e "$sep_bot\n"
}