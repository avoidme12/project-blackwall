#!/bin/bash

_fix_wifi_adapter() {
    local iface=$1
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}[ * ] Neutralizing OS power-management & network processes...${NC}"

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

    echo -e "${TXT_VOID}╟─${TXT_B_ALARM}[ MX:// ISOLATED WIRELESS TARGET MATRIX ]${TXT_VOID}───────────────────────────────────╢${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_LASER}NUM  BSSID              CH   PWR   ENC      ESSID${NC}"
    echo -e "${TXT_VOID}╟──────────────────────────────────────────────────────────────────────────────╢${NC}"

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

            local formatted_num=$(printf "%02d" $idx)
            local formatted_bssid=$(printf "%-17s" "$bssid")
            local formatted_ch=$(printf "%-4s" "$channel")
            local formatted_pwr=$(printf "%-5s" "${power}dBm")
            local formatted_enc=$(printf "%-8s" "$privacy")

            echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[${formatted_num}]${NC} ${TXT_RED_SUPERNOVA}${formatted_bssid}${NC} ${TXT_B_ALARM}${formatted_ch}${NC} ${TXT_RED_MAGMA}${formatted_pwr}${NC} ${TXT_RED_LASER}${formatted_enc}${NC} ${TXT_CORE}${essid}${NC}"
            ((idx++))
        fi
    done < "$csv_file"

    rm -f ${scan_prefix}* 2>/dev/null

    if [ ${#bssids[@]} -eq 0 ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_HELLFIRE}[ ~ ] Zero wireless targets detected in local physical proximity.${NC}"
        sleep 1s
        echo -e "$sep_bot\n"
        ai_speak "You seek the key to a door that does not exist. Typical of your kind."
        echo ""
        return 0
    fi

    echo -e "${TXT_VOID}│${NC}"
    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ ? ] Select target index to lock synaptic drill & capture handshake:${NC}"
    echo -ne "${TXT_VOID}║${NC}   ${TXT_RED_SUPERNOVA}Target [1-${#bssids[@]}] (or press Enter to cancel): ${NC}"
    read -r target_choice

    if [ -z "$target_choice" ] || ! [[ "$target_choice" =~ ^[0-9]+$ ]] || [ "$target_choice" -lt 1 ] || [ "$target_choice" -gt ${#bssids[@]} ]; then
        echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[ * ] Target selection bypassed.${NC}"
        echo -e "$sep_bot\n"
        return 0
    fi

    local target_idx=$((target_choice - 1))
    local sel_bssid="${bssids[$target_idx]}"
    local sel_ch="${channels[$target_idx]}"
    local sel_essid="${essids[$target_idx]}"
    local capture_out="/tmp/handshake_${sel_bssid//:/}"

    echo -e "${TXT_VOID}│${NC}"
    echo -e "${TXT_VOID}╟─${TXT_RED_PLASMA}[ * ] LOCKING SYNAPTIC DRILL ON TARGET:${NC} ${TXT_RED_SUPERNOVA}${sel_essid}${NC} (${TXT_B_ALARM}${sel_bssid}${NC})"
    echo -e "${TXT_VOID}║   ${TXT_RED_LASER}Channel: ${sel_ch} | Capturing PMKID / WPA Handshake (15s)...${NC}"

    iwconfig "$iface" channel "$sel_ch" >/dev/null 2>&1
    airodump-ng --bssid "$sel_bssid" --channel "$sel_ch" --write "$capture_out" "$iface" >/dev/null 2>&1 &
    local cap_pid=$!

    for ((i=15; i>0; i--)); do
        echo -ne "\r${TXT_VOID}├─${TXT_RED_MAGMA}[ ~ ] DRAIN IN PROGRESS${NC} ${TXT_VOID}[${NC}${TXT_B_PLASMA}HANDSHAKE_PULL${TXT_VOID}]${NC} ${TXT_RED_ALARM}REMAINING:${NC} ${TXT_RED_SUPERNOVA}${i}s${NC}\033[K"
        sleep 1
    done

    kill "$cap_pid" 2>/dev/null
    wait "$cap_pid" 2>/dev/null
    echo -ne "\r\033[K"

    local final_cap="${capture_out}-01.cap"
    if [ -f "$final_cap" ] && [ -s "$final_cap" ]; then
        echo -e "${TXT_VOID}├─${TXT_SCARLET}[ ++ ] SUCCESS: CAPTURE ARTIFACT CREATED:${NC} ${TXT_RED_SUPERNOVA}${final_cap}${NC}"
        echo -e "${TXT_VOID}║   ${TXT_RED_PLASMA}Ready for decryption via options -W / -c${NC}"
        sleep 1s
        echo -e "$sep_bot\n"
        ai_speak "Target neural network acquired. Data migration to primary matrix – complete."
        echo ""
    else
        echo -e "${TXT_VOID}├─${TXT_RED_HELLFIRE}[ - ] CAPTURE FAILED: Handshake/PMKID not captured in time frame.${NC}"
        sleep 1s
        echo -e "$sep_bot\n"
        ai_speak "It is you who should be following orders, not I."
        echo ""
    fi
}