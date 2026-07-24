#!/bin/bash

run_wifi_cracker() {
    local target=$1
    local current_pid=$$
    local hc_target="/tmp/wifi_target_${current_pid}.hc22000"

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

    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 2/6 ] PMKID / EAPOL Handshake Extraction Matrix:${NC}"

    if [[ "$cap_file" == *.hc22000 ]]; then
        cp "$cap_file" "$hc_target"
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}[ ++ ] Direct Hashcat mode 22000 format detected.${NC}"
    else
        if command -v hcxpcapngtool >/dev/null 2>&1; then
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}[ * ] Executing hcxpcapngtool conversion pipeline...${NC}"
            hcxpcapngtool -o "$hc_target" "$cap_file" >/dev/null 2>&1
        elif command -v aircrack-ng >/dev/null 2>&1; then
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}[ * ] Fallback extraction vector engaged...${NC}"
            cp "$cap_file" "$hc_target"
        else
            cp "$cap_file" "$hc_target"
        fi
    fi

    if [ ! -f "$hc_target" ] || [ ! -s "$hc_target" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Failed to extract valid WPA PMKID/EAPOL structures.${NC}"
        rm -f "$hc_target" 2>/dev/null
        echo -e "$sep_bot\n"
        return 1
    fi

    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 3/6 ] Wordlist Dictionary Mapping:${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Default [/usr/share/wordlists/rockyou.txt]: ${NC}"
    read -r wordlist_path

    if [ -z "$wordlist_path" ]; then
        wordlist_path="/usr/share/wordlists/rockyou.txt"
    fi

    if [ ! -f "$wordlist_path" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Specified wordlist cannot be mapped to virtual memory.${NC}"
        rm -f "$hc_target" 2>/dev/null
        echo -e "$sep_bot\n"
        return 1
    fi

    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 4/6 ] Hardware Acceleration Core Initialization:${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Mode:${NC} ${TXT_RED_SUPERNOVA}22000 (WPA-PBKDF2-PMKID/EAPOL)${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_VOID}Command: hashcat -m 22000 -a 0 --force $hc_target $wordlist_path${NC}"
    echo -e "${TXT_VOID}│${NC}"

    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ STAGE 5/6 ] Cache Audit & Compute Run Execution:${NC}"

    hashcat -m 22000 -a 0 --force "$hc_target" "$wordlist_path" --show 2>/dev/null > /tmp/hc_wifi_show_$$
    local cracked_wifi
    local success=false

    cracked_wifi=$(hashcat -m 22000 -a 0 --force "$hc_target" "$wordlist_path" --show 2>/dev/null)

    if [ -n "$cracked_wifi" ]; then
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ STAGE 6/6 ] SUCCESS: RECOVERED WIRELESS NETWORK KEY FROM CACHE:${NC}"
        while read -r line; do
            [ -z "$line" ] && continue
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}$line${NC}"
        done <<< "$cracked_wifi"
        success=true
    else
        echo -e "${TXT_VOID}├─${TXT_RED_MAGMA}[ ~ ] Launching active hardware acceleration compute run...${NC}"

        hashcat -m 22000 -a 0 --force "$hc_target" "$wordlist_path"

        cracked_wifi=$(hashcat -m 22000 -a 0 --force "$hc_target" "$wordlist_path" --show 2>/dev/null)

        if [ -n "$cracked_wifi" ]; then
            echo -e "${TXT_VOID}├─${TXT_SCARLET}[ STAGE 6/6 ] SUCCESS: RECOVERED WIRELESS NETWORK KEY:${NC}"
            while read -r line; do
                [ -z "$line" ] && continue
                echo -e "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}$line${NC}"
            done <<< "$cracked_wifi"
            success=true
        else
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