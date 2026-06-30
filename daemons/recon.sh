#!/bin/bash

check_target_alive() {
    local ip=$1
    echo -e "${TXT_DRK_RED}[///] CORE INIT: ICMP SWEEP...${NC}"
    if ping -c 1 -W 2 "$ip" > /dev/null 2>&1; then
        echo -e "${TXT_SCARLET}[ ++ ] ${TXT_DRK_RED}TARGET ${TXT_CORE}${ip}${TXT_DRK_RED} IS RESPONDING.${NC}"
    else
        echo -e "\n${TXT_CORE}${ITLC}An unusually high security level. How intriguing...${NC}\n"
        exit 1
    fi
}

scan_ports() {
    local ip=$1
    local output_file="nmap_${ip}.txt"
    local local_ports=()

    echo -e "${TXT_DRK_RED}============================================================${NC}"
    echo -e "${TXT_PULSE_RED}[///] INITIATING SYNAPTIC SCAN ON ${TXT_CORE}$ip${NC}"
    echo -e "${TXT_MID_RED}[ i ] PROFILE: -sC -sV -p- -A -Pn -v --min-rate 5000${NC}"
    echo -e "${TXT_DRK_RED}============================================================${NC}\n"
    STATE[shadow_web_80_started]="false"
    STATE[shadow_web_443_started]="false"

    while IFS= read -r line; do
        if [[ "$line" =~ ^[0-9]+/tcp[[:space:]]+open ]]; then
            local port=$(echo "$line" | awk -F'/' '{print $1}')
            local service=$(echo "$line" | awk '{print $3}')

            local_ports+=("$port")
            echo -e "\r\033[K${TXT_SCARLET}[ ++ ]${NC} PORT: ${TXT_CORE}${port}/tcp${NC} \t${TXT_DRK_RED}>>${NC} SVC: ${TXT_NEON}${service}${NC}"

        elif [[ "$line" =~ ^"OS details:" ]] || [[ "$line" =~ ^"Running:" ]]; then
            local os_info="${line#*: }"
            echo -e "\r\033[K${TXT_GLOW}[ OS ]${NC} TARGET ARCHITECTURE: ${TXT_CORE}${os_info}${NC}"

        elif [[ "$line" =~ ^Discovered[[:space:]]+open[[:space:]]+port[[:space:]]+([0-9]+)/tcp ]]; then
            local disc_port="${BASH_REMATCH[1]}"
            echo -ne "\r${TXT_DRK_RED}[ ~ ] Raw stream detect: port ${disc_port}...${NC}\033[K"

            if [[ "$disc_port" == "80" && "${STATE[shadow_web_80_started]}" == "false" ]]; then
                 STATE[shadow_web_80_started]="true"
                 run_shadow_web_fuzz "$ip" "80" &
                 STATE[shadow_web_80_pid]=$!
            fi

            if [[ "$disc_port" == "443" && "${STATE[shadow_web_443_started]}" == "false" ]]; then
              STATE[shadow_web_443_started]="true"
              run_shadow_web_fuzz "$ip" "443" &
              STATE[shadow_web_443_pid]=$!
            fi
        fi

    done < <(nmap -sC -sV -p- -A -Pn -v --min-rate 5000 "$ip" -oN "$output_file" 2>/dev/null)

    echo -ne "\r\033[K"

    local ports_string=$(IFS=, ; echo "${local_ports[*]}")
    STATE[open_ports]="$ports_string"

    echo ""
    if [ ${#local_ports[@]} -gt 0 ]; then
      ai_speak "Target neural network acquired. Data migration to primary matrix - complete."
    else
      ai_speak "You seek the key to a door that does not exist. Typical of your kind."
    fi

    if [[ "${STATE[shadow_web_80_started]}" == "true" || "${STATE[shadow_web_443_started]}" == "true" ]]; then
            echo -e "\n${TXT_DRK_RED}============================================================${NC}"
            echo -e "${TXT_PULSE_RED}[///] SYNCHRONIZING ASYNC DAEMONS...${NC}"

            while kill -0 "${STATE[shadow_web_80_pid]}" 2>/dev/null || kill -0 "${STATE[shadow_web_443_pid]}" 2>/dev/null; do
                echo -ne "\r${TXT_DRK_RED}[ ~ ] Waiting for background web fuzzers to complete...${NC}\033[K"
                sleep 0.5
            done
            echo -ne "\r\033[K"

            ai_speak "Async streams resolved. Injecting results into main terminal."

            for port in 80 443; do
                local json_out="/tmp/blackwall_ffuf_${ip}_${port}.json"
                local nuclei_out="/tmp/blackwall_nuclei_${ip}_${port}.txt"

                if [ -f "$json_out" ]; then
                    echo -e "${TXT_MID_RED}[ i ] BACKGROUND DIRECTORY DISCOVERY (PORT ${port}):${NC}"

                    while IFS= read -r status && IFS= read -r path; do
                        local status_color="${TXT_CORE}"
                        if [[ "$status" == "301" || "$status" == "302" ]]; then status_color="${TXT_MID_RED}"; fi
                        echo -e "${TXT_SCARLET}[ ++ ]${NC} HTTP ${status_color}${status}${NC} \t${TXT_DRK_RED}>>${NC} ${TXT_NEON}/${path}${NC}"
                    done < <( jq -r '.results[] | select(.status == 200 or .status == 301 or .status == 302) | "\(.status)\n\(.input.FUZZ)"' "$json_out" 2>/dev/null)

                    rm -f "$json_out"
                fi

                if [ -f "$nuclei_out" ] && [ -s "$nuclei_out" ]; then
                    echo -e "\n${TXT_GLITCH_BLUE}[ NUCLEI ] VULNERABILITIES DETECTED:${NC}"
                    cat "$nuclei_out" | while read -r n_line; do
                        echo -e "  ${TXT_DRK_RED}->${NC} ${TXT_CORE}${n_line}${NC}"
                    done
                    rm -f "$nuclei_out"
                fi
            done
    fi
}