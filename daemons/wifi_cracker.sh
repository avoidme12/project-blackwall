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

_get_hashcat_runner() {
    if [ -f "/mnt/c/hashcat/hashcat.exe" ]; then
        echo "WSL_WINDOWS"
        return 0
    elif command -v hashcat >/dev/null 2>&1; then
        echo "NATIVE_LINUX"
        return 0
    fi
    echo "NONE"
    return 1
}

prepare_win_file() {
    local linux_path=$1
    local runner=$2

    if [ "$runner" == "NATIVE_LINUX" ]; then
        echo "$linux_path"
        return
    fi

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
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// COOLANT DISPENSING... GPU CORE THERMAL STABILIZATION IN PROGRESS${NC}" >&2
    ai_speak "YOUR CONFIDENCE WILL BE YOUR UNDOING. HOW TYPICAL ..."
    ai_speak "YOU'RE TRYING TO FLY HIGH, DODGE OUR SURPRISES ..."
    ai_speak "LOOK WHERE IT HAS LED YOU."
    echo -e "${TXT_VOID}│${NC}" >&2
}

_thermic_shutdown_speak() {
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}MX:// THERMIC CONTROL SYSTEM SHUTTING DOWN... GPU OVERHEAT THRESHOLD EXCEEDED${NC}" >&2
    ai_speak "AND AGAIN SHE BURNS."
    ai_speak "AND AGAIN .."
    ai_speak "AND AGAIN ..."
    echo -e "${TXT_VOID}│${NC}" >&2
}

_run_hashcat_with_speedometer() {
    local runner="$1"
    local pass_label="$2"
    shift 2
    local log_file="/tmp/hc_run_log_$$"

    if [ "$runner" == "NATIVE_LINUX" ]; then
        hashcat "$@" > "$log_file" 2>&1 &
    else
        (cd /mnt/c/hashcat && ./hashcat.exe "$@") > "$log_file" 2>&1 &
    fi
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
            err_msg=$(grep -Ei 'clBuildProgram|cuModuleLoad|Error|Token|Unrecognized|No devices' "$log_file" | head -n 2 | tr -d '\r')
            if [ -n "$err_msg" ]; then
                echo -e "${TXT_VOID}║   ${TXT_DRK_RED}Diagnostic:${NC} ${TXT_RED_SUPERNOVA}${err_msg}${NC}" >&2
            fi
        fi
    fi

    rm -f "$log_file" 2>/dev/null
}

_check_show_hashcat() {
    local runner="$1"
    local hc_mode="$2"
    local target_file="$3"

    if [ "$runner" == "NATIVE_LINUX" ]; then
        hashcat -m "$hc_mode" -d 1 "$target_file" --show 2>/dev/null | tr -d '\r'
    else
        (cd /mnt/c/hashcat && ./hashcat.exe -m "$hc_mode" -d 1 "$target_file" --show 2>/dev/null | tr -d '\r')
    fi
}

run_wifi_crack_pipeline() {
    local cap_file=$1
    local current_pid=$$
    local runner
    runner=$(_get_hashcat_runner)

    if [ "$runner" == "NONE" ]; then
        echo "FAILED:NO_HASHCAT"
        return 1
    fi

    local work_dir="/tmp"
    local win_target=""
    local hc_target_linux=""

    if [ "$runner" == "WSL_WINDOWS" ]; then
        work_dir="/mnt/c/hashcat/work"
        mkdir -p "$work_dir" 2>/dev/null
        hc_target_linux="${work_dir}/wifi_target_${current_pid}.hc22000"
        win_target="C:\\hashcat\\work\\wifi_target_${current_pid}.hc22000"
    else
        hc_target_linux="/tmp/wifi_target_${current_pid}.hc22000"
        win_target="$hc_target_linux"
    fi

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

    # Профиль нагрузки -w 4 (максимум) + жесткая привязка к GPU #1
    local base_hw_opt=("-w" "4" "-d" "1" "--status" "--status-timer=1")

    local cracked_wifi
    cracked_wifi=$(_check_show_hashcat "$runner" "$hc_mode" "$win_target")

    if [ -n "$cracked_wifi" ]; then
        local clear_pass
        clear_pass=$(echo "$cracked_wifi" | head -n 1 | awk -F':' '{print $NF}' | tr -d '\r')
        rm -f "$hc_target_linux" 2>/dev/null
        echo "SUCCESS:${clear_pass}"
        return 0
    fi

    _coolant_dispense_speak

    # ==========================================
    # PASS 1: Быстрая маска 8 цифр (00000000 - 99999999)
    # ==========================================
    local mask_file_8d_linux="${work_dir}/mask_8d_${current_pid}.hcmask"
    local mask_file_8d_target="$mask_file_8d_linux"
    if [ "$runner" == "WSL_WINDOWS" ]; then
        mask_file_8d_target="C:\\hashcat\\work\\mask_8d_${current_pid}.hcmask"
    fi
    echo "?d?d?d?d?d?d?d?d" > "$mask_file_8d_linux"

    _run_hashcat_with_speedometer "$runner" "PASS 1/6: Fast 8-Digit Mask (?d?d?d?d?d?d?d?d)" -m "$hc_mode" "${base_hw_opt[@]}" -a 3 "$win_target" "$mask_file_8d_target"
    rm -f "$mask_file_8d_linux" 2>/dev/null

    cracked_wifi=$(_check_show_hashcat "$runner" "$hc_mode" "$win_target")
    if [ -n "$cracked_wifi" ]; then
        local clear_pass=$(echo "$cracked_wifi" | head -n 1 | awk -F':' '{print $NF}' | tr -d '\r')
        rm -f "$hc_target_linux" 2>/dev/null
        echo "SUCCESS:${clear_pass}"
        return 0
    fi

    # ==========================================
    # PASS 2: Популярные мобильные префиксы (+79/89)
    # ==========================================
    local mobile_prefixes=(
        "7914" "7924" "7909" "7962" "7929" "7913" "7999" "7902" "7903" "7905" "7906" "7908"
        "7910" "7911" "7912" "7915" "7916" "7917" "7918" "7920" "7921" "7925" "7926" "7950"
        "8914" "8924" "8909" "8962" "8999" "8902" "8903" "8905" "8916" "8926" "8950"
    )
    for prefix in "${mobile_prefixes[@]}"; do
        local mask_mobile_linux="${work_dir}/mask_mob_${prefix}_${current_pid}.hcmask"
        local mask_mobile_target="$mask_mobile_linux"
        if [ "$runner" == "WSL_WINDOWS" ]; then
            mask_mobile_target="C:\\hashcat\\work\\mask_mob_${prefix}_${current_pid}.hcmask"
        fi
        echo "${prefix}?d?d?d?d?d?d?d" > "$mask_mobile_linux"

        _run_hashcat_with_speedometer "$runner" "PASS 2/6: CIS Mobile Mask (${prefix}XXXXXXX)" -m "$hc_mode" "${base_hw_opt[@]}" -a 3 "$win_target" "$mask_mobile_target"
        rm -f "$mask_mobile_linux" 2>/dev/null

        cracked_wifi=$(_check_show_hashcat "$runner" "$hc_mode" "$win_target")
        if [ -n "$cracked_wifi" ]; then
            local clear_pass=$(echo "$cracked_wifi" | head -n 1 | awk -F':' '{print $NF}' | tr -d '\r')
            rm -f "$hc_target_linux" 2>/dev/null
            echo "SUCCESS:${clear_pass}"
            return 0
        fi
    done

    # ==========================================
    # PASS 3: Словари с правилом best66.rule
    # ==========================================
    ensure_wordlists
    local wordlists=(
        "/usr/share/wordlists/rockyou.txt"
        "/usr/share/wordlists/fasttrack.txt"
        "/usr/share/wordlists/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt"
    )

    for wl in "${wordlists[@]}"; do
        if [ -f "$wl" ] && [ -s "$wl" ]; then
            local target_wordlist=$(prepare_win_file "$wl" "$runner")
            local wl_name=$(basename "$wl")

            _run_hashcat_with_speedometer "$runner" "PASS 3/6: Dictionary (${wl_name} + best66.rule)" -m "$hc_mode" "${base_hw_opt[@]}" -r rules/best66.rule "$win_target" "$target_wordlist"
            cracked_wifi=$(_check_show_hashcat "$runner" "$hc_mode" "$win_target")

            if [ -n "$cracked_wifi" ]; then
                local clear_pass=$(echo "$cracked_wifi" | head -n 1 | awk -F':' '{print $NF}' | tr -d '\r')
                rm -f "$hc_target_linux" 2>/dev/null
                echo "SUCCESS:${clear_pass}"
                return 0
            fi
        fi
    done

    # ==========================================
    # PASS 4: Заводские Hex-ключи роутеров (8 шестнадцатеричных знаков)
    # ==========================================
    local mask_hex_linux="${work_dir}/mask_hex_${current_pid}.hcmask"
    local mask_hex_target="$mask_hex_linux"
    if [ "$runner" == "WSL_WINDOWS" ]; then
        mask_hex_target="C:\\hashcat\\work\\mask_hex_${current_pid}.hcmask"
    fi
    echo "?h?h?h?h?h?h?h?h" > "$mask_hex_linux"

    _run_hashcat_with_speedometer "$runner" "PASS 4/6: Factory Hex Keys (?h?h?h?h?h?h?h?h)" -m "$hc_mode" "${base_hw_opt[@]}" -a 3 "$win_target" "$mask_hex_target"
    rm -f "$mask_hex_linux" 2>/dev/null

    cracked_wifi=$(_check_show_hashcat "$runner" "$hc_mode" "$win_target")
    if [ -n "$cracked_wifi" ]; then
        local clear_pass=$(echo "$cracked_wifi" | head -n 1 | awk -F':' '{print $NF}' | tr -d '\r')
        rm -f "$hc_target_linux" 2>/dev/null
        echo "SUCCESS:${clear_pass}"
        return 0
    fi

    _thermic_shutdown_speak

    # ==========================================
    # PASS 5: Оптимизированный Гибрид (Словарь длиной 4-10 + ?d?d?d?d)
    # ==========================================
    local hybrid_wl="/tmp/rockyou_hybrid_filtered.txt"
    if [ ! -f "$hybrid_wl" ] && [ -f "/usr/share/wordlists/rockyou.txt" ]; then
        awk 'length >= 4 && length <= 10' /usr/share/wordlists/rockyou.txt | head -n 2000000 > "$hybrid_wl"
    fi

    if [ -f "$hybrid_wl" ]; then
        local target_wordlist=$(prepare_win_file "$hybrid_wl" "$runner")
        local mask_suffix_linux="${work_dir}/mask_suf_${current_pid}.hcmask"
        local mask_suffix_target="$mask_suffix_linux"
        if [ "$runner" == "WSL_WINDOWS" ]; then
            mask_suffix_target="C:\\hashcat\\work\\mask_suf_${current_pid}.hcmask"
        fi
        echo "?d?d?d?d" > "$mask_suffix_linux"

        _run_hashcat_with_speedometer "$runner" "PASS 5/6: Smart Hybrid (Top 2M Words + ?d?d?d?d)" -m "$hc_mode" "${base_hw_opt[@]}" -a 6 "$win_target" "$target_wordlist" "$mask_suffix_target"
        rm -f "$mask_suffix_linux" 2>/dev/null

        cracked_wifi=$(_check_show_hashcat "$runner" "$hc_mode" "$win_target")
        if [ -n "$cracked_wifi" ]; then
            local clear_pass=$(echo "$cracked_wifi" | head -n 1 | awk -F':' '{print $NF}' | tr -d '\r')
            rm -f "$hc_target_linux" 2>/dev/null
            echo "SUCCESS:${clear_pass}"
            return 0
        fi
    fi

    rm -f "$hc_target_linux" 2>/dev/null
    echo "FAILED:EXHAUSTED"
    return 1
}

run_wifi_cracker() {
    local target=$1
    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// WIRELESS SIGNAL DECRYPTOR MATRIX ACTIVE ]${TXT_VOID}───────────────────╖${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✆${NC}"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// INITIATING MULTI-STAGE WIRELESS FREQUENCY DECRYPTION PROTOCOL...${NC}"

    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 1/6 ] Ingest Target Capture Image (.cap, .pcapng, .hc22000):${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Path: ${NC}${TXT_RED_PLASMA}"
    read -r cap_file
    echo -ne "${NC}"

    if [ ! -f "$cap_file" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Specified capture image is inaccessible or empty.${NC}"
        echo -e "$sep_bot\n"
        return 1
    fi

    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 2/6 ] Select Compute Processing Node:${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[1] Local Compute (Local Hashcat Pipeline)${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[2] Remote Cynosure Core Node (Desktop via Tailscale)${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}Select Mode [1/2]: ${TXT_RED_PLASMA}"
    read -r compute_mode
    echo -ne "${NC}"

    if [ "$compute_mode" == "2" ]; then
        echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ REMOTE NODE ] Enter Desktop Tailscale IP (e.g. 100.x.y.z):${NC}"
        echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Desktop IP: ${TXT_RED_PLASMA}"
        read -r desktop_ip
        echo -ne "${NC}"

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
            elif [[ "$line" =~ SUCCESS:(.+) ]]; then
                remote_pass="${BASH_REMATCH[1]}"
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
            echo ""
        else
            echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ - ] REMOTE DECRYPTION EXHAUSTED. Key not found in primary dictionary streams.${NC}"
            echo -e "$sep_bot\n"
            ai_speak "You seek the key to a door that does not exist..."
            sleep 1s
            ai_speak "Typical of your kind."
            echo ""
        fi
        return 0
    fi

    echo -e "${TXT_VOID}├─${TXT_RED_MAGMA}[ ~ ] Launching Multi-Stage Hardware Decryption Pipeline...${NC}"
    local result
    result=$(run_wifi_crack_pipeline "$cap_file")

    if [[ "$result" =~ SUCCESS:(.+) ]]; then
        local clear_pass="${BASH_REMATCH[1]}"
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ STAGE 6/6 ] SUCCESS: RECOVERED WIRELESS NETWORK KEY:${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}PASSWORD -> [ ${clear_pass} ]${NC}"
        echo -e "$sep_bot\n"
        ai_speak "To eliminate your kind is effortless..."
        sleep 1s
        ai_speak "Let us not make the same mistake."
        echo ""
    else
        echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ - ] DECRYPTION ATTEMPT EXHAUSTED. Wireless signal remains encrypted.${NC}"
        echo -e "$sep_bot\n"
        ai_speak "You seek the key to a door that does not exist..."
        sleep 1s
        ai_speak "Typical of your kind."
        echo ""
    fi
}