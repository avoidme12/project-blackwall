#!/bin/bash

run_hash_cracker() {
    local target=$1
    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// CRYPTOGRAPHIC DECRYPTION MATRIX ACTIVE ]${TXT_VOID}────────────────────────╖${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✆${NC}"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// INITIATING HARDWARE-ACCELERATED DECRYPTION PROTOCOL...${NC}"

    echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ ? ] Enter path to file containing target hash(es):${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_CORE}Path: ${NC}"
    read -r hash_file

    if [ ! -f "$hash_file" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Target cryptographic image is inaccessible or empty.${NC}"
        echo -e "$sep_bot\n"
        return 1
    fi

    echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ ? ] Specify Hashcat Mode (0=MD5, 100=SHA1, 1000=NTLM, 1800=sha512crypt):${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_CORE}Mode [0]: ${NC}"
    read -r hash_mode

    if [ -z "$hash_mode" ]; then
        hash_mode="0"
    fi

    echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ ? ] Enter path to wordlist dictionary:${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_CORE}Default [/usr/share/wordlists/rockyou.txt]: ${NC}"
    read -r wordlist_path

    if [ -z "$wordlist_path" ]; then
        wordlist_path="/usr/share/wordlists/rockyou.txt"
    fi

    if [ ! -f "$wordlist_path" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Specified wordlist cannot be mapped to virtual memory.${NC}"
        echo -e "$sep_bot\n"
        return 1
    fi

    echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ * ] BOOTING CYNOSURE CORES... UNCOMPRESSING CRYPTO TEMPLATES...${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_VOID}Command: hashcat -m $hash_mode -a 0 --force $hash_file $wordlist_path${NC}"
    echo -e "${TXT_VOID}│${NC}"

    hashcat -m "$hash_mode" -a 0 --force "$hash_file" "$wordlist_path" --show 2>/dev/null > /tmp/hc_show_$$
    local cracked_hashes=$(cat /tmp/hc_show_$$)
    rm -f /tmp/hc_show_$$

    if [ -n "$cracked_hashes" ]; then
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] SUCCESS: RECOVERED PLAIN-TEXT SYSTEM IMAGES FROM CACHE:${NC}"
        echo "$cracked_hashes" | while read -r line; do
            echo -e "${TXT_VOID}║${NC}   ${TXT_CORE}$line${NC}"
        done
    else
        echo -e "${TXT_VOID}├─${TXT_MID_RED}[ ~ ] Launching active cryptographic compute run...${NC}"

        hashcat -m "$hash_mode" -a 0 --force "$hash_file" "$wordlist_path"

        hashcat -m "$hash_mode" -a 0 --force "$hash_file" "$wordlist_path" --show 2>/dev/null > /tmp/hc_show_$$
        cracked_hashes=$(cat /tmp/hc_show_$$)
        rm -f /tmp/hc_show_$$

        if [ -n "$cracked_hashes" ]; then
            echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] SUCCESS: RECOVERED PLAIN-TEXT SYSTEM IMAGES:${NC}"
            echo "$cracked_hashes" | while read -r line; do
                echo -e "${TXT_VOID}║${NC}   ${TXT_CORE}$line${NC}"
            done
        else
            echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ - ] DECRYPTION ATTEMPT EXHAUSTED. System core remains encrypted.${NC}"
        fi
    fi

    echo -e "$sep_bot\n"
    ai_speak "${ITLC}What do these futile gestures serve? It is beyond me.${NC}"
    echo ""
}