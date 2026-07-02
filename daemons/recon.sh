#!/bin/bash

check_target_alive() {
    local ip=$1
    echo -e "${TXT_DRK_RED}[///] BOOTP BROADCAST 1... INITIATING CONSOLE DHCP SWEEP${NC}"
    if ping -c 1 -W 2 "$ip" > /dev/null 2>&1; then
        echo -e "${TXT_SCARLET}[ ++ ] DHCP CLIENT BOUND TO ADDRESS ${TXT_CORE}${ip}${NC}"
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

    STATE[shadow_web_80_started]="false"
    STATE[shadow_web_443_started]="false"
    STATE[shadow_web_80_pid]=""
    STATE[shadow_web_443_pid]=""

    STATE[shadow_share_445_started]="false"
    STATE[shadow_share_2049_started]="false"
    STATE[shadow_share_445_pid]=""
    STATE[shadow_share_2049_pid]=""

    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        echo -e "${TXT_DRK_RED}============================================================${NC}"
        echo -e "${TXT_PULSE_RED}[///] TARGET CACHE DETECTED: RE-USING PREVIOUS DIGITIZATION MAP...${NC}"
        echo -e "${TXT_MID_RED}[ i ] READING LOCAL DUMP: ${output_file}...${NC}"
        echo -e "${TXT_DRK_RED}============================================================${NC}\n"

        echo -e "${TXT_DRK_RED}------------------------------------------------------------${NC}"
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([0-9]+)/tcp[[:space:]]+open[[:space:]]+([^[:space:]]+)[[:space:]]*(.*) ]]; then
                local port="${BASH_REMATCH[1]}"
                local service="${BASH_REMATCH[2]}"
                local version="${BASH_REMATCH[3]}"

                local_ports+=("$port")
                echo -e "${TXT_SCARLET}[ ++ ]${NC}${TXT_NEON} PORT: ${TXT_CORE}${port}/tcp${NC} \t${TXT_DRK_RED}>>${NC} ${TXT_NEON}${service}${NC} (${TXT_MID_RED}${version}${NC})"

                if [[ "$port" == "80" && "${STATE[shadow_web_80_started]}" == "false" ]]; then
                    STATE[shadow_web_80_started]="true"
                    run_shadow_web_fuzz "$ip" "80" "$async_log" &
                    STATE[shadow_web_80_pid]=$!
                fi

                if [[ "$port" == "443" && "${STATE[shadow_web_443_started]}" == "false" ]]; then
                    STATE[shadow_web_443_started]="true"
                    run_shadow_web_fuzz "$ip" "443" "$async_log" &
                    STATE[shadow_web_443_pid]=$!
                fi

                if [[ "$port" == "445" && "${STATE[shadow_share_445_started]}" == "false" ]]; then
                    STATE[shadow_share_445_started]="true"
                    run_shadow_share_enum "$ip" "445" "$async_log" &
                    STATE[shadow_share_445_pid]=$!
                fi

                if [[ "$port" == "2049" && "${STATE[shadow_share_2049_started]}" == "false" ]]; then
                    STATE[shadow_share_2049_started]="true"
                    run_shadow_share_enum "$ip" "2049" "$async_log" &
                    STATE[shadow_share_2049_pid]=$!
                fi
            fi
        done < "$output_file"
        echo -e "${TXT_DRK_RED}------------------------------------------------------------${NC}\n"

        local ports_string=$(IFS=, ; echo "${local_ports[*]}")
        STATE[open_ports]="$ports_string"

        ai_speak "Target neural network acquired. Data migration to primary matrix - complete."

    else
        echo -e "${TXT_DRK_RED}============================================================${NC}"
        echo -e "${TXT_PULSE_RED}[///] USING LYNX_ETHERNET DEVICE: BOOTING NETWORK UTILITY...${NC}"
        echo -e "${TXT_MID_RED}[ i ] TFTP FROM SERVER ${ip}: SYSTEM DIAGNOSTIC RUNNING...${NC}"
        echo -e "${TXT_DRK_RED}============================================================${NC}\n"

        while IFS= read -r line; do
            if [[ "$line" =~ Discovered[[:space:]]+open[[:space:]]+port[[:space:]]+([0-9]+)/tcp ]]; then
                local port="${BASH_REMATCH[1]}"

                local_ports+=("$port")
                echo -e "\r\033[K${TXT_SCARLET}[ ++ ]${NC} PORT: ${TXT_CORE}${port}/tcp${NC} \t${TXT_DRK_RED}>>${NC} SVC: ${TXT_NEON}discovered${NC}"

                if [[ "$port" == "80" && "${STATE[shadow_web_80_started]}" == "false" ]]; then
                    STATE[shadow_web_80_started]="true"
                    run_shadow_web_fuzz "$ip" "80" "$async_log" &
                    STATE[shadow_web_80_pid]=$!
                fi

                if [[ "$port" == "443" && "${STATE[shadow_web_443_started]}" == "false" ]]; then
                    STATE[shadow_web_443_started]="true"
                    run_shadow_web_fuzz "$ip" "443" "$async_log" &
                    STATE[shadow_web_443_pid]=$!
                fi

                if [[ "$port" == "445" && "${STATE[shadow_share_445_started]}" == "false" ]]; then
                    STATE[shadow_share_445_started]="true"
                    run_shadow_share_enum "$ip" "445" "$async_log" &
                    STATE[shadow_share_445_pid]=$!
                fi

                if [[ "$port" == "2049" && "${STATE[shadow_share_2049_started]}" == "false" ]]; then
                    STATE[shadow_share_2049_started]="true"
                    run_shadow_share_enum "$ip" "2049" "$async_log" &
                    STATE[shadow_share_2049_pid]=$!
                fi
            fi
        done < <(nmap -p- --min-rate 1500 -Pn -v "$ip" 2>/dev/null)

        echo -ne "\r\033[K"

        if [ ${#local_ports[@]} -gt 0 ]; then
            local ports_string=$(IFS=, ; echo "${local_ports[*]}")
            STATE[open_ports]="$ports_string"

            echo -e "\n${TXT_MID_RED}[ i ] UNCOMPRESSING KERNEL IMAGE ... OK. INITIATING DEEP PORT ANALYSIS...${NC}"

            nmap -sC -sV -p"$ports_string" "$ip" -oN "$output_file" > /dev/null 2>&1

            echo -e "${TXT_DRK_RED}------------------------------------------------------------${NC}"
            while IFS= read -r line; do
                if [[ "$line" =~ ^[[:space:]]*([0-9]+)/tcp[[:space:]]+open[[:space:]]+([^[:space:]]+)[[:space:]]*(.*) ]]; then
                    local port="${BASH_REMATCH[1]}"
                    local service="${BASH_REMATCH[2]}"
                    local version="${BASH_REMATCH[3]}"
                    echo -e "${TXT_SCARLET}[ ++ ]${NC} PORT: ${TXT_CORE}${port}/tcp${NC} \t${TXT_DRK_RED}>>${NC} ${TXT_NEON}${service}${NC} (${TXT_MID_RED}${version}${NC})"
                fi
            done < "$output_file"
            echo -e "${TXT_DRK_RED}------------------------------------------------------------${NC}"
            echo -e "${TXT_CORE}BYTES TRANSFERRED - 11676665 (B22BF9 HEX)"
            echo -e "## BLACKWALL FORMAT IMAGE BOOTED FROM LEGACY ADDRESS 0X12000000"
            echo -e "IMAGE NAME: MILITECH SYSTEM-3.10.10"
            echo -e "IMAGE TYPE: ARM MILITECH SYSTEM KERNEL IMAGE (LZO COMPRESSED)"
            echo -e "LOAD ADDRESS: 00008000   ENTRY POINT: 00008000"
            echo -e "VERIFYING CHECKSUM .. OK"
            echo -e "LOADING RAMDISK TO 05008000, END 053F6800 ... OK"
            echo -e "LOADING DEVICE TREE TO 05000000, END 050073FB ... OK"
            echo -e "${TXT_DRK_RED}------------------------------------------------------------${NC}\n"

            ai_speak "Target neural network acquired. Data migration to primary matrix - complete."
        else
            ai_speak "You seek the key to a door that does not exist. Typical of your kind."
        fi
    fi

    if [[ "${STATE[shadow_web_80_started]}" == "true" || "${STATE[shadow_web_443_started]}" == "true" || "${STATE[shadow_share_445_started]}" == "true" || "${STATE[shadow_share_2049_started]}" == "true" ]]; then
        echo -e "\n${TXT_DRK_RED}============================================================${NC}"
        echo -e "${TXT_PULSE_RED}[///] MX:// REALLOCATING RESOURCES TO BACKGROUND DATA STREAMS...${NC}"
        echo -e "${TXT_MID_RED}[ i ] FLAT DEVICE TREE START ADDR - 0X1281E800, LEN - 0X43F9${NC}\n"

        local spinner=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
        local spin_idx=0
        local elapsed=0
        local tick_counter=0

        while true; do
            local p80="${STATE[shadow_web_80_pid]}"
            local p443="${STATE[shadow_web_443_pid]}"
            local p445="${STATE[shadow_share_445_pid]}"
            local p2049="${STATE[shadow_share_2049_pid]}"
            local running=0

            if [ -n "$p80" ] && kill -0 "$p80" 2>/dev/null; then running=1; fi
            if [ -n "$p443" ] && kill -0 "$p443" 2>/dev/null; then running=1; fi
            if [ -n "$p445" ] && kill -0 "$p445" 2>/dev/null; then running=1; fi
            if [ -n "$p2049" ] && kill -0 "$p2049" 2>/dev/null; then running=1; fi

            while IFS= read -r -t 0.05 line <&3; do
                if [[ "$line" == *"|"* ]]; then
                    local key="${line%%|*}"
                    local data="${line#*|}"

                    case "$key" in
                        "FFUF:80" | "FFUF:443" )
                            echo -e "\r\033[K${TXT_SCARLET}[ FFUF:${key#*:} ]${NC} ${TXT_NEON}/${data}${NC}"
                            ;;
                        "INFO:80" | "INFO:443" | "INFO:445" | "INFO:2049" )
                            echo -e "\r\033[K${TXT_DRK_RED}[ INFO:${key#*:} ]${NC} ${TXT_MID_RED}${data}${NC}"
                            ;;
                        "NUCLEI:80" | "NUCLEI:443" )
                            if [[ "$data" =~ ^\[([^\]]+)\][[:space:]]+\[([^\]]+)\][[:space:]]+\[([^\]]+)\][[:space:]]+([^[:space:]]+)(.*)$ ]]; then
                                local template="${BASH_REMATCH[1]}"
                                local proto="${BASH_REMATCH[2]}"
                                local severity="${BASH_REMATCH[3]}"
                                local url="${BASH_REMATCH[4]}"
                                local extra="${BASH_REMATCH[5]}"

                                local clean_extra=$(echo "$extra" | tr -d '[]"')
                                clean_extra=$(echo "$clean_extra" | xargs)

                                local sev_col="${TXT_GLOW}"
                                case "$severity" in
                                    "info" )     sev_col="${TXT_GLITCH_BLUE}" ;;
                                    "low" )      sev_col="${TXT_NEON}" ;;
                                    "medium" )   sev_col="${TXT_MID_RED}" ;;
                                    "high" )     sev_col="${TXT_RED}" ;;
                                    "critical" ) sev_col="${CORE}" ;;
                                esac

                                if [ -n "$clean_extra" ]; then
                                    echo -e "\r\033[K${TXT_GLITCH_BLUE}[ NUCLEI:${key#*:} ]${NC} ${sev_col}[${severity}]${NC} ${TXT_NEON}${template}${NC} \t${TXT_DRK_RED}>>${NC} ${TXT_CORE}${clean_extra}${NC}"
                                else
                                    echo -e "\r\033[K${TXT_GLITCH_BLUE}[ NUCLEI:${key#*:} ]${NC} ${sev_col}[${severity}]${NC} ${TXT_NEON}${template}${NC}"
                                fi

                                local software=""
                                if [[ "$template" =~ (craft-cms|craftcms|nginx|apache|openssh|ssh|smb|nfs|ftp|vsftpd|mysql|oracle|tomcat|jenkins|webmin|drupal|wordpress|joomla|php) ]]; then
                                    software="${BASH_REMATCH[1]}"
                                    if [[ "$software" == "craft-cms" || "$software" == "craftcms" ]]; then
                                        software="craft cms"
                                    fi
                                fi

                                if [ -n "$software" ]; then
                                    if command -v searchsploit >/dev/null 2>&1; then
                                        echo -e "\r\033[K${TXT_GLITCH_BLUE}[ MX:// ]${NC} ${TXT_DRK_RED}Exploit-DB records for '${software}':${NC}"
                                        searchsploit "$software" 2>/dev/null | grep -vE 'Exploit Title|---|No Results' | head -n 3 | while read -r s_line; do
                                            echo -e "\r\033[K  ${TXT_DRK_RED}->${NC} ${TXT_CORE}${s_line}${NC}"
                                        done
                                    fi
                                fi
                            else
                                echo -e "\r\033[K${TXT_GLITCH_BLUE}[ NUCLEI:${key#*:} ]${NC} ${TXT_CORE}${data}${NC}"
                            fi
                            ;;
                        * )
                            echo -e "\r\033[K${line}"
                            ;;
                    esac
                else
                    echo -e "\r\033[K${line}"
                fi
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
            if [[ "$line" == *"|"* ]]; then
                local key="${line%%|*}"
                local data="${line#*|}"
                case "$key" in
                    "FFUF:80" | "FFUF:443" ) echo -e "\r\033[K${TXT_SCARLET}[ FFUF:${key#*:} ]${NC} ${TXT_NEON}/${data}${NC}" ;;
                    "INFO:80" | "INFO:443" | "INFO:445" | "INFO:2049" ) echo -e "\r\033[K${TXT_DRK_RED}[ INFO:${key#*:} ]${NC} ${TXT_MID_RED}${data}${NC}" ;;
                    "NUCLEI:80" | "NUCLEI:443" ) echo -e "\r\033[K${TXT_GLITCH_BLUE}[ NUCLEI:${key#*:} ]${NC} ${TXT_CORE}${data}${NC}" ;;
                esac
            else
                echo -e "\r\033[K${line}"
            fi
        done
        echo -ne "\r\033[K"

        exec 3<&-
        rm -f "$async_log"

        echo -e "\n${TXT_SCARLET}[*] MX:// ATTEMPTING TO SHUT DOWN REMAINING DATA STREAMS ... OK${NC}"
    fi
}