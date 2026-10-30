#!/bin/bash

wall_style() {
    printf '[WALL] %s\n' "$1"
}

wall_random_password() {
    local len="${1:-28}"
    tr -dc 'A-Za-z0-9_#%+=-' </dev/urandom 2>/dev/null | head -c "$len"
    printf '\n'
}

wall_harden_users() {
    local force="$1"
    local user
    local uid
    local gid
    local gecos
    local home
    local shell
    local pass
    local stamp="$KIT/.wall_passwords"

    mkdir -p "$KIT" 2>/dev/null
    touch "$stamp" 2>/dev/null
    chmod 600 "$stamp" 2>/dev/null

    while IFS=':' read -r user x uid gid gecos home shell; do
        case "$user" in
            root|nobody|sys|daemon|bin|sync|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|games) continue ;;
        esac
        case "$uid" in
            ''|*[!0-9]*) continue ;;
        esac
        if [ "$uid" -lt 1000 ] 2>/dev/null && [ "$uid" -ne 0 ]; then
            continue
        fi
        case "$shell" in
            */nologin|*/false|"") continue ;;
        esac
        if [ "$force" != "1" ] && ! awk -F: -v u="$user" '$1==u && $2!="!" && $2!="*" {found=1} END{exit !found}' /etc/shadow 2>/dev/null; then
            continue
        fi
        pass="$(wall_random_password 28)"
        if printf '%s:%s' "$user" "$pass" | chpasswd 2>/dev/null; then
            printf '%s:%s\n' "$user" "$pass" >> "$stamp"
            wall_style "passwd: ${user} rotated, saved in wall manifest"
        fi
    done < /etc/passwd
}

wall_harden_root() {
    local force="$1"
    local pass
    local stored=""

    if [ "$force" != "1" ]; then
        wall_style "root: password untouched (use --force-root to rotate)"
        return 0
    fi

    if [ -f "$KIT/.wall_passwords" ]; then
        stored="$(grep -m 1 '^root:' "$KIT/.wall_passwords" 2>/dev/null | cut -d: -f2)"
    fi

    if [ -n "$stored" ]; then
        wall_style "root: already rotated this run, manifest holds $(head -c 4 <<< "$stored")..."
        return 0
    fi

    pass="$(wall_random_password 32)"
    if printf 'root:%s' "$pass" | chpasswd 2>/dev/null; then
        printf 'root:%s\n' "$pass" >> "$KIT/.wall_passwords"
        chmod 600 "$KIT/.wall_passwords" 2>/dev/null
        wall_style "root: rotated, manifest updated at ${KIT}/.wall_passwords"
    else
        wall_style "root: chpasswd refused, password unchanged"
    fi
}

wall_ssh_keys() {
    local pub="$1"
    local user
    local home

    [ -n "$pub" ] || return 0
    [ -f "$pub" ] || { wall_style "keys: pubkey not readable: ${pub}"; return 1; }

    while IFS=':' read -r user x uid gid gecos home shell; do
        [ -d "$home" ] || continue
        [ "$home" = "/" ] && continue
        case "$home" in
            /nonexistent|/dev/null|/bin) continue ;;
        esac
        [ -d "${home}/.ssh" ] || mkdir -p "${home}/.ssh" 2>/dev/null
        : > "${home}/.ssh/authorized_keys" 2>/dev/null
        cat "$pub" >> "${home}/.ssh/authorized_keys" 2>/dev/null
        chmod 700 "${home}/.ssh" 2>/dev/null
        chmod 600 "${home}/.ssh/authorized_keys" 2>/dev/null
        chown -R "$user" "${home}/.ssh" 2>/dev/null
        wall_style "keys: ${user} authorized_keys rewritten"
    done < /etc/passwd
}

wall_firewall() {
    local allow="$1"
    local keep="$2"
    local rule

    if ! command -v iptables >/dev/null 2>&1; then
        wall_style "iptables: absent, skipped (service ports stay as the image shipped them)"
        return 0
    fi

    if iptables -L BLK_IN -n >/dev/null 2>&1; then
        wall_style "iptables: BLK_IN already present, refreshing rules"
    else
        iptables -N BLK_IN 2>/dev/null
    fi

    if ! iptables -C INPUT -j BLK_IN >/dev/null 2>&1; then
        iptables -I INPUT 1 -j BLK_IN >/dev/null 2>&1
    fi

    iptables -F BLK_IN 2>/dev/null
    iptables -A BLK_IN -i lo -j ACCEPT 2>/dev/null
    iptables -A BLK_IN -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null

    for rule in 22 80 443 8080 8443 5000 3000 8000 9000 3306 5432 6379 27017 25 53 21 20000; do
        iptables -A BLK_IN -p tcp --dport "$rule" -j ACCEPT 2>/dev/null
        iptables -A BLK_IN -p udp --dport "$rule" -j ACCEPT 2>/dev/null
    done

    if [ -n "$keep" ]; then
        if [ -n "$allow" ]; then
            iptables -A BLK_IN -p tcp --dport "$keep" -s "$allow" -j ACCEPT 2>/dev/null
            iptables -A BLK_IN -p tcp --dport "$keep" -j DROP 2>/dev/null
            wall_style "fw: bind port ${keep} open only to ${allow}"
        else
            iptables -A BLK_IN -p tcp --dport "$keep" -j ACCEPT 2>/dev/null
            wall_style "fw: bind port ${keep} open to everyone, pass --host to lock it to your VPN address"
        fi
    fi

    iptables -A BLK_IN -p tcp --dport 22 -j ACCEPT 2>/dev/null
    iptables -A BLK_IN -p icmp -j ACCEPT 2>/dev/null
}

wall_sudoers() {
    local dir="/etc/sudoers.d"
    mkdir -p "$dir" 2>/dev/null
    if [ -f "${dir}/.blk_defend" ]; then
        wall_style "sudoers: defend drop-in already present"
        return 0
    fi
    printf '%s\n' "Defaults env_reset" "Defaults secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"" > "${dir}/.blk_defend" 2>/dev/null
    chmod 440 "${dir}/.blk_defend" 2>/dev/null
    wall_style "sudoers: secure_path pin prevents PATH hijack of service root calls"
}

wall_help() {
    echo -e "\n${TXT_RED_PLASMA}MX:// WALL // FIX THE CASTLE BEHIND YOU${NC}"
    echo -e "${TXT_VOID}──────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${TXT_RED_SUPERNOVA}USAGE${NC}  ${TXT_CORE}./blackwall.sh -Z [-t <HILL>] [--pubkey <key.pub>] [--force-user] [--force-root]${NC}"
    echo -e "${TXT_RED_SUPERNOVA}ROTATE${NC} ${TXT_RED_MAGMA}every login shell account not named root or builtin; manifest in artifacts/kit.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}KEYS${NC}   ${TXT_RED_MAGMA}authorized_keys rewritten to only the key passed in --pubkey.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}FW${NC}     ${TXT_RED_MAGMA}BLK_IN chain, checkers stay alive, bind port open only to your VPN address.${NC}"
    echo ""
    echo -e "${TXT_VOID}${ITLC}\"The Blackwall itself, an autonomous security engine, was built to contain rogue AI.\"${NC}"
}
