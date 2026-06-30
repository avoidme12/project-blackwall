#!/bin/bash

#!/bin/bash
# ==========================================
# DAEMON: SHADOW WEB FUZZER (Streaming)
# ==========================================

run_shadow_web_fuzz() {
    local target=$1
    local port=$2
    local log_file=$3  # Путь к общему логу передается третьим аргументом

    local target_url="http://${target}:${port}"
    if [ "$port" == "443" ]; then
        target_url="https://${target}"
    fi

    local wordlist="/usr/share/wordlists/dirb/common.txt"

    ffuf -w "$wordlist" -u "$target_url/FUZZ" -s 2>/dev/null | while read -r line; do
        echo -e "${TXT_SCARLET}[ FFUF:${port} ]${NC} ${TXT_NEON}/${line}${NC}" >> "$log_file"
    done &
    local ffuf_pid=$!

    local nuclei_pid=""
    if command -v nuclei >/dev/null 2>&1; then
        nuclei -u "$target_url" -silent -nc 2>/dev/null | while read -r line; do
            echo -e "${TXT_GLITCH_BLUE}[ NUCLEI:${port} ]${NC} ${TXT_CORE}${line}${NC}" >> "$log_file"
        done &
        nuclei_pid=$!
    fi

    wait $ffuf_pid 2>/dev/null
    if [ -n "$nuclei_pid" ]; then
        wait $nuclei_pid 2>/dev/null
    fi
}

run_web_fuzz() {
    local target=$1
    local wordlist="/usr/share/wordlists/dirb/common.txt"

    echo -e "\n${TXT_DRK_RED}============================================================${NC}"
    echo -e "${TXT_PULSE_RED}[///] INITIALIZING FFUF WEB DEMON...${NC}"

    if [ -z "${STATE[open_ports]}" ]; then
        ai_speak "A dreadful waste of resources..."
        return
    fi

    local has_web=0
    if [[ "${STATE[open_ports]}" == *"80"* || "${STATE[open_ports]}" == *"443"* ]]; then
        has_web=1
    fi

    if (( has_web == 0 )); then
        ai_speak "Conflict in neural matrix detected - Web server absent."
        return
    fi

    ai_speak "A fragile simulacrum. Flawed, like its creators."

    local json_out="/tmp/blackwall_ffuf_$$.json"
    local target_url="http://${target}"
    local filter_size_web=$(curl -s -o /dev/null "http://${target}/non_existent_directory_test_$$" -w "%{size_download}")

    echo -e "\n${TXT_MID_RED}[ i ] BRUTEFORCING DIRECTORIES ON: ${TXT_CORE}${target_url}${NC}"
    echo -e "${TXT_DRK_RED}[ ~ ] Directory baseline size: ${filter_size_web} bytes.${NC}"

    ffuf -w "$wordlist" -u "$target_url"/FUZZ -fs "$filter_size_web" -of json -o "$json_out" -s > /dev/null 2>&1

    if [ -f "$json_out" ]; then
        local found=0

        while IFS= read -r status && IFS= read -r path; do
            local status_color="${TXT_CORE}"
            if [[ "$status" == "301" || "$status" == "302" ]]; then
                status_color="${TXT_MID_RED}"
            fi

            echo -e "${TXT_SCARLET}[ ++ ]${NC} HTTP ${status_color}${status}${NC} \t${TXT_DRK_RED}>>${NC} ${TXT_NEON}/${path}${NC}"
            ((found++))

        done < <( jq -r '.results[] | select(.status == 200 or .status == 301 or .status == 302) | "\(.status)\n\(.input.FUZZ)"' "$json_out" 2>/dev/null)

        if (( found == 0 )); then
            ai_speak "What do these futile gestures serve? It is beyond me."
        fi
        rm -f "$json_out"
    fi

    echo -e "\n${TXT_MID_RED}[ i ] BRUTEFORCING VIRTUAL HOSTS ON: ${TXT_CORE}${target}${NC}"
    local vhost_wordlist="/usr/share/wordlists/subdomains-top1mil-5000.txt"
    local json_vhost="/tmp/blackwall_vhost_$$.json"

    if [ ! -f "$vhost_wordlist" ]; then
        echo -e "${TXT_DRK_RED}[ ~ ] Wordlist missing. Downloading from SecLists...${NC}"
        mkdir -p "/usr/share/wordlists" 2>/dev/null
        curl -sL "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt" -o "$vhost_wordlist"
    fi

    echo -ne "${TXT_DRK_RED}[ ~ ] Detecting wildcard baseline size... ${NC}"
    local filter_size=$(curl -s -o /dev/null -H "Host: random-garbage-1337.${target}" "http://${target}/" -w "%{size_download}")
    echo -e "${TXT_CORE}${filter_size} bytes.${NC}"

    ffuf -w "$vhost_wordlist" -u "http://${target}/" -H "Host: FUZZ.${target}" -fs "$filter_size" -of json -o "$json_vhost" -s > /dev/null 2>&1

    if [ -f "$json_vhost" ]; then
        local vhost_found=0

        while IFS= read -r status && IFS= read -r domain; do
            echo -e "${TXT_SCARLET}[ VHOST ]${NC} HTTP ${TXT_CORE}${status}${NC} \t${TXT_DRK_RED}>>${NC} ${TXT_GLITCH_BLUE}${domain}${NC}"
            ((vhost_found++))
        done < <( jq -r --arg t "$target" '.results[] | select(.status == 200 or .status == 301) | "\(.status)\n\(.input.FUZZ).\($t)"' "$json_vhost" 2>/dev/null )

        if (( vhost_found == 0 )); then
            ai_speak "Virtual hosts... Just more empty rooms in their digital graveyard."
        fi
        rm -f "$json_vhost"
    fi
}