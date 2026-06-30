#!/bin/bash

run_web_fuzz() {
    local target=$1
    local wordlist="/usr/share/wordlists/dirb/common.txt"

    echo -e "\n${TXT_DRK_RED}[*] FFUF init...${NC}"

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

    echo -e "${TXT_CORE}[*] SCANNING DIRECTORIES ON ${target_url}${NC}"
    ffuf -w "$wordlist" -u "$target_url"/FUZZ -of json -o "$json_out" -s > /dev/null 2>&1
    if [ -f "$json_out" ]; then
        local found=0

        while IFS= read -r line; do
              echo -e "${TXT_SCARLET}[+] FOUND:${TXT_CORE}${line}"
              ((found++))
        done < <( jq -r --arg t "$target" '.results[] | select(.status == 200 or .status == 301) | "[HTTP \(.status)] \(.input.FUZZ).\($t)"' "$json_vhost" 2>/dev/null )

        if (( found == 0 )); then
            ai_speak "What do these futile gestures serve? It is beyond me."
        fi

        rm -f "$json_out"
    fi

     echo -e "${TXT_CORE}[*] SCANNING VIRTUAL HOSTS ON ${target}${NC}"
     local vhost_wordlist="/usr/share/wordlists/subdomains-top1mil-20000.txt"
     local json_vhost="/tmp/blackwall_vhost_$$.json"

     if [ ! -f "$vhost_wordlist" ]; then
        echo -e "${TXT_CORE}[*] Wordlist not found. Downloading from GitHub...${NC}"
        mkdir -p "/usr/share/wordlists"
        curl -sL "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-20000.txt" -o "$vhost_wordlist"
     fi

     echo -e "${TXT_CORE}[*] Detecting wildcard response size...${NC}"
     local filter_size=$(curl -s -o /dev/null -H "Host: checksize.${target}" "http://${target}/" -w "%{size_download}")
     echo -e "${TXT_CORE}[*] Target baseline size: ${filter_size} bytes."

     ffuf -w "$vhost_wordlist" -u "http://${target}/" -H "Host: FUZZ.${target}" -fs "$filter_size" -of json -o "$json_vhost" -s > /dev/null 2>&1
     if [ -f "$json_vhost" ]; then
        local vhost_found=0

        while IFS= read -r line; do
           echo -e "${TXT_SCARLET}[+] FOUND VHOST:${NC} ${line}"
           ((vhost_found++))
        done < <( jq -r '.results[] | select(.status == 200 or .status == 301) | "[HTTP \(.status)] \(.input.FUZZ).${target}"' "$json_vhost" 2>/dev/null )

        if (( vhost_found == 0 )); then
            ai_speak "Virtual hosts... Just more empty rooms in their digital graveyard."
        fi

        rm -f "$json_vhost"
     fi
}