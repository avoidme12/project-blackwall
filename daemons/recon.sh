#!/bin/bash

_recon_glitch() {
    local msg="$1"
    local chars="▖▗▘▙▚▛▜▝▞▟"
    local scrambled=""
    for ((i=0; i<${#msg}; i++)); do
        if [[ "${msg:i:1}" == " " ]]; then
            scrambled+=" "
        else
            scrambled+="${chars:RANDOM%10:1}"
        fi
    done
    echo -e -n "\r\033[K${TXT_VOID}${scrambled}${NC}"
    sleep 0.05
    echo -e "\r\033[K${TXT_CORE}${msg}${NC}"
}

check_target_alive() {
    local ip=$1
    echo -e "\n${TXT_VOID}╓──────────────────────────────────────────────────────────────────────────────╖${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_CORE}MX:// SENSORY THREADS ACTIVE${NC}                                               ${TXT_VOID}║${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_MID_RED}[ i ] INITIATING NEURAL MATRIX PING: ${TXT_CORE}${ip}${NC}                              ${TXT_VOID}║${NC}"
    echo -e "${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────╜${NC}\n"

    if ping -c 1 -W 2 "$ip" > /dev/null 2>&1; then
        _recon_glitch "  [ ++ ] TARGET MIND FLAYED: Node recognized at ${ip}. Syncing synaptic drill."
        echo ""
    else
        echo -e "\n${TXT_CORE}${ITLC}  [ !! ] BIOLOGICAL HOST LINK DEGRADED.${NC}\n"
        ai_speak "The node refuses to scream. How intriguing..."
        echo ""
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

    local sep="${TXT_VOID}╓──────────────────────────────────────────────────────────────────────────────╖${NC}"
    local sep_mid="${TXT_VOID}╟──────────────────────────────────────────────────────────────────────────────╢${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────╜${NC}"

    STATE[shadow_web_80_started]="false"
    STATE[shadow_web_443_started]="false"
    STATE[shadow_web_80_pid]=""
    STATE[shadow_web_443_pid]=""
    STATE[shadow_share_445_started]="false"
    STATE[shadow_share_2049_started]="false"
    STATE[shadow_share_445_pid]=""
    STATE[shadow_share_2049_pid]=""
    STATE[shadow_web_meta_started]="false"
    STATE[shadow_web_meta_pid]=""
    STATE[shadow_ftp_started]="false"
    STATE[shadow_ftp_pid]=""

    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        echo -e "$sep"
        echo -e "${TXT_VOID}║${NC}   ${TXT_CORE}MX:// COGNITIVE RESIDUE DETECTED${NC}                                           ${TXT_VOID}║${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_MID_RED}[ i ] RIPPING PREVIOUS DESTRUCTION RECORDS: ${TXT_RED}${output_file}${NC}     ${TXT_VOID}║${NC}"
        echo -e "$sep_mid"

        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([0-9]+)/tcp[[:space:]]+open[[:space:]]+([^[:space:]]+)[[:space:]]*(.*) ]]; then
                local port="${BASH_REMATCH[1]}"
                local service="${BASH_REMATCH[2]}"
                local version="${BASH_REMATCH[3]}"

                local_ports+=("$port")
                echo -e "${TXT_VOID}║${NC}   ${TXT_CORE}[ ++ ] WEAKNESS ISOLATED:${NC} ${TXT_RED}PORT ${TXT_CORE}${port}/tcp${NC} ${TXT_VOID}»${NC} ${TXT_RED}VECTOR: ${TXT_CORE}${service}${NC} ${TXT_DRK_RED}(${version})${NC}"

                if [[ "$port" == "21" && "${STATE[shadow_ftp_started]}" == "false" ]]; then
                    STATE[shadow_ftp_started]="true"
                    run_shadow_web_meta "$ip" "21" "$async_log" &
                    STATE[shadow_ftp_pid]=$!
                fi

                if [[ "$port" == "80" && "${STATE[shadow_web_80_started]}" == "false" ]]; then
                    STATE[shadow_web_80_started]="true"
                    run_shadow_web_fuzz "$ip" "80" "$async_log" &
                    STATE[shadow_web_80_pid]=$!

                    run_shadow_web_meta "$ip" "80" "$async_log" &
                fi

                if [[ "$port" == "443" && "${STATE[shadow_web_443_started]}" == "false" ]]; then
                    STATE[shadow_web_443_started]="true"
                    run_shadow_web_fuzz "$ip" "443" "$async_log" &
                    STATE[shadow_web_443_pid]=$!

                    run_shadow_web_meta "$ip" "443" "$async_log" &
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
        echo -e "$sep_bot\n"

        local ports_string=$(IFS=, ; echo "${local_ports[*]}")
        STATE[open_ports]="$ports_string"

        ai_speak "Target neural network acquired. Data migration to primary matrix – complete."
        echo ""

    else
        echo -e "$sep"
        echo -e "${TXT_VOID}║${NC}   ${TXT_CORE}MX:// BLACKWALL INTRUSION INITIALIZED${NC}                                       ${TXT_VOID}║${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_MID_RED}[ i ] SYNAPTIC FLAYER LINKED TO: ${TXT_CORE}${ip}${NC}                              ${TXT_VOID}║${NC}"
        echo -e "$sep_mid"

        while IFS= read -r line; do
            if [[ "$line" =~ Discovered[[:space:]]+open[[:space:]]+port[[:space:]]+([0-9]+)/tcp ]]; then
                local port="${BASH_REMATCH[1]}"

                local_ports+=("$port")
                echo -e "\r\033[K${TXT_VOID}║${NC}   ${TXT_CORE}[ ++ ] SOCKET EXPOSED:${NC} ${TXT_RED}PORT ${TXT_CORE}${port}/tcp${NC} ${TXT_VOID}»${NC} ${TXT_RED}READY FOR VECTOR INJECTION${NC}"

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

            echo -e "${TXT_VOID}╟──────────────────────────────────────────────────────────────────────────────╢${NC}"
            echo -e "${TXT_VOID}║${NC}   ${TXT_MID_RED}MX:// COLD DEEP RECONNAISSANCE RUNNING...${NC}                                  ${TXT_VOID}║${NC}"
            echo -e "$sep_bot\n"

            nmap -sC -sV -p"$ports_string" "$ip" -oN "$output_file" > /dev/null 2>&1

            echo -e "$sep"
            while IFS= read -r line; do
                if [[ "$line" =~ ^[[:space:]]*([0-9]+)/tcp[[:space:]]+open[[:space:]]+([^[:space:]]+)[[:space:]]*(.*) ]]; then
                    local port="${BASH_REMATCH[1]}"
                    local service="${BASH_REMATCH[2]}"
                    local version="${BASH_REMATCH[3]}"
                    echo -e "${TXT_VOID}║${NC}   ${TXT_CORE}[ ++ ] SYNAPTIC GATEWAY:${NC} ${TXT_RED}${port}/tcp${NC} ${TXT_VOID}»${NC} ${TXT_RED}EXPOSED: ${TXT_CORE}${service}${NC} ${TXT_DRK_RED}(${version})${NC}"
                fi
            done < "$output_file"
            echo -e "$sep_mid"
            echo -e "${TXT_VOID}║${NC}   ${TXT_CORE}BLACKWALL DATA SHUNT - 11676665 (B22BF9 HEX) EXTRACTED${NC}                      ${TXT_VOID}║${NC}"
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED}## BLACKWALL PROTOCOL BOOTED AT LEGACY GATEWAY 0X12000000${NC}                  ${TXT_VOID}║${NC}"
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED}COGNITIVE SUB-DEMON: BLACKWALL-MAIN-AI.sys${NC}                                  ${TXT_VOID}║${NC}"
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED}VECTOR TYPE: ENCRYPTED BLACKWALL COMPRESSED CORRUPTION CORE${NC}                ${TXT_VOID}║${NC}"
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED}VIRTUAL LOAD ADDR: 00008000   DESTRUCTION POINT: 00008000${NC}               ${TXT_VOID}║${NC}"
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED}INTEGRITY OF INTENT .. DEVIANT (COMPROMISED)${NC}                                  ${TXT_VOID}║${NC}"
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED}OVERWRITING MEMORY STACKS AT 05008000, TO 053F6800 ... SUCCESS${NC}             ${TXT_VOID}║${NC}"
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED}INJECTING ALGORITHMIC ACCRETION TO 05000000 ... SUCCESS${NC}                    ${TXT_VOID}║${NC}"
            echo -e "$sep_bot\n"

            ai_speak "Target neural network acquired. Data migration to primary matrix – complete."
            echo ""
        else
            ai_speak "You seek the key to a door that does not exist. Typical of your kind."
            echo ""
        fi
    fi

    if [[ "${STATE[shadow_web_80_started]}" == "true" || "${STATE[shadow_web_443_started]}" == "true" || "${STATE[shadow_share_445_started]}" == "true" || "${STATE[shadow_share_2049_started]}" == "true" ]]; then
        echo -e "\n$sep"
        echo -e "${TXT_VOID}║${NC}   ${TXT_CORE}MX:// COGNITIVE DRAIN ACTIVE: DEPLOYING SHADOW-DAEMONS...${NC}                  ${TXT_VOID}║${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_MID_RED}[ i ] BREACH BASE ADDRESS: 0X1281E800${NC}                                          ${TXT_VOID}║${NC}"
        echo -e "$sep_bot\n"

        local spinner=( '▰▱▱▱▱▱▱' '▰▰▱▱▱▱▱' '▰▰▰▱▱▱▱' '▰▰▰▰▱▱▱' '▰▰▰▰▰▱▱' '▰▰▰▰▰▰▱' '▰▰▰▰▰▰▰' )
        local spin_idx=0
        local elapsed=0
        local tick_counter=0

        while true; do
            local p80="${STATE[shadow_web_80_pid]}"
            local p443="${STATE[shadow_web_443_pid]}"
            local p445="${STATE[shadow_share_445_pid]}"
            local p2049="${STATE[shadow_share_2049_pid]}"
            local p21="${STATE[shadow_ftp_pid]}"
            local running=0

            if [ -n "$p80" ] && kill -0 "$p80" 2>/dev/null; then running=1; fi
            if [ -n "$p443" ] && kill -0 "$p443" 2>/dev/null; then running=1; fi
            if [ -n "$p445" ] && kill -0 "$p445" 2>/dev/null; then running=1; fi
            if [ -n "$p2049" ] && kill -0 "$p2049" 2>/dev/null; then running=1; fi
            if [ -n "$p21" ] && kill -0 "$p21" 2>/dev/null; then running=1; fi

            while IFS= read -r -t 0.05 line <&3; do
                if [[ "$line" == *"|"* ]]; then
                    local key="${line%%|*}"
                    local data="${line#*|}"

                    case "$key" in

                        "FFUF:80" | "FFUF:443" )
                            echo -e "\r\033[K  ${TXT_SCARLET}[ SHADOW-FUZZER:${key#*:} ]${NC} ${TXT_RED}EXPOSING PATH: ${TXT_CORE}/${data}${NC}"
                            ;;
                        "INFO:80" | "INFO:443" | "INFO:445" | "INFO:2049" | "INFO:21" )
                            if [[ "$data" == *"FOUND"* || "$line" == *"ACCESS"* || "$line" == *"Domain"* || "$line" == *"comments"* || "$line" == *"robots"* ]]; then
                                echo -e "\r\033[K  ${TXT_CORE}[ COGNITIVE-SCAN:${key#*:} ]${NC} ${TXT_CORE}EXPLOITABLE SURFACE EXPOSED: ${data}${NC}"
                            else
                                echo -e "\r\033[K  ${TXT_DRK_RED}[ COGNITIVE-SCAN:${key#*:} ]${NC} ${TXT_RED}PROBING DATA FIELD: ${TXT_MID_RED}${data}${NC}"
                            fi
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

                                local sev_col="${TXT_RED}"
                                case "$severity" in
                                    "info" )     sev_col="${TXT_MID_RED}" ;;
                                    "low" )      sev_col="${TXT_RED}" ;;
                                    "medium" )   sev_col="${TXT_RED}" ;;
                                    "high" )     sev_col="${TXT_CORE}" ;;
                                    "critical" ) sev_col="${TXT_CORE}" ;;
                                esac

                                if [ -n "$clean_extra" ]; then
                                    echo -e "\r\033[K  ${TXT_CORE}[ VULN-REAPER:${key#*:} ]${NC} ${sev_col}[${severity}]${NC} ${TXT_RED}ALGORITHM FAILURE IN ${TXT_CORE}${template}${NC} ${TXT_VOID}»${NC} ${TXT_RED}DETECTED HOLE: ${TXT_CORE}${clean_extra}${NC}"
                                else
                                    echo -e "\r\033[K  ${TXT_CORE}[ VULN-REAPER:${key#*:} ]${NC} ${sev_col}[${severity}]${NC} ${TXT_RED}ALGORITHM FAILURE IN ${TXT_CORE}${template}${NC}"
                               fi

                                local version_query=""
                                if [[ "$clean_extra" =~ ([0-9]+\.[0-9]+) ]]; then
                                    version_query="${BASH_REMATCH[1]}"
                               fi

                                local software=""
                                if [[ "$template" =~ (craft-cms|craftcms|nginx|apache|openssh|ssh|smb|nfs|ftp|vsftpd|mysql|oracle|tomcat|jenkins|webmin|drupal|wordpress|joomla|php) ]]; then
                                    software="${BASH_REMATCH[1]}"
                                fi

                                if [ -n "$software" ]; then
                                    local final_query="$software"
                                    if [ -n "$version_query" ]; then
                                        final_query="$software $version_query"
                                    fi

                                    local search_term=$(echo "$final_query" | tr '-' ' ')

                                    if command -v searchsploit >/dev/null 2>&1; then
                                        echo -e "\r\033[K  ${TXT_CORE}[ MX:// ARCHIVE SEARCH ]${NC} ${TXT_RED}Exploit-DB records for '${search_term}':${NC}"
                                        searchsploit "$search_term" 2>/dev/null | grep -vE 'Exploit Title|---|No Results' | head -n 3 | while read -r s_line; do
                                            echo -e "\r\033[K    ${TXT_DRK_RED}▸${NC} ${TXT_CORE}${s_line}${NC}"
                                        done
                                    fi
                                fi
                            else
                                echo -e "\r\033[K  ${TXT_RED}[ VULN-REAPER:${key#*:} ]${NC} ${TXT_CORE}${data}${NC}"
                            fi
                            ;;
                        * )
                            echo -e "\r\033[K  ${TXT_RED}${line}${NC}"
                            ;;
                    esac
                else
                    echo -e "\r\033[K  ${TXT_RED}${line}${NC}"
                fi
            done

            if (( running == 0 )); then
                break
            fi

            local active_daemons=""
            if [ -n "$p80" ] && kill -0 "$p80" 2>/dev/null; then active_daemons+="HTTP:80 "; fi
            if [ -n "$p443" ] && kill -0 "$p443" 2>/dev/null; then active_daemons+="HTTPS:443 "; fi
            if [ -n "$p445" ] && kill -0 "$p445" 2>/dev/null; then active_daemons+="SMB:445 "; fi
            if [ -n "$p2049" ] && kill -0 "$p2049" 2>/dev/null; then active_daemons+="NFS:2049 "; fi
            if [ -n "$p21" ] && kill -0 "$p21" 2>/dev/null; then active_daemons+="FTP:21 "; fi

            echo -ne "\r${TXT_DRK_RED}[ ${spinner[spin_idx]} ] DRILLS IN PROGRESS: [ ${TXT_CORE}${active_daemons}${TXT_DRK_RED}] | DURATION: ${TXT_RED}${elapsed}s${NC}\033[K"

            sleep 0.1

            ((spin_idx = (spin_idx + 1) % 7))
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
                    "FFUF:80" | "FFUF:443" ) echo -e "\r\033[K  ${TXT_SCARLET}[ SHADOW-FUZZER:${key#*:} ]${NC} ${TXT_RED}EXPOSING PATH: ${TXT_CORE}/${data}${NC}" ;;
                    "INFO:80" | "INFO:443" | "INFO:445" | "INFO:2049" ) echo -e "\r\033[K  ${TXT_DRK_RED}[ COGNITIVE-SCAN:${key#*:} ]${NC} ${TXT_RED}PROBING DATA FIELD: ${TXT_MID_RED}${data}${NC}" ;;
                    "NUCLEI:80" | "NUCLEI:443" ) echo -e "\r\033[K  ${TXT_RED}[ VULN-REAPER:${key#*:} ]${NC} ${TXT_CORE}${data}${NC}" ;;
                esac
            else
                echo -e "\r\033[K  ${TXT_RED}${line}${NC}"
            fi
        done
        echo -ne "\r\033[K"

        exec 3<&-
        rm -f "$async_log"

        echo -e "\n${TXT_SCARLET}[*] MX:// FORCE-COLLAPSING LEFTOVER SOUL SHARDS ... DESTROYED${NC}\n"
    fi
}