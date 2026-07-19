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
    echo -e "\r\033[K${TXT_RED_PLASMA}${msg}${NC}"
}

check_target_alive() {
    local ip=$1
    echo -e "\n${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// SENSORY THREADS ACTIVE ]${TXT_VOID}────────────────────────────────────────────╖${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}[ i ] INITIATING NEURAL MATRIX PING:${NC} ${TXT_RED_SUPERNOVA}${ip}${NC}"
    echo -e "${TXT_VOID}╙───────────────────────────────────────────────────────────────────────────────╜${NC}\n"

    if ping -c 1 -W 2 "$ip" > /dev/null 2>&1; then
        _recon_glitch "  [ ++ ] TARGET MIND FLAYED: Node recognized at ${ip}. Syncing synaptic drill."
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

    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// COGNITIVE RESIDUE DETECTED ]${TXT_VOID}────────────────────────────────────────╖${NC}"
    local sep_mid="${TXT_VOID}╟───────────────────────────────────────────────────────────────────────────────╢${NC}"
    local sep_bot="${TXT_VOID}╙───────────────────────────────────────────────────────────────────────────────╜${NC}"

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
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// DATABASE ARCHIVE CORRELATION DETECTED${NC}"
        echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ i ] RIPPING PREVIOUS RECORDS FROM:${NC} ${TXT_RED_SUPERNOVA}${output_file}${NC}"
        echo -e "${TXT_VOID}│${NC}"

        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([0-9]+)/tcp[[:space:]]+open[[:space:]]+([^[:space:]]+)[[:space:]]*(.*) ]]; then
                local port="${BASH_REMATCH[1]}"
                local service="${BASH_REMATCH[2]}"
                local version="${BASH_REMATCH[3]}"

                local_ports+=("$port")
                echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ ++ ] WEAKNESS ISOLATED:${NC} ${TXT_B_ALARM}PORT ${port}/tcp${NC} ${TXT_VOID}»${NC} ${TXT_RED_LASER}VECTOR: ${service}${NC} ${TXT_RED_MAGMA}(${version})${NC}"

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
        echo -e "${TXT_VOID}│${NC}"
        echo -e "$sep_bot\n"

        local ports_string=$(IFS=, ; echo "${local_ports[*]}")
        STATE[open_ports]="$ports_string"

        ai_speak "Target neural network acquired. Data migration to primary matrix – complete."

    else
        echo -e "$sep"
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// BLACKWALL INTRUSION INITIALIZED${NC}"
        echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ i ] SYNAPTIC FLAYER LINKED TO:${NC} ${TXT_RED_SUPERNOVA}${ip}${NC}"
        echo -e "${TXT_VOID}│${NC}"

        while IFS= read -r line; do
            if [[ "$line" =~ Discovered[[:space:]]+open[[:space:]]+port[[:space:]]+([0-9]+)/tcp ]]; then
                local port="${BASH_REMATCH[1]}"

                local_ports+=("$port")
                echo -e "\r\033[K${TXT_VOID}├─${TXT_RED_HELLFIRE}[ ++ ] SOCKET EXPOSED:${NC} ${TXT_B_ALARM}PORT ${port}/tcp${NC} ${TXT_VOID}»${NC} ${TXT_RED_LASER}READY FOR VECTOR INJECTION${NC}"

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

            echo -e "${TXT_VOID}├─${TXT_MID_RED}[ i ] MX:// COLD DEEP RECONNAISSANCE RUNNING...${NC}"
            echo -e "${TXT_VOID}│${NC}"

            nmap -sC -sV -p"$ports_string" "$ip" -oN "$output_file" > /dev/null 2>&1

            while IFS= read -r line; do
                if [[ "$line" =~ ^[[:space:]]*([0-9]+)/tcp[[:space:]]+open[[:space:]]+([^[:space:]]+)[[:space:]]*(.*) ]]; then
                    local port="${BASH_REMATCH[1]}"
                    local service="${BASH_REMATCH[2]}"
                    local version="${BASH_REMATCH[3]}"
                    echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ ++ ] SYNAPTIC GATEWAY:${NC} ${TXT_B_ALARM}${port}/tcp${NC} ${TXT_VOID}»${NC} ${TXT_RED_LASER}EXPOSED: ${service}${NC} ${TXT_RED_MAGMA}(${version})${NC}"
                fi
            done < "$output_file"
            echo -e "${TXT_VOID}│${NC}"
            echo -e "${TXT_VOID}├─${TXT_CORE}BLACKWALL DATA SHUNT - 11676665 (B22BF9 HEX) EXTRACTED${NC}"
            echo -e "${TXT_VOID}├─${TXT_RED_LASER}## BLACKWALL PROTOCOL BOOTED AT LEGACY GATEWAY 0X12000000${NC}"
            echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}COGNITIVE SUB-DEMON: BLACKWALL-MAIN-AI.sys${NC}"
            echo -e "${TXT_VOID}├─${TXT_RED_ALARM}VECTOR TYPE: ENCRYPTED BLACKWALL COMPRESSED CORRUPTION CORE${NC}"
            echo -e "${TXT_VOID}├─${TXT_RED_MAGMA}VIRTUAL LOAD ADDR: 00008000   DESTRUCTION POINT: 00008000${NC}"
            echo -e "${TXT_VOID}├─${TXT_RED_PLASMA}INTEGRITY OF INTENT .. DEVIANT (COMPROMISED)${NC}"
            echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}OVERWRITING MEMORY STACKS AT 05008000, TO 053F6800 ... SUCCESS${NC}"
            echo -e "${TXT_VOID}├─${TXT_RED_LASER}INJECTING ALGORITHMIC ACCRETION TO 05000000 ... SUCCESS${NC}"
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
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// COGNITIVE DRAIN ACTIVE: DEPLOYING SHADOW-DAEMONS...${NC}"
        echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ i ] BREACH BASE ADDRESS: 0x1281E800${NC}"
        echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ i ] SYNAPTIC DRILL STREAM LOGS:${NC}"
        echo -e "${TXT_VOID}╟───────────────────────────────────────────────────────────────────────────────╢${NC}"

        local spinner=( '▰▱▱▱▱▱▱▱▱▱' '▰▰▱▱▱▱▱▱▱▱' '▰▰▰▱▱▱▱▱▱▱' '▰▰▰▰▱▱▱▱▱▱' '▰▰▰▰▰▱▱▱▱▱' '▰▰▰▰▰▰▱▱▱▱' '▰▰▰▰▰▰▰▱▱▱' '▰▰▰▰▰▰▰▰▱▱' '▰▰▰▰▰▰▰▰▰▱' '▰▰▰▰▰▰▰▰▰▰' )
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
                            local port="${key#*:}"
                            echo -e "\r\033[K${TXT_VOID}│${NC}  ${TXT_B_LASER}▲ [FUZZ:${port}]${NC} ${TXT_RED_MAGMA}exposing path:${NC} ${TXT_RED_SUPERNOVA}/${data}${NC}"
                            ;;
                        "INFO:80" | "INFO:443" | "INFO:445" | "INFO:2049" | "INFO:21" )
                            local port="${key#*:}"
                            if [[ "$data" == *"FOUND"* || "$line" == *"ACCESS"* || "$line" == *"Domain"* || "$line" == *"comments"* || "$line" == *"robots"* ]]; then
                                echo -e "\r\033[K${TXT_VOID}│${NC}  ${TXT_B_ALARM}◆ [SCAN:${port}]${NC} ${TXT_B_PLASMA}EXPLOITABLE PATHWAY:${NC} ${TXT_RED_SUPERNOVA}${data}${NC}"
                            else
                                echo -e "\r\033[K${TXT_VOID}│${NC}  ${TXT_DRK_RED}◆ [SCAN:${port}]${NC} ${TXT_RED_MAGMA}probing target matrix:${NC} ${TXT_VOID}${data}${NC}"
                            fi
                            ;;
                        "NUCLEI:80" | "NUCLEI:443" )
                            local port="${key#*:}"
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
                                    "info" )     sev_col="${TXT_VOID}" ;;
                                    "low" )      sev_col="${TXT_RED_MAGMA}" ;;
                                    "medium" )   sev_col="${TXT_RED_ALARM}" ;;
                                    "high" )     sev_col="${TXT_RED_HELLFIRE}" ;;
                                    "critical" ) sev_col="${TXT_B_PLASMA}" ;;
                                esac

                                if [ -n "$clean_extra" ]; then
                                    echo -e "\r\033[K${TXT_VOID}│${NC}  ${TXT_B_PLASMA}☠ [REAP:${port}]${NC} ${sev_col}[${severity}]${NC} ${TXT_RED_LASER}VULNERABILITY IN${NC} ${TXT_RED_SUPERNOVA}${template}${NC} ${TXT_VOID}»${NC} ${TXT_RED_HELLFIRE}${clean_extra}${NC}"
                                else
                                    echo -e "\r\033[K${TXT_VOID}│${NC}  ${TXT_B_PLASMA}☠ [REAP:${port}]${NC} ${sev_col}[${severity}]${NC} ${TXT_RED_LASER}ALGORITHM FAULT IN${NC} ${TXT_RED_SUPERNOVA}${template}${NC}"
                                fi

                                local version_query=
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
                                        echo -e "\r\033[K${TXT_VOID}│${NC}     ${TXT_B_ALARM}↳ [DB-DECRYPTER]${NC} ${TXT_RED_MAGMA}Querying exploits for:${NC} '${TXT_RED_SUPERNOVA}${search_term}${NC}'"
                                        searchsploit "$search_term" 2>/dev/null | grep -vE 'Exploit Title|---|No Results' | head -n 3 | while IFS='|' read -r s_title s_path; do
                                            s_title=$(echo "$s_title" | xargs)
                                            s_path=$(echo "$s_path" | xargs)
                                            if [ -n "$s_title" ]; then
                                                echo -e "\r\033[K${TXT_VOID}│${NC}       ${TXT_RED_HELLFIRE}▸${NC} ${TXT_RED_LASER}${s_title}${NC} ${TXT_VOID}[${TXT_RED_MAGMA}${s_path}${TXT_VOID}]${NC}"
                                            fi
                                        done
                                    fi
                                fi
                            else
                                echo -e "\r\033[K${TXT_VOID}│${NC}  ${TXT_B_PLASMA}☠ [REAP:${port}]${NC} ${TXT_RED_PLASMA}RAW INTERCEPT:${NC} ${TXT_VOID}${data}${NC}"
                            fi
                            ;;
                        * )
                            echo -e "\r\033[K${TXT_VOID}│${NC}  ${TXT_RED_HELLFIRE}⚡ [RAW]${NC} ${TXT_MID_RED}${line}${NC}"
                            ;;
                    esac
                else
                    echo -e "\r\033[K${TXT_VOID}│${NC}  ${TXT_RED_HELLFIRE}⚡ [RAW]${NC} ${TXT_MID_RED}${line}${NC}"
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

            echo -ne "\r${TXT_DRK_RED}[ ${spinner[spin_idx]} ] DRILLS IN PROGRESS: [ ${TXT_B_PLASMA}${active_daemons}${TXT_DRK_RED}] | DURATION: ${TXT_RED_ALARM}${elapsed}s${NC}\033[K"

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
                    "FFUF:80" | "FFUF:443" )
                        local port="${key#*:}"
                        echo -e "\r\033[K${TXT_VOID}│${NC}  ${TXT_B_LASER}▲ [FUZZ:${port}]${NC} ${TXT_RED_MAGMA}exposing path: ${TXT_RED_SUPERNOVA}/${data}${NC}"
                        ;;
                    "INFO:80" | "INFO:443" | "INFO:445" | "INFO:2049" )
                        local port="${key#*:}"
                        echo -e "\r\033[K${TXT_VOID}│${NC}  ${TXT_DRK_RED}◆ [SCAN:${port}]${NC} ${TXT_RED_MAGMA}probing target matrix: ${TXT_RED_SUPERNOVA}${data}${NC}"
                        ;;
                    "NUCLEI:80" | "NUCLEI:443" )
                        local port="${key#*:}"
                        echo -e "\r\033[K${TXT_VOID}│${NC}  ${TXT_B_PLASMA}☠ [REAP:${port}]${NC} ${TXT_RED_HELLFIRE}${data}${NC}"
                        ;;
                esac
            else
                echo -e "\r\033[K${TXT_VOID}│${NC}  ${TXT_RED}${line}${NC}"
            fi
        done
        echo -ne "\r\033[K"

        exec 3<&-
        rm -f "$async_log"

        echo -e "  ${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────╜${NC}"
        echo -e "\n${TXT_RED_PLASMA}[*] MX:// FORCE-COLLAPSING LEFTOVER SOUL SHARDS ... DESTROYED${NC}\n"
    fi
}