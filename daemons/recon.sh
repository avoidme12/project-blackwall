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

    local async_log="/tmp/blackwall_async_$$"
    rm -f "$async_log"
    mkfifo "$async_log"

    exec 3<> "$async_log"

    echo -e "${TXT_DRK_RED}============================================================${NC}"
    echo -e "${TXT_PULSE_RED}[///] INITIATING SYNAPTIC SCAN ON ${TXT_CORE}$ip${NC}"
    echo -e "${TXT_MID_RED}[ i ] PROFILE: -sC -sV -p- -A -Pn -v --min-rate 1000${NC}"
    echo -e "${TXT_DRK_RED}============================================================${NC}\n"

    STATE[shadow_web_80_started]="false"
    STATE[shadow_web_443_started]="false"
    STATE[shadow_web_80_pid]=""
    STATE[shadow_web_443_pid]=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([0-9]+)/tcp[[:space:]]+open ]]; then
            local port="${BASH_REMATCH[1]}"
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
                run_shadow_web_fuzz "$ip" "80" "$async_log" &
                STATE[shadow_web_80_pid]=$!
            fi

            if [[ "$disc_port" == "443" && "${STATE[shadow_web_443_started]}" == "false" ]]; then
                STATE[shadow_web_443_started]="true"
                run_shadow_web_fuzz "$ip" "443" "$async_log" &
                STATE[shadow_web_443_pid]=$!
            fi
        fi

    done < <(nmap -sC -sV -p- -A -Pn -v --min-rate 1000 "$ip" -oN "$output_file" 2>/dev/null)

    echo -ne "\r\033[K"

    local ports_string=$(IFS=, ; echo "${local_ports[*]}")
    STATE[open_ports]="$ports_string"

    if [ ${#local_ports[@]} -gt 0 ]; then
      ai_speak "Target neural network acquired. Data migration to primary matrix - complete."
    else
      ai_speak "You seek the key to a door that does not exist. Typical of your kind."
    fi

    if [[ "${STATE[shadow_web_80_started]}" == "true" || "${STATE[shadow_web_443_started]}" == "true" ]]; then
        echo -e "\n${TXT_DRK_RED}============================================================${NC}"
        echo -e "${TXT_PULSE_RED}[///] SYNCHRONIZING ASYNC DAEMONS...${NC}"
        echo -e "${TXT_MID_RED}[ i ] Streaming background discoveries in real-time:${NC}\n"

        local spinner=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
        local spin_idx=0
        local elapsed=0
        local tick_counter=0

        while true; do
            local p80="${STATE[shadow_web_80_pid]}"
            local p443="${STATE[shadow_web_443_pid]}"
            local running=0

            if [ -n "$p80" ] && kill -0 "$p80" 2>/dev/null; then running=1; fi
            if [ -n "$p443" ] && kill -0 "$p443" 2>/dev/null; then running=1; fi

            while IFS= read -r -t 0.05 line <&3; do
                echo -e "\r\033[K${line}"
            done

            if (( running == 0 )); then
                break
            fi

            echo -ne "\r${TXT_DRK_RED}[ ${spinner[spin_idx]} ] Syncing background fuzzers... [Elapsed: ${elapsed}s]${NC}\033[K"

            sleep 0.1

            ((spin_idx = (spin_idx + 1) % 10))
            ((tick_counter++))

            if (( tick_counter >= 10 )); then
                ((elapsed++))
                tick_counter=0
            fi
        done

        while IFS= read -r -t 0.05 line <&3; do
            echo -e "\r\033[K${line}"
        done
        echo -ne "\r\033[K"

        exec 3<&-
        rm -f "$async_log"

        echo -e "\n${TXT_SCARLET}[*] All background streams resolved.${NC}"
    fi
}